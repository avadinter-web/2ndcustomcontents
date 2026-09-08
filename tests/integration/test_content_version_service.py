from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import ContentVersionService, CreateContentVersion
from custom_content_studio.domain import ContentVersionSnapshot
from custom_content_studio.domain.security import ActorContext, ActorType, Role, SecurityError
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteContentRepository,
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
    factory = SQLiteConnectionFactory((tmp_path / "service.sqlite3").resolve())
    MigrationRunner(factory, ROOT / "migrations").migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        c = uow.connection
        c.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES ('user-1','u@example.test','u@example.test','ACTIVE',?,?)",
            ("2026-09-09T00:00:00Z",) * 2,
        )
        for suffix in ("1", "2"):
            workspace = f"workspace-{suffix}"
            c.execute(
                "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
                (workspace, workspace, "2026-09-09T00:00:00Z", "2026-09-09T00:00:00Z"),
            )
            c.execute(
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
            c.execute(
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
        c.execute(
            "INSERT INTO workspace_memberships(workspace_id,user_id,role,created_at,updated_at) "
            "VALUES ('workspace-1','user-1','EDITOR',?,?)",
            ("2026-09-09T00:00:00Z",) * 2,
        )
        uow.commit()
    return factory


def _actor(actor_type: ActorType = ActorType.USER) -> ActorContext:
    return ActorContext(
        actor_type=actor_type,
        actor_id="user-1" if actor_type is ActorType.USER else "service-1",
        authentication_id="auth-1",
        workspace_id="workspace-1",
        roles=frozenset({Role.EDITOR}),
        scopes=frozenset(),
        authenticated_at_utc=NOW,
    )


def _command(**changes: object) -> CreateContentVersion:
    command = CreateContentVersion(
        actor=_actor(),
        workspace_id="workspace-1",
        content_id="content-1",
        version_id="version-1",
        expected_content_row_version=1,
        expected_current_version_id=None,
        parent_version_id=None,
        snapshot=ContentVersionSnapshot(title="Launch", script=None, content={"body": "hello"}),
        created_at_utc=NOW,
    )
    return replace(command, **changes)


def test_user_creates_monotonic_versions_with_exact_parent_and_head_cas(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = ContentVersionService(
        factory, SQLiteContentRepository(), SQLiteContentVersionRepository()
    )
    first = service.create(_command())
    second = service.create(
        _command(
            version_id="version-2",
            expected_content_row_version=2,
            expected_current_version_id="version-1",
            parent_version_id="version-1",
            created_at_utc=NOW + timedelta(seconds=1),
        )
    )
    assert (first.version_number, second.version_number, second.parent_version_id) == (
        1,
        2,
        "version-1",
    )
    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM content_versions").fetchone()[0] == 2
        assert connection.execute(
            "SELECT current_version_id,row_version FROM contents WHERE id='content-1'"
        ).fetchone()[:] == ("version-2", 3)
    finally:
        connection.close()


def test_creation_rejects_service_accounts_cross_workspace_and_stale_cas(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = ContentVersionService(
        factory, SQLiteContentRepository(), SQLiteContentVersionRepository()
    )
    with pytest.raises(SecurityError) as service_denial:
        service.create(_command(actor=_actor(ActorType.SERVICE_ACCOUNT)))
    assert service_denial.value.code == "WORKSPACE_ACCESS_DENIED"
    with pytest.raises(SecurityError) as scope_denial:
        service.create(_command(content_id="content-2"))
    assert scope_denial.value.code == "WORKSPACE_ACCESS_DENIED"
    service.create(_command())
    with pytest.raises(SecurityError) as stale:
        service.create(_command(version_id="orphan"))
    assert stale.value.code == "VERSION_CONFLICT"
    connection = factory.connect()
    try:
        assert (
            connection.execute(
                "SELECT COUNT(*) FROM content_versions WHERE id='orphan'"
            ).fetchone()[0]
            == 0
        )
    finally:
        connection.close()
