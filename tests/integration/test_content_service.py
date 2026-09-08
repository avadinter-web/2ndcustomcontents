import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import (
    ContentService,
    CreateContent,
    UpdateContent,
)
from custom_content_studio.domain import ContentStatus, ContentType
from custom_content_studio.domain.security import ActorContext, ActorType, Role, SecurityError
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
    factory = SQLiteConnectionFactory((tmp_path / "content-service.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        uow.commit()
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


def _actor(*, workspace_id: str = "workspace-1", role: Role = Role.EDITOR) -> ActorContext:
    return ActorContext(
        actor_type=ActorType.USER,
        actor_id="user-1",
        authentication_id="session-1",
        workspace_id=workspace_id,
        roles=frozenset({role}),
        scopes=frozenset(),
        authenticated_at_utc=NOW,
    )


def _create(
    *,
    actor: ActorContext | None = None,
    content_id: str = "content-1",
    project_id: str = "project-1",
) -> CreateContent:
    return CreateContent(
        actor=actor or _actor(),
        content_id=content_id,
        workspace_id="workspace-1",
        project_id=project_id,
        title="Launch",
        content_type=ContentType.SHORT,
        primary_platform="YOUTUBE",
        goal="Awareness",
        created_at_utc=NOW,
    )


def test_create_forces_initial_idea_without_version_or_archive(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = ContentService(factory, SQLiteContentRepository())
    content = service.create(_create())
    assert content.status is ContentStatus.IDEA
    assert content.current_version_id is None
    assert content.archived_at_utc is None
    assert content.row_version == 1


@pytest.mark.parametrize("actor", [_actor(role=Role.VIEWER), _actor(workspace_id="workspace-2")])
def test_create_requires_existing_content_edit_authorization(
    tmp_path: Path, actor: ActorContext
) -> None:
    factory = _factory(tmp_path)
    service = ContentService(factory, SQLiteContentRepository())
    with pytest.raises(SecurityError) as caught:
        service.create(_create(actor=actor))
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"


def test_cross_workspace_project_is_concealed(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = ContentService(factory, SQLiteContentRepository())
    with pytest.raises(SecurityError) as caught:
        service.create(_create(project_id="project-2"))
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"


def test_descriptive_update_uses_cas_and_preserves_identity_and_state(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = ContentService(factory, SQLiteContentRepository())
    actor = _actor()
    service.create(_create(actor=actor))
    updated = service.update(
        UpdateContent(
            actor=actor,
            workspace_id="workspace-1",
            content_id="content-1",
            expected_row_version=1,
            title="Updated",
            content_type=ContentType.REEL,
            primary_platform="INSTAGRAM",
            goal=None,
            updated_at_utc=NOW + timedelta(seconds=1),
        )
    )
    assert updated.row_version == 2
    assert updated.project_id == "project-1"
    assert updated.status is ContentStatus.IDEA
    assert updated.current_version_id is None

    with pytest.raises(SecurityError) as caught:
        service.update(
            UpdateContent(
                actor=actor,
                workspace_id="workspace-1",
                content_id="content-1",
                expected_row_version=1,
                title="Stale",
                content_type=ContentType.SHORT,
                primary_platform=None,
                goal=None,
                updated_at_utc=NOW + timedelta(seconds=2),
            )
        )
    assert caught.value.code == "VERSION_CONFLICT"


@pytest.mark.parametrize("content_id", ["missing", "foreign"])
def test_missing_and_cross_workspace_content_share_safe_denial(
    tmp_path: Path, content_id: str
) -> None:
    factory = _factory(tmp_path)
    service = ContentService(factory, SQLiteContentRepository())
    if content_id == "foreign":
        connection = factory.connect()
        try:
            connection.execute(
                "INSERT INTO contents(id,workspace_id,project_id,title,content_type,status,"
                "created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)",
                (
                    "foreign",
                    "workspace-2",
                    "project-2",
                    "Foreign",
                    "SHORT",
                    "IDEA",
                    "2026-09-09T00:00:00Z",
                    "2026-09-09T00:00:00Z",
                ),
            )
        finally:
            connection.close()
    with pytest.raises(SecurityError) as caught:
        service.update(
            UpdateContent(
                actor=_actor(),
                workspace_id="workspace-1",
                content_id=content_id,
                expected_row_version=1,
                title="Hidden",
                content_type=ContentType.SHORT,
                primary_platform=None,
                goal=None,
                updated_at_utc=NOW + timedelta(seconds=1),
            )
        )
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
    assert content_id not in str(caught.value)
