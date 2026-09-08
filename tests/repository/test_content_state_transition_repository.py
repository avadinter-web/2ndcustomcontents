import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import ContentStateTransitionConflictError
from custom_content_studio.domain import (
    ContentStatus,
    ContentVersionSnapshot,
    ContentVersionStatus,
    compute_snapshot_hash,
)
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteContentStateTransitionRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

ROOT = Path(__file__).resolve().parents[2]
NOW = datetime(2026, 9, 9, tzinfo=UTC)
SNAPSHOT = (
    '{"_schema":"ccs.content-version-snapshot","_version":1,'
    '"data":{"content":{},"script":null,"title":"Launch"}}'
)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "transitions.sqlite3").resolve())
    MigrationRunner(factory, ROOT / "migrations").migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        _seed(uow.connection)
        uow.commit()
    return factory


def _seed(connection: sqlite3.Connection) -> None:
    for suffix in ("1", "2"):
        workspace = f"workspace-{suffix}"
        user = f"user-{suffix}"
        connection.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?)",
            (
                user,
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
            (workspace, user, "EDITOR", "2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
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
        snapshot_hash = compute_snapshot_hash(
            f"content-{suffix}",
            1,
            ContentVersionSnapshot(title="Launch", script=None, content={}),
        )
        connection.execute(
            "INSERT INTO content_versions(id,content_id,version_number,status,title_snapshot,"
            "content_snapshot_json,snapshot_hash,created_by,created_at) "
            "VALUES (?,?,1,'DRAFT','Launch',?,?,?,?)",
            (
                f"version-{suffix}",
                f"content-{suffix}",
                SNAPSHOT,
                snapshot_hash,
                user,
                "2026-09-09T00:00:00Z",
            ),
        )
        connection.execute(
            "UPDATE contents SET current_version_id=? WHERE id=?",
            (f"version-{suffix}", f"content-{suffix}"),
        )


def test_repository_transitions_are_scoped_cas_and_caller_owned(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentStateTransitionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        active = repository.transition_content(
            uow.connection,
            "workspace-1",
            "content-1",
            1,
            ContentStatus.IDEA,
            ContentStatus.ACTIVE,
            NOW + timedelta(seconds=1),
        )
        assert (active.status, active.row_version) == (ContentStatus.ACTIVE, 2)
        with pytest.raises(ContentStateTransitionConflictError):
            repository.transition_content(
                uow.connection,
                "workspace-1",
                "content-1",
                1,
                ContentStatus.ACTIVE,
                ContentStatus.ARCHIVED,
                NOW + timedelta(seconds=2),
            )
    connection = factory.connect()
    try:
        assert (
            connection.execute("SELECT status FROM contents WHERE id='content-1'").fetchone()[0]
            == "IDEA"
        )
    finally:
        connection.close()


def test_submit_review_preserves_version_identity_and_conceals_scope(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentStateTransitionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        before = uow.connection.execute(
            "SELECT * FROM content_versions WHERE id='version-1'"
        ).fetchone()
        after = repository.transition_content_version(
            uow.connection,
            "workspace-1",
            "version-1",
            1,
            ContentVersionStatus.DRAFT,
            ContentVersionStatus.REVIEW_REQUIRED,
        )
        assert (after.status, after.row_version) == (ContentVersionStatus.REVIEW_REQUIRED, 2)
        stored = uow.connection.execute(
            "SELECT * FROM content_versions WHERE id='version-1'"
        ).fetchone()
        for field in (
            "content_id",
            "version_number",
            "parent_version_id",
            "title_snapshot",
            "script_snapshot_json",
            "content_snapshot_json",
            "snapshot_hash",
            "created_by",
            "created_at",
            "approved_at",
            "approved_by",
        ):
            assert stored[field] == before[field]
        assert repository.get_content_version(uow.connection, "workspace-2", "version-1") is None
