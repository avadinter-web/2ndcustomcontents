import sqlite3
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import (
    ProjectAlreadyExistsError,
    ProjectArchivedError,
    ProjectConflictError,
    ProjectNotFoundError,
)
from custom_content_studio.domain import Project, ProjectStatus
from custom_content_studio.infrastructure.sqlite.repositories import SQLiteProjectRepository
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "projects.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _seed_workspace(connection: sqlite3.Connection, workspace_id: str) -> None:
    connection.execute(
        "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
        (workspace_id, workspace_id, "2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
    )


def _project(workspace_id: str = "workspace-1", project_id: str = "project-1") -> Project:
    return Project(
        project_id=project_id,
        workspace_id=workspace_id,
        name="Launch",
        description=None,
        content_type="SHORT_VIDEO",
        default_language="ko",
        default_platforms=("YOUTUBE",),
        brand_profile_ref=None,
        status=ProjectStatus.ACTIVE,
        created_at_utc=NOW,
        updated_at_utc=NOW,
    )


def test_create_and_reads_are_workspace_scoped_without_implicit_commit(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteProjectRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_workspace(uow.connection, "workspace-1")
        _seed_workspace(uow.connection, "workspace-2")
        repository.create(uow.connection, _project())
        loaded = repository.get_by_id(uow.connection, "workspace-1", "project-1")
        assert loaded is not None
        assert loaded.default_platforms == ("YOUTUBE",)
        assert repository.get_by_id(uow.connection, "workspace-2", "project-1") is None
        assert repository.list_active(uow.connection, "workspace-2") == ()
        with pytest.raises(ProjectAlreadyExistsError):
            repository.create(uow.connection, _project())

    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM projects").fetchone()[0] == 0
    finally:
        connection.close()


def test_update_cas_conceals_cross_workspace_and_distinguishes_stale(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteProjectRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_workspace(uow.connection, "workspace-1")
        _seed_workspace(uow.connection, "workspace-2")
        repository.create(uow.connection, _project())
        uow.commit()

    connection = factory.connect()
    try:
        original = repository.get_by_id(connection, "workspace-1", "project-1")
        assert original is not None
        updated = repository.update(
            connection,
            replace(original, name="Updated", updated_at_utc=NOW + timedelta(seconds=1)),
        )
        assert updated.row_version == 2
        with pytest.raises(ProjectConflictError):
            repository.update(connection, replace(original, name="Stale"))
        with pytest.raises(ProjectNotFoundError):
            repository.update(connection, replace(updated, workspace_id="workspace-2"))
    finally:
        connection.close()


def test_archive_is_scoped_and_blocks_mutation(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteProjectRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_workspace(uow.connection, "workspace-1")
        _seed_workspace(uow.connection, "workspace-2")
        repository.create(uow.connection, _project())
        with pytest.raises(ProjectNotFoundError):
            repository.archive(
                uow.connection, "workspace-2", "project-1", 1, NOW + timedelta(seconds=1)
            )
        archived = repository.archive(
            uow.connection, "workspace-1", "project-1", 1, NOW + timedelta(seconds=1)
        )
        assert archived.status is ProjectStatus.ARCHIVED
        assert repository.list_active(uow.connection, "workspace-1") == ()
        with pytest.raises(ProjectArchivedError):
            repository.update(
                uow.connection,
                replace(
                    archived,
                    status=ProjectStatus.PAUSED,
                    archived_at_utc=None,
                ),
            )
