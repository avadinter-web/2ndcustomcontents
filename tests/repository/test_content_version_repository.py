import sqlite3
from datetime import UTC, datetime
from pathlib import Path

import pytest

from custom_content_studio.application.ports import ContentVersionConflictError
from custom_content_studio.domain import (
    ContentVersion,
    ContentVersionSnapshot,
    ContentVersionStatus,
    compute_snapshot_hash,
)
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteContentVersionRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

ROOT = Path(__file__).resolve().parents[2]
NOW = datetime(2026, 9, 9, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "versions.sqlite3").resolve())
    MigrationRunner(factory, ROOT / "migrations").migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        _seed(uow.connection)
        uow.commit()
    return factory


def _seed(connection: sqlite3.Connection) -> None:
    for suffix in ("1", "2"):
        workspace = f"workspace-{suffix}"
        connection.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?)",
            (
                f"user-{suffix}",
                f"u{suffix}@example.test",
                f"u{suffix}@example.test",
                "ACTIVE",
                "2026-09-09T00:00:00Z",
                "2026-09-09T00:00:00Z",
            ),
        )
        connection.execute(
            "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
            (workspace, workspace, "2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
        )
        connection.execute(
            "INSERT INTO workspace_memberships(workspace_id,user_id,role,created_at,updated_at) "
            "VALUES (?,?,?,?,?)",
            (workspace, f"user-{suffix}", "EDITOR", "2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
        )
        connection.execute(
            "INSERT INTO projects(id,workspace_id,name,status,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?)",
            (
                f"project-{suffix}",
                workspace,
                workspace,
                "ACTIVE",
                "2026-09-09T00:00:00Z",
                "2026-09-09T00:00:00Z",
            ),
        )
        connection.execute(
            "INSERT INTO contents(id,workspace_id,project_id,title,content_type,status,"
            "created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)",
            (
                f"content-{suffix}",
                workspace,
                f"project-{suffix}",
                "Launch",
                "SHORT",
                "IDEA",
                "2026-09-09T00:00:00Z",
                "2026-09-09T00:00:00Z",
            ),
        )


def _version(number: int = 1, parent: str | None = None) -> ContentVersion:
    snapshot = ContentVersionSnapshot(title="Launch", script={"text": "hello"}, content={})
    return ContentVersion(
        version_id=f"version-{number}",
        content_id="content-1",
        version_number=number,
        parent_version_id=parent,
        status=ContentVersionStatus.DRAFT,
        snapshot=snapshot,
        snapshot_hash=compute_snapshot_hash("content-1", number, snapshot),
        created_by="user-1",
        created_at_utc=NOW,
    )


def test_create_advances_head_preserves_history_and_never_commits(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentVersionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        assert repository.next_version_number(uow.connection, "workspace-1", "content-1") == 1
        repository.create_and_advance_head(uow.connection, "workspace-1", 1, None, _version())
        assert repository.get_by_id(uow.connection, "workspace-2", "version-1") is None
        loaded = repository.get_by_id(uow.connection, "workspace-1", "version-1")
        assert loaded == _version()
        assert uow.connection.execute(
            "SELECT current_version_id,row_version FROM contents WHERE id='content-1'"
        ).fetchone()[:] == ("version-1", 2)
    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM content_versions").fetchone()[0] == 0
    finally:
        connection.close()


def test_stale_head_conflict_rolls_back_without_orphan_and_delete_is_blocked(
    tmp_path: Path,
) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentVersionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        repository.create_and_advance_head(uow.connection, "workspace-1", 1, None, _version())
        uow.commit()
    with pytest.raises(ContentVersionConflictError), SQLiteUnitOfWork(factory) as uow:
        repository.create_and_advance_head(
            uow.connection, "workspace-1", 1, None, _version(2, "version-1")
        )
    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM content_versions").fetchone()[0] == 1
        with pytest.raises(sqlite3.IntegrityError, match="immutable"):
            connection.execute("DELETE FROM content_versions WHERE id='version-1'")
    finally:
        connection.close()
