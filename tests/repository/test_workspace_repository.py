from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import (
    WorkspaceAlreadyExistsError,
    WorkspaceArchivedError,
    WorkspaceConflictError,
    WorkspaceNotFoundError,
)
from custom_content_studio.domain import Workspace
from custom_content_studio.infrastructure.sqlite.repositories import SQLiteWorkspaceRepository
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "workspaces.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _workspace(workspace_id: str = "workspace-1", name: str = "Studio") -> Workspace:
    return Workspace(
        workspace_id=workspace_id,
        name=name,
        timezone="UTC",
        settings={"language": "ko"},
        created_at_utc=NOW,
        updated_at_utc=NOW,
    )


def test_create_get_list_and_duplicate_error_are_transactional(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteWorkspaceRepository()
    with SQLiteUnitOfWork(factory) as uow:
        repository.create(uow.connection, _workspace("workspace-2", "Second"))
        repository.create(uow.connection, _workspace("workspace-1", "First"))
        loaded = repository.get_by_id(uow.connection, "workspace-1")
        assert loaded is not None
        assert loaded.settings == {"language": "ko"}
        assert [item.workspace_id for item in repository.list_active(uow.connection)] == [
            "workspace-1",
            "workspace-2",
        ]
        with pytest.raises(WorkspaceAlreadyExistsError):
            repository.create(uow.connection, _workspace("workspace-1"))

    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM workspaces").fetchone()[0] == 0
    finally:
        connection.close()


def test_update_uses_row_version_cas_and_distinguishes_missing(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteWorkspaceRepository()
    with SQLiteUnitOfWork(factory) as uow:
        repository.create(uow.connection, _workspace())
        uow.commit()

    connection = factory.connect()
    try:
        original = repository.get_by_id(connection, "workspace-1")
        assert original is not None
        updated = repository.update(
            connection,
            replace(original, name="Updated", updated_at_utc=NOW + timedelta(seconds=1)),
        )
        assert updated.name == "Updated"
        assert updated.row_version == 2
        with pytest.raises(WorkspaceConflictError):
            repository.update(connection, replace(original, name="Stale"))
        with pytest.raises(WorkspaceNotFoundError):
            repository.update(connection, replace(original, workspace_id="missing"))
    finally:
        connection.close()


def test_archive_excludes_workspace_and_blocks_further_updates(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteWorkspaceRepository()
    with SQLiteUnitOfWork(factory) as uow:
        repository.create(uow.connection, _workspace())
        archived = repository.archive(uow.connection, "workspace-1", 1, NOW + timedelta(seconds=1))
        assert archived.is_archived
        assert archived.row_version == 2
        assert repository.list_active(uow.connection) == ()
        with pytest.raises(WorkspaceArchivedError):
            repository.update(uow.connection, replace(archived, archived_at_utc=None))
        with pytest.raises(WorkspaceArchivedError):
            repository.archive(uow.connection, "workspace-1", 2, NOW + timedelta(seconds=2))
