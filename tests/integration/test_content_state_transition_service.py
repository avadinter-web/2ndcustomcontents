from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import (
    ActivateContent,
    ArchiveContent,
    ContentStateTransitionService,
    SubmitContentVersionForReview,
)
from custom_content_studio.domain import ContentVersionSnapshot, compute_snapshot_hash
from custom_content_studio.domain.security import ActorContext, ActorType, Role, SecurityError
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
SNAPSHOT_HASH = compute_snapshot_hash(
    "content-1", 1, ContentVersionSnapshot(title="Launch", script=None, content={})
)


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
        c.execute(
            "INSERT INTO content_versions(id,content_id,version_number,status,title_snapshot,"
            "content_snapshot_json,snapshot_hash,created_by,created_at) "
            "VALUES ('version-1','content-1',1,'DRAFT','Launch',?,?,'user-1',?)",
            (SNAPSHOT, SNAPSHOT_HASH, "2026-09-09T00:00:00Z"),
        )
        c.execute("UPDATE contents SET current_version_id='version-1' WHERE id='content-1'")
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


def test_service_executes_only_three_valid_edges(tmp_path: Path) -> None:
    service = ContentStateTransitionService(
        _factory(tmp_path), SQLiteContentStateTransitionRepository()
    )
    active = service.activate(
        ActivateContent(_actor(), "workspace-1", "content-1", 1, NOW + timedelta(seconds=1))
    )
    archived = service.archive(
        ArchiveContent(_actor(), "workspace-1", "content-1", 2, NOW + timedelta(seconds=2))
    )
    reviewed = service.submit_for_review(
        SubmitContentVersionForReview(
            _actor(), "workspace-1", "version-1", 1, NOW + timedelta(seconds=1)
        )
    )
    assert active.status.value == "ACTIVE"
    assert archived.status.value == "ARCHIVED" and archived.archived_at_utc == NOW + timedelta(
        seconds=2
    )
    assert reviewed.status.value == "REVIEW_REQUIRED"


def test_service_rejects_invalid_stale_scope_and_service_account(tmp_path: Path) -> None:
    service = ContentStateTransitionService(
        _factory(tmp_path), SQLiteContentStateTransitionRepository()
    )
    with pytest.raises(SecurityError) as invalid:
        service.archive(
            ArchiveContent(_actor(), "workspace-1", "content-1", 1, NOW + timedelta(seconds=1))
        )
    assert invalid.value.code == "INVALID_STATE_TRANSITION"
    assert invalid.value.details["current_state"] == "IDEA"
    with pytest.raises(SecurityError) as stale:
        service.activate(
            ActivateContent(_actor(), "workspace-1", "content-1", 2, NOW + timedelta(seconds=1))
        )
    assert stale.value.code == "VERSION_CONFLICT"
    with pytest.raises(SecurityError) as hidden:
        service.activate(
            ActivateContent(_actor(), "workspace-1", "content-2", 1, NOW + timedelta(seconds=1))
        )
    assert hidden.value.code == "WORKSPACE_ACCESS_DENIED"
    command = ActivateContent(_actor(), "workspace-1", "content-1", 1, NOW + timedelta(seconds=1))
    with pytest.raises(SecurityError) as actor_denial:
        service.activate(replace(command, actor=_actor(ActorType.SERVICE_ACCOUNT)))
    assert actor_denial.value.code == "WORKSPACE_ACCESS_DENIED"
