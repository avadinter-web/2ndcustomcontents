from __future__ import annotations

import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import SessionService
from custom_content_studio.domain.security import Role, SecurityError
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteSessionRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "service.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _seed_identity(factory: SQLiteConnectionFactory) -> None:
    with SQLiteUnitOfWork(factory) as uow:
        connection = uow.connection
        connection.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES ('user-1','user@example.test','user@example.test','ACTIVE',?,?)",
            ("2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
        )
        for workspace_id in ("workspace-1", "workspace-2"):
            connection.execute(
                "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
                (
                    workspace_id,
                    workspace_id,
                    "2026-09-08T00:00:00Z",
                    "2026-09-08T00:00:00Z",
                ),
            )
        connection.execute(
            "INSERT INTO workspace_memberships("
            "workspace_id,user_id,role,created_at,updated_at) VALUES (?,?,?,?,?)",
            (
                "workspace-1",
                "user-1",
                "EDITOR",
                "2026-09-08T00:00:00Z",
                "2026-09-08T00:00:00Z",
            ),
        )
        uow.commit()


def _service(tmp_path: Path) -> tuple[SQLiteConnectionFactory, SessionService]:
    factory = _factory(tmp_path)
    _seed_identity(factory)
    return factory, SessionService(factory, SQLiteSessionRepository())


def _execute(factory: SQLiteConnectionFactory, sql: str, parameters: tuple[object, ...]) -> None:
    with SQLiteUnitOfWork(factory) as uow:
        uow.connection.execute(sql, parameters)
        uow.commit()


def test_issue_and_authenticate_derive_current_workspace_role(tmp_path: Path) -> None:
    factory, service = _service(tmp_path)
    issued = service.issue(
        "user-1",
        NOW,
        NOW + timedelta(hours=1),
        client_fingerprint_hash="synthetic-fingerprint-hash",
        user_agent_hash="synthetic-user-agent-hash",
    )
    assert issued.raw_token_once not in repr(issued)
    actor = service.authenticate(issued.raw_token_once, "workspace-1", NOW)
    assert actor.actor_id == "user-1"
    assert actor.authentication_id == issued.session_id
    assert actor.workspace_id == "workspace-1"
    assert actor.roles == frozenset({Role.EDITOR})

    _execute(
        factory,
        "UPDATE workspace_memberships SET role='REVIEWER',updated_at=? "
        "WHERE workspace_id='workspace-1' AND user_id='user-1'",
        ("2026-09-08T00:01:00Z",),
    )
    changed = service.authenticate(issued.raw_token_once, "workspace-1", NOW + timedelta(minutes=1))
    assert changed.roles == frozenset({Role.REVIEWER})


def test_membership_removal_and_cross_workspace_reveal_no_target(
    tmp_path: Path,
) -> None:
    factory, service = _service(tmp_path)
    issued = service.issue("user-1", NOW, NOW + timedelta(hours=1))
    for workspace in ("workspace-2", "nonexistent-workspace"):
        with pytest.raises(SecurityError) as caught:
            service.authenticate(issued.raw_token_once, workspace, NOW)
        assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
        assert workspace not in f"{caught.value!r} {caught.value} {caught.value.details}"

    _execute(
        factory,
        "DELETE FROM workspace_memberships WHERE workspace_id=? AND user_id=?",
        ("workspace-1", "user-1"),
    )
    with pytest.raises(SecurityError) as caught:
        service.authenticate(issued.raw_token_once, "workspace-1", NOW)
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"


def test_disabled_expired_revoked_and_malformed_sessions_are_rejected(
    tmp_path: Path,
) -> None:
    factory, service = _service(tmp_path)
    disabled = service.issue("user-1", NOW, NOW + timedelta(hours=1))
    _execute(factory, "UPDATE users SET status='DISABLED' WHERE id=?", ("user-1",))
    with pytest.raises(SecurityError) as caught:
        service.authenticate(disabled.raw_token_once, "workspace-1", NOW)
    assert caught.value.code == "SESSION_EXPIRED"

    _execute(factory, "UPDATE users SET status='ACTIVE' WHERE id=?", ("user-1",))
    expired = service.issue("user-1", NOW, NOW + timedelta(minutes=1))
    with pytest.raises(SecurityError) as caught:
        service.authenticate(expired.raw_token_once, "workspace-1", NOW + timedelta(minutes=2))
    assert caught.value.code == "SESSION_EXPIRED"

    revoked = service.issue("user-1", NOW, NOW + timedelta(hours=1))
    service.revoke(revoked.session_id, "USER_REQUEST", NOW + timedelta(minutes=1))
    service.revoke(revoked.session_id, "USER_REQUEST", NOW + timedelta(minutes=2))
    with pytest.raises(SecurityError) as caught:
        service.authenticate(revoked.raw_token_once, "workspace-1", NOW + timedelta(minutes=2))
    assert caught.value.code == "SESSION_EXPIRED"

    for token in ("", "malformed", f"v1.{'0' * 32}.{'X' * 43}"):
        with pytest.raises(SecurityError) as caught:
            service.authenticate(token, "workspace-1", NOW)
        assert caught.value.code == "AUTHENTICATION_REQUIRED"
        if token:
            assert token not in f"{caught.value!r} {caught.value}"


def test_rotation_is_atomic_and_old_session_stays_revoked_after_reopen(
    tmp_path: Path,
) -> None:
    factory, service = _service(tmp_path)
    first = service.issue("user-1", NOW, NOW + timedelta(hours=1))
    second = service.rotate(
        first.raw_token_once, NOW + timedelta(minutes=1), NOW + timedelta(hours=2)
    )
    assert second.session_family_id == first.session_family_id
    with pytest.raises(SecurityError) as caught:
        service.authenticate(first.raw_token_once, "workspace-1", NOW + timedelta(minutes=1))
    assert caught.value.code == "SESSION_EXPIRED"

    reopened_service = SessionService(factory, SQLiteSessionRepository())
    actor = reopened_service.authenticate(
        second.raw_token_once, "workspace-1", NOW + timedelta(minutes=1)
    )
    assert actor.authentication_id == second.session_id
    connection = factory.connect()
    try:
        rows = connection.execute(
            "SELECT id,session_family_id,rotated_from_session_id,revocation_reason "
            "FROM auth_sessions ORDER BY created_at,id"
        ).fetchall()
    finally:
        connection.close()
    by_id = {str(row["id"]): row for row in rows}
    assert str(by_id[first.session_id]["revocation_reason"]) == "ROTATED"
    assert str(by_id[second.session_id]["rotated_from_session_id"]) == first.session_id


def test_issue_rejects_inactive_or_unknown_user(tmp_path: Path) -> None:
    factory, service = _service(tmp_path)
    _execute(factory, "UPDATE users SET status='DISABLED' WHERE id=?", ("user-1",))
    for user_id in ("user-1", "unknown-user"):
        with pytest.raises(SecurityError) as caught:
            service.issue(user_id, NOW, NOW + timedelta(hours=1))
        assert caught.value.code == "SESSION_EXPIRED"


def test_no_runtime_or_external_database_is_used(tmp_path: Path) -> None:
    factory, service = _service(tmp_path)
    issued = service.issue("user-1", NOW, NOW + timedelta(hours=1))
    service.authenticate(issued.raw_token_once, "workspace-1", NOW)
    assert factory.database_path.parent == tmp_path.resolve()
    assert factory.database_path.exists()
    connection = sqlite3.connect(factory.database_path)
    try:
        assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    finally:
        connection.close()
