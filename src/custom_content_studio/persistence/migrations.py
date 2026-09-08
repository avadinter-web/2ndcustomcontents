from __future__ import annotations

import json
import re
import sqlite3
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from hashlib import sha256
from pathlib import Path
from typing import Any
from urllib.parse import quote

from .sqlite import PersistenceError, SQLiteConnectionFactory

_HEX_DIGEST = re.compile(r"[0-9a-f]{64}")
_MIGRATION_NAME = re.compile(r"[a-z0-9_]+")
_MANIFEST_KEYS = {"_schema", "_version", "application_version", "migrations"}
_ENTRY_KEYS = {"version", "name", "path", "checksum_sha256"}
_SCHEMA_MIGRATIONS_SQL = """
CREATE TABLE schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  checksum_sha256 TEXT NOT NULL,
  started_at TEXT NOT NULL,
  applied_at TEXT,
  status TEXT NOT NULL CHECK(status IN ('APPLYING','APPLIED','FAILED')),
  application_version TEXT NOT NULL
)
"""


class MigrationManifestError(PersistenceError):
    def __init__(self, message: str) -> None:
        super().__init__("MIGRATION_MANIFEST_INVALID", message)


class MigrationChecksumMismatchError(PersistenceError):
    def __init__(self, message: str) -> None:
        super().__init__("MIGRATION_CHECKSUM_MISMATCH", message)


class ExistingDatabaseNotAuthorizedError(PersistenceError):
    def __init__(self, message: str) -> None:
        super().__init__("EXISTING_DATABASE_NOT_AUTHORIZED", message)


class DatabaseIntegrityError(PersistenceError):
    def __init__(self, message: str) -> None:
        super().__init__("DATABASE_INTEGRITY_FAILED", message)


@dataclass(frozen=True)
class Migration:
    version: int
    name: str
    path: Path
    checksum_sha256: str
    sql: str


@dataclass(frozen=True)
class MigrationManifest:
    application_version: str
    migrations: tuple[Migration, ...]


@dataclass(frozen=True)
class MigrationResult:
    current_version: int
    applied_versions: tuple[int, ...]


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise MigrationManifestError(f"duplicate manifest key: {key}")
        result[key] = value
    return result


def _require_exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        raise MigrationManifestError(f"{label} keys must be exactly {sorted(expected)}")


def load_manifest(migrations_root: Path) -> MigrationManifest:
    if not migrations_root.is_absolute():
        raise MigrationManifestError("migrations root must be absolute")
    try:
        root = migrations_root.resolve(strict=True)
    except OSError as error:
        raise MigrationManifestError("migrations root must exist") from error
    if not root.is_dir():
        raise MigrationManifestError("migrations root must be a directory")

    manifest_path = root / "manifest.json"
    try:
        raw_manifest = manifest_path.read_text(encoding="utf-8")
        parsed = json.loads(raw_manifest, object_pairs_hook=_reject_duplicate_keys)
    except MigrationManifestError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MigrationManifestError("manifest must be readable UTF-8 JSON") from error
    if not isinstance(parsed, dict):
        raise MigrationManifestError("manifest root must be an object")
    _require_exact_keys(parsed, _MANIFEST_KEYS, "manifest")
    if parsed["_schema"] != "ccs.sqlite.migration-manifest" or parsed["_version"] != 1:
        raise MigrationManifestError("unsupported manifest schema or version")
    application_version = parsed["application_version"]
    entries = parsed["migrations"]
    if not isinstance(application_version, str) or not application_version:
        raise MigrationManifestError("application_version must be a nonempty string")
    if not isinstance(entries, list) or not entries:
        raise MigrationManifestError("migrations must be a nonempty array")

    migrations: list[Migration] = []
    listed_paths: set[str] = set()
    for expected_version, raw_entry in enumerate(entries, start=1):
        if not isinstance(raw_entry, dict):
            raise MigrationManifestError("migration entry must be an object")
        _require_exact_keys(raw_entry, _ENTRY_KEYS, "migration")
        version = raw_entry["version"]
        name = raw_entry["name"]
        relative_path = raw_entry["path"]
        checksum = raw_entry["checksum_sha256"]
        if type(version) is not int or version != expected_version:
            raise MigrationManifestError("migration versions must be contiguous from 1")
        if not isinstance(name, str) or _MIGRATION_NAME.fullmatch(name) is None:
            raise MigrationManifestError("migration name is invalid")
        expected_filename = f"{version:04d}_{name}.sql"
        if not isinstance(relative_path, str) or relative_path != expected_filename:
            raise MigrationManifestError("migration path does not match version and name")
        if not isinstance(checksum, str) or _HEX_DIGEST.fullmatch(checksum) is None:
            raise MigrationManifestError("migration checksum must be lowercase SHA-256")
        candidate = root / relative_path
        try:
            resolved_candidate = candidate.resolve(strict=True)
        except OSError as error:
            raise MigrationManifestError("listed migration file is missing") from error
        if resolved_candidate.parent != root or not resolved_candidate.is_file():
            raise MigrationManifestError("migration path must be a direct file inside root")
        try:
            sql_bytes = resolved_candidate.read_bytes()
            sql = sql_bytes.decode("utf-8")
        except (OSError, UnicodeError) as error:
            raise MigrationManifestError("migration must be readable UTF-8") from error
        actual_checksum = sha256(sql_bytes).hexdigest()
        if actual_checksum != checksum:
            raise MigrationChecksumMismatchError(f"checksum mismatch for version {version}")
        listed_paths.add(relative_path)
        migrations.append(Migration(version, name, resolved_candidate, checksum, sql))

    actual_sql_files = {path.name for path in root.glob("*.sql") if path.is_file()}
    if actual_sql_files != listed_paths:
        raise MigrationManifestError("manifest and SQL file set must match exactly")
    return MigrationManifest(application_version, tuple(migrations))


def _utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _execute_statements(connection: sqlite3.Connection, sql: str) -> None:
    buffer: list[str] = []
    for line in sql.splitlines(keepends=True):
        buffer.append(line)
        statement = "".join(buffer)
        if sqlite3.complete_statement(statement):
            if statement.strip():
                connection.execute(statement)
            buffer.clear()
    if "".join(buffer).strip():
        raise MigrationManifestError("migration contains an incomplete SQL statement")


def _integrity_check(connection: sqlite3.Connection) -> None:
    integrity_rows = connection.execute("PRAGMA integrity_check").fetchall()
    if [str(row[0]) for row in integrity_rows] != ["ok"]:
        raise DatabaseIntegrityError("integrity_check did not return ok")
    if connection.execute("PRAGMA foreign_key_check").fetchone() is not None:
        raise DatabaseIntegrityError("foreign_key_check returned violations")


def _migration_rows(connection: sqlite3.Connection) -> list[sqlite3.Row]:
    return list(
        connection.execute(
            "SELECT version, name, checksum_sha256, status, application_version "
            "FROM schema_migrations ORDER BY version"
        )
    )


def _matches_manifest(rows: Iterable[sqlite3.Row], manifest: MigrationManifest) -> bool:
    actual = list(rows)
    if len(actual) != len(manifest.migrations):
        return False
    return all(
        int(row["version"]) == migration.version
        and str(row["name"]) == migration.name
        and str(row["checksum_sha256"]) == migration.checksum_sha256
        and str(row["status"]) == "APPLIED"
        and str(row["application_version"]) == manifest.application_version
        for row, migration in zip(actual, manifest.migrations, strict=True)
    )


def _inspect_existing(database_path: Path, manifest: MigrationManifest) -> bool:
    if not database_path.exists() or database_path.stat().st_size == 0:
        return False
    uri = f"file:{quote(database_path.as_posix(), safe='/:')}?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True)
        connection.row_factory = sqlite3.Row
        table = connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='schema_migrations'"
        ).fetchone()
        if table is None:
            raise ExistingDatabaseNotAuthorizedError(
                "pre-existing database has no migration identity"
            )
        rows = _migration_rows(connection)
        for row in rows:
            version = int(row["version"])
            expected = next((item for item in manifest.migrations if item.version == version), None)
            if expected is not None and str(row["checksum_sha256"]) != expected.checksum_sha256:
                raise MigrationChecksumMismatchError(
                    f"applied checksum mismatch for version {version}"
                )
        if not _matches_manifest(rows, manifest):
            raise ExistingDatabaseNotAuthorizedError(
                "pre-existing database is not the exact migrated database"
            )
        return True
    except PersistenceError:
        raise
    except sqlite3.Error as error:
        raise ExistingDatabaseNotAuthorizedError(
            "unable to verify pre-existing database"
        ) from error
    finally:
        if "connection" in locals():
            connection.close()


class MigrationRunner:
    def __init__(self, factory: SQLiteConnectionFactory, migrations_root: Path) -> None:
        self._factory = factory
        self._migrations_root = migrations_root

    def migrate_fresh(self) -> MigrationResult:
        manifest = load_manifest(self._migrations_root)
        if _inspect_existing(self._factory.database_path, manifest):
            connection = self._factory.connect()
            try:
                _integrity_check(connection)
                rows = _migration_rows(connection)
                if not _matches_manifest(rows, manifest):
                    raise ExistingDatabaseNotAuthorizedError("migration state changed during open")
            finally:
                connection.close()
            return MigrationResult(manifest.migrations[-1].version, ())

        connection = self._factory.connect()
        applied: list[int] = []
        try:
            connection.execute(_SCHEMA_MIGRATIONS_SQL)
            for migration in manifest.migrations:
                started_at = _utc_now()
                try:
                    connection.execute("BEGIN IMMEDIATE")
                    connection.execute(
                        "INSERT INTO schema_migrations "
                        "(version,name,checksum_sha256,started_at,applied_at,status,"
                        "application_version) "
                        "VALUES (?,?,?,?,NULL,'APPLYING',?)",
                        (
                            migration.version,
                            migration.name,
                            migration.checksum_sha256,
                            started_at,
                            manifest.application_version,
                        ),
                    )
                    _execute_statements(connection, migration.sql)
                    _integrity_check(connection)
                    connection.execute(
                        "UPDATE schema_migrations SET applied_at=?, status='APPLIED' "
                        "WHERE version=? AND status='APPLYING'",
                        (_utc_now(), migration.version),
                    )
                    connection.execute("COMMIT")
                    applied.append(migration.version)
                except (PersistenceError, sqlite3.Error) as error:
                    if connection.in_transaction:
                        connection.execute("ROLLBACK")
                    connection.execute(
                        "INSERT INTO schema_migrations "
                        "(version,name,checksum_sha256,started_at,applied_at,status,"
                        "application_version) "
                        "VALUES (?,?,?,?,NULL,'FAILED',?)",
                        (
                            migration.version,
                            migration.name,
                            migration.checksum_sha256,
                            started_at,
                            manifest.application_version,
                        ),
                    )
                    if isinstance(error, PersistenceError):
                        raise
                    raise DatabaseIntegrityError(
                        f"migration {migration.version} failed and rolled back"
                    ) from error
            _integrity_check(connection)
            rows = _migration_rows(connection)
            if not _matches_manifest(rows, manifest):
                raise DatabaseIntegrityError("applied migration state does not match manifest")
            return MigrationResult(manifest.migrations[-1].version, tuple(applied))
        except PersistenceError:
            raise
        except sqlite3.Error as error:
            raise DatabaseIntegrityError("SQLite migration operation failed") from error
        finally:
            connection.close()
