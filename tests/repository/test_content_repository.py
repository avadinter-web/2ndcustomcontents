import sqlite3
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import (
    ContentAlreadyExistsError,
    ContentArchivedError,
    ContentConflictError,
    ContentNotFoundError,
)
from custom_content_studio.domain import Content, ContentStatus, ContentType
from custom_content_studio.infrastructure.sqlite.repositories import SQLiteContentRepository
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 9, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "contents.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _seed_parents(connection: sqlite3.Connection) -> None:
    for suffix in ("1", "2"):
        workspace_id = f"workspace-{suffix}"
        connection.execute(
            "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
            (workspace_id, workspace_id, "2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
        )
        connection.execute(
            "INSERT INTO projects(id,workspace_id,name,status,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?)",
            (
                f"project-{suffix}",
                workspace_id,
                workspace_id,
                "ACTIVE",
                "2026-09-09T00:00:00Z",
                "2026-09-09T00:00:00Z",
            ),
        )


def _content(content_id: str = "content-1") -> Content:
    return Content(
        content_id=content_id,
        workspace_id="workspace-1",
        project_id="project-1",
        title="Launch",
        content_type=ContentType.SHORT,
        primary_platform="YOUTUBE",
        goal=None,
        status=ContentStatus.IDEA,
        current_version_id=None,
        created_at_utc=NOW,
        updated_at_utc=NOW,
    )


def test_create_is_initial_idea_and_never_commits(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        repository.create(uow.connection, _content())
        loaded = repository.get_by_id(uow.connection, "workspace-1", "content-1")
        assert loaded is not None
        assert loaded.status is ContentStatus.IDEA
        assert loaded.current_version_id is None

    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM contents").fetchone()[0] == 0
    finally:
        connection.close()


def test_scope_project_and_reopen_persistence(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        foreign = replace(_content(), project_id="project-2")
        with pytest.raises(ContentNotFoundError):
            repository.create(uow.connection, foreign)
        repository.create(uow.connection, _content())
        with pytest.raises(ContentAlreadyExistsError):
            repository.create(uow.connection, _content())
        uow.commit()

    connection = factory.connect()
    try:
        assert repository.get_by_id(connection, "workspace-2", "content-1") is None
        assert repository.list_for_project(connection, "workspace-2", "project-1") == ()
        assert len(repository.list_for_project(connection, "workspace-1", "project-1")) == 1
    finally:
        connection.close()


def test_descriptive_update_uses_cas_and_preserves_version_linkage(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        repository.create(uow.connection, _content())
        original = repository.get_by_id(uow.connection, "workspace-1", "content-1")
        assert original is not None
        updated = repository.update(
            uow.connection,
            replace(
                original,
                title="Updated",
                status=ContentStatus.ACTIVE,
                updated_at_utc=NOW + timedelta(seconds=1),
            ),
        )
        assert updated.title == "Updated"
        assert updated.status is ContentStatus.IDEA
        assert updated.current_version_id is None
        assert updated.row_version == 2
        with pytest.raises(ContentConflictError):
            repository.update(uow.connection, replace(original, title="Stale"))

        uow.connection.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES ('user-1','user@example.test','user@example.test','ACTIVE',?,?)",
            ("2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
        )
        uow.connection.execute(
            "INSERT INTO workspace_memberships(workspace_id,user_id,role,created_at,updated_at) "
            "VALUES ('workspace-1','user-1','EDITOR',?,?)",
            ("2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
        )
        uow.connection.execute(
            "INSERT INTO content_versions(id,content_id,version_number,status,"
            "content_snapshot_json,snapshot_hash,created_by,created_at) "
            "VALUES ('version-1','content-1',1,'DRAFT',?,'hash','user-1',?)",
            (
                '{"_schema":"ccs.content-version-snapshot","_version":1,'
                '"data":{"content":{},"script":null,"title":"Launch"}}',
                "2026-09-09T00:00:02Z",
            ),
        )
        uow.connection.execute(
            "UPDATE contents SET current_version_id='version-1',row_version=3 WHERE id='content-1'"
        )
        linked = repository.get_by_id(uow.connection, "workspace-1", "content-1")
        assert linked is not None
        assert linked.current_version_id == "version-1"
        linked_updated = repository.update(
            uow.connection,
            replace(linked, title="Linked update", updated_at_utc=NOW + timedelta(seconds=3)),
        )
        assert linked_updated.current_version_id == "version-1"
        assert linked_updated.row_version == 4


def test_archived_content_cannot_be_updated(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteContentRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        repository.create(uow.connection, _content())
        original = repository.get_by_id(uow.connection, "workspace-1", "content-1")
        assert original is not None
        uow.connection.execute(
            "UPDATE contents SET status='ARCHIVED',archived_at=?,row_version=2 WHERE id=?",
            ("2026-09-09T00:00:01Z", "content-1"),
        )
        with pytest.raises(ContentArchivedError):
            repository.update(
                uow.connection,
                replace(original, title="Forbidden", updated_at_utc=NOW + timedelta(seconds=2)),
            )
