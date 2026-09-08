from __future__ import annotations

import json
import sqlite3
from hashlib import sha256
from pathlib import Path

import pytest

from custom_content_studio.persistence import (
    DatabaseIntegrityError,
    ExistingDatabaseNotAuthorizedError,
    MigrationChecksumMismatchError,
    MigrationManifestError,
    MigrationRunner,
    SQLiteConnectionFactory,
    load_manifest,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"


def _factory(tmp_path: Path, name: str = "studio.sqlite3") -> SQLiteConnectionFactory:
    database_path = (tmp_path / name).resolve()
    assert database_path.parent == tmp_path.resolve()
    return SQLiteConnectionFactory(database_path)


def _write_fixture_migration(root: Path, sql: str) -> None:
    root.mkdir()
    sql_path = root / "0001_fixture.sql"
    sql_path.write_text(sql, encoding="utf-8")
    manifest = {
        "_schema": "ccs.sqlite.migration-manifest",
        "_version": 1,
        "application_version": "0.0.0",
        "migrations": [
            {
                "version": 1,
                "name": "fixture",
                "path": sql_path.name,
                "checksum_sha256": sha256(sql_path.read_bytes()).hexdigest(),
            }
        ],
    }
    (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


def test_fresh_bootstrap_applies_canonical_schema_and_pragmas(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    result = MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()

    assert result.current_version == 1
    assert result.applied_versions == (1,)
    connection = factory.connect()
    try:
        objects = {
            (str(row[0]), str(row[1]))
            for row in connection.execute(
                "SELECT type,name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'"
            )
        }
        assert ("table", "schema_migrations") in objects
        assert ("table", "users") in objects
        assert ("table", "publications") in objects
        assert ("view", "timeline_duration_view") in objects
        assert ("trigger", "trg_content_versions_no_delete") in objects
        row = connection.execute(
            "SELECT version,name,checksum_sha256,status,application_version FROM schema_migrations"
        ).fetchone()
        assert row is not None
        assert tuple(row) == (
            1,
            "initial_v2_2",
            load_manifest(MIGRATIONS_ROOT).migrations[0].checksum_sha256,
            "APPLIED",
            "0.0.0",
        )
        assert connection.execute("PRAGMA foreign_keys").fetchone()[0] == 1
        assert str(connection.execute("PRAGMA journal_mode").fetchone()[0]).casefold() == "wal"
        assert connection.execute("PRAGMA busy_timeout").fetchone()[0] == 5000
        assert connection.execute("PRAGMA integrity_check").fetchall()[0][0] == "ok"
        assert connection.execute("PRAGMA foreign_key_check").fetchall() == []
    finally:
        connection.close()


def test_restart_is_noop_and_preserves_data(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    runner = MigrationRunner(factory, MIGRATIONS_ROOT)
    runner.migrate_fresh()
    connection = factory.connect()
    connection.execute(
        "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
        "VALUES ('u1','user@example.test','user@example.test','ACTIVE',"
        "'2026-09-08T00:00:00Z','2026-09-08T00:00:00Z')"
    )
    connection.close()

    result = runner.migrate_fresh()

    assert result.applied_versions == ()
    connection = factory.connect()
    try:
        assert connection.execute("SELECT id FROM users").fetchone()[0] == "u1"
        assert connection.execute("SELECT COUNT(*) FROM schema_migrations").fetchone()[0] == 1
    finally:
        connection.close()


def test_changed_applied_migration_bytes_fail_before_database_mutation(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(fixture_root, "CREATE TABLE witness(id INTEGER);\n")
    factory = _factory(tmp_path)
    runner = MigrationRunner(factory, fixture_root)
    runner.migrate_fresh()
    (fixture_root / "0001_fixture.sql").write_text(
        "CREATE TABLE changed(id INTEGER);\n", encoding="utf-8"
    )

    with pytest.raises(MigrationChecksumMismatchError):
        runner.migrate_fresh()

    connection = sqlite3.connect(factory.database_path)
    try:
        assert (
            connection.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='changed'"
            ).fetchone()
            is None
        )
        assert connection.execute("SELECT COUNT(*) FROM schema_migrations").fetchone()[0] == 1
    finally:
        connection.close()


def test_manifest_rejects_invalid_shape(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(fixture_root, "CREATE TABLE witness(id INTEGER);\n")
    manifest_path = fixture_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["unexpected"] = True
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(MigrationManifestError):
        load_manifest(fixture_root)


def test_manifest_rejects_gapped_version(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(fixture_root, "CREATE TABLE witness(id INTEGER);\n")
    manifest_path = fixture_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["migrations"][0]["version"] = 2
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(MigrationManifestError):
        load_manifest(fixture_root)


def test_manifest_rejects_duplicate_keys(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(fixture_root, "CREATE TABLE witness(id INTEGER);\n")
    manifest_path = fixture_root / "manifest.json"
    raw = manifest_path.read_text(encoding="utf-8")
    manifest_path.write_text(
        raw.replace('"_version": 1', '"_version": 1, "_version": 1'), encoding="utf-8"
    )

    with pytest.raises(MigrationManifestError):
        load_manifest(fixture_root)


def test_manifest_rejects_unsafe_path(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(fixture_root, "CREATE TABLE witness(id INTEGER);\n")
    manifest_path = fixture_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["migrations"][0]["path"] = "../0001_fixture.sql"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(MigrationManifestError):
        load_manifest(fixture_root)


def test_manifest_rejects_unlisted_sql(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(fixture_root, "CREATE TABLE witness(id INTEGER);\n")
    (fixture_root / "0002_unlisted.sql").write_text("SELECT 1;\n", encoding="utf-8")

    with pytest.raises(MigrationManifestError):
        load_manifest(fixture_root)


def test_failing_migration_rolls_back_domain_changes(tmp_path: Path) -> None:
    fixture_root = tmp_path / "migrations"
    _write_fixture_migration(
        fixture_root,
        "CREATE TABLE witness(id INTEGER);\n"
        "INSERT INTO witness(id) VALUES (1);\n"
        "SELECT missing_function();\n",
    )
    factory = _factory(tmp_path)

    with pytest.raises(DatabaseIntegrityError):
        MigrationRunner(factory, fixture_root).migrate_fresh()

    connection = sqlite3.connect(factory.database_path)
    try:
        assert (
            connection.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='witness'"
            ).fetchone()
            is None
        )
        assert (
            connection.execute("SELECT status FROM schema_migrations WHERE version=1").fetchone()[0]
            == "FAILED"
        )
    finally:
        connection.close()


def test_preexisting_unrelated_database_is_rejected_without_schema_mutation(
    tmp_path: Path,
) -> None:
    factory = _factory(tmp_path)
    connection = sqlite3.connect(factory.database_path)
    connection.execute("CREATE TABLE sentinel(id INTEGER)")
    connection.close()

    with pytest.raises(ExistingDatabaseNotAuthorizedError):
        MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()

    connection = sqlite3.connect(factory.database_path)
    try:
        names = [
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            )
        ]
        assert names == ["sentinel"]
    finally:
        connection.close()
