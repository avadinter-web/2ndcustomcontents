from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import AuditEventDraft
from custom_content_studio.application.services import (
    RotateServiceAccountCredentialReference,
    ServiceAccountCredentialService,
)
from custom_content_studio.domain.security import (
    ActorContext,
    ActorType,
    Role,
    SecretReference,
    SecurityError,
)
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteAuditEventRepository,
    SQLiteServiceAccountRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)
OLD_LOCATOR = "synthetic://old/reference"
NEW_LOCATOR = "synthetic://new/reference"


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "rotation.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _seed(
    factory: SQLiteConnectionFactory,
    *,
    status: str = "ACTIVE",
    credential_secret_ref: str | None = OLD_LOCATOR,
) -> None:
    with SQLiteUnitOfWork(factory) as uow:
        for workspace_id in ("workspace-1", "workspace-2"):
            uow.connection.execute(
                "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
                (workspace_id, workspace_id, "2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
            )
        for service_account_id, workspace_id in (
            ("service-account-1", "workspace-1"),
            ("service-account-foreign", "workspace-2"),
        ):
            uow.connection.execute(
                "INSERT INTO service_accounts(id,workspace_id,name,status,permissions_json,"
                "credential_secret_ref,credential_rotated_at,created_at,updated_at) "
                "VALUES (?,?,?,?,?,?,?,?,?)",
                (
                    service_account_id,
                    workspace_id,
                    service_account_id,
                    status,
                    '["render"]',
                    credential_secret_ref,
                    "2026-09-07T00:00:00Z" if credential_secret_ref else None,
                    "2026-09-07T00:00:00Z",
                    "2026-09-08T00:00:00Z",
                ),
            )
        uow.commit()


def _actor() -> ActorContext:
    return ActorContext(
        actor_type=ActorType.USER,
        actor_id="admin-1",
        authentication_id="session-1",
        workspace_id="workspace-1",
        roles=frozenset({Role.ADMIN}),
        scopes=frozenset(),
        authenticated_at_utc=NOW,
    )


def _command(
    *,
    service_account_id: str = "service-account-1",
    expected_updated_at_utc: datetime = NOW,
    rotated_at_utc: datetime = NOW + timedelta(minutes=1),
    new_locator: str = NEW_LOCATOR,
) -> RotateServiceAccountCredentialReference:
    return RotateServiceAccountCredentialReference(
        workspace_id="workspace-1",
        service_account_id=service_account_id,
        actor=_actor(),
        expected_updated_at_utc=expected_updated_at_utc,
        new_secret_ref=SecretReference(new_locator),
        rotated_at_utc=rotated_at_utc,
    )


def _service(
    factory: SQLiteConnectionFactory,
    *,
    event_id: str = "rotation-event-1",
) -> ServiceAccountCredentialService:
    return ServiceAccountCredentialService(
        factory,
        SQLiteServiceAccountRepository(),
        SQLiteAuditEventRepository(),
        event_id_factory=lambda: event_id,
    )


@pytest.mark.parametrize("status", ["ACTIVE", "DISABLED"])
def test_rotation_updates_only_reference_and_appends_hash_only_audit(
    tmp_path: Path,
    status: str,
) -> None:
    factory = _factory(tmp_path)
    _seed(factory, status=status)
    result = _service(factory).rotate_reference(_command())
    connection = factory.connect()
    try:
        account = connection.execute(
            "SELECT name,status,permissions_json,credential_secret_ref,credential_rotated_at,"
            "updated_at,created_at FROM service_accounts WHERE id='service-account-1'"
        ).fetchone()
        audit = connection.execute("SELECT * FROM audit_events").fetchone()
    finally:
        connection.close()

    assert tuple(account) == (
        "service-account-1",
        status,
        '["render"]',
        NEW_LOCATOR,
        "2026-09-08T00:01:00Z",
        "2026-09-08T00:01:00Z",
        "2026-09-07T00:00:00Z",
    )
    payload = json.loads(str(audit["event_json"]))
    assert payload == {
        "_schema": "ccs.service-account-credential-rotation",
        "_version": 1,
        "new_secret_ref_sha256": hashlib.sha256(NEW_LOCATOR.encode()).hexdigest(),
        "old_secret_ref_sha256": hashlib.sha256(OLD_LOCATOR.encode()).hexdigest(),
    }
    assert OLD_LOCATOR not in str(audit["event_json"])
    assert NEW_LOCATOR not in str(audit["event_json"])
    assert (
        audit["stream_key"],
        audit["sequence_no"],
        audit["actor_type"],
        audit["actor_id"],
        audit["action"],
        audit["entity_type"],
        audit["entity_id"],
        audit["occurred_at"],
    ) == (
        "workspace:workspace-1",
        1,
        "USER",
        "admin-1",
        "SERVICE_ACCOUNT_CREDENTIAL_ROTATED",
        "SERVICE_ACCOUNT",
        "service-account-1",
        "2026-09-08T00:01:00Z",
    )
    assert result.audit_event_hash == audit["event_hash"]
    assert result.audit_sequence_no == 1


@pytest.mark.parametrize("target", ["missing-account", "service-account-foreign"])
def test_missing_and_cross_workspace_target_share_safe_denial(
    tmp_path: Path,
    target: str,
) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    with pytest.raises(SecurityError) as caught:
        _service(factory).rotate_reference(_command(service_account_id=target))
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
    rendered = f"{caught.value!r} {caught.value} {caught.value.details}"
    assert target not in rendered
    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM audit_events").fetchone()[0] == 0
    finally:
        connection.close()


def test_stale_version_is_rejected_without_account_or_audit_mutation(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    with pytest.raises(SecurityError) as caught:
        _service(factory).rotate_reference(
            _command(expected_updated_at_utc=NOW - timedelta(seconds=1))
        )
    assert caught.value.code == "VERSION_CONFLICT"
    connection = factory.connect()
    try:
        row = connection.execute(
            "SELECT credential_secret_ref,updated_at FROM service_accounts "
            "WHERE id='service-account-1'"
        ).fetchone()
        audit_count = connection.execute("SELECT COUNT(*) FROM audit_events").fetchone()[0]
    finally:
        connection.close()
    assert tuple(row) == (OLD_LOCATOR, "2026-09-08T00:00:00Z")
    assert audit_count == 0


def test_two_rotations_with_one_expected_version_yield_one_success(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    service = _service(factory)
    first = service.rotate_reference(_command())
    with pytest.raises(SecurityError) as caught:
        service.rotate_reference(
            _command(
                rotated_at_utc=NOW + timedelta(minutes=2),
                new_locator="synthetic://second/reference",
            )
        )
    assert caught.value.code == "VERSION_CONFLICT"
    connection = factory.connect()
    try:
        account = connection.execute(
            "SELECT credential_secret_ref,updated_at FROM service_accounts "
            "WHERE id='service-account-1'"
        ).fetchone()
        audits = connection.execute(
            "SELECT id,sequence_no FROM audit_events ORDER BY sequence_no"
        ).fetchall()
    finally:
        connection.close()
    assert tuple(account) == (NEW_LOCATOR, "2026-09-08T00:01:00Z")
    assert [tuple(row) for row in audits] == [(first.audit_event_id, 1)]


@pytest.mark.parametrize(
    ("seed_ref", "new_locator", "rotated_at"),
    [
        (None, NEW_LOCATOR, NOW + timedelta(minutes=1)),
        (OLD_LOCATOR, OLD_LOCATOR, NOW + timedelta(minutes=1)),
        (OLD_LOCATOR, NEW_LOCATOR, NOW),
    ],
)
def test_invalid_rotation_state_is_rejected_without_mutation(
    tmp_path: Path,
    seed_ref: str | None,
    new_locator: str,
    rotated_at: datetime,
) -> None:
    factory = _factory(tmp_path)
    _seed(factory, credential_secret_ref=seed_ref)
    with pytest.raises(SecurityError) as caught:
        _service(factory).rotate_reference(
            _command(new_locator=new_locator, rotated_at_utc=rotated_at)
        )
    assert caught.value.code == "DOMAIN_VALIDATION_FAILED"
    connection = factory.connect()
    try:
        row = connection.execute(
            "SELECT credential_secret_ref,updated_at FROM service_accounts "
            "WHERE id='service-account-1'"
        ).fetchone()
        audit_count = connection.execute("SELECT COUNT(*) FROM audit_events").fetchone()[0]
    finally:
        connection.close()
    assert tuple(row) == (seed_ref, "2026-09-08T00:00:00Z")
    assert audit_count == 0


def test_audit_insert_failure_rolls_back_reference_rotation(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    duplicate_id = "duplicate-event"
    with SQLiteUnitOfWork(factory) as uow:
        SQLiteAuditEventRepository().append(
            uow.connection,
            AuditEventDraft(
                event_id=duplicate_id,
                workspace_id="workspace-1",
                stream_key="workspace:workspace-1",
                actor_type="USER",
                actor_id="admin-1",
                action="PRIOR_EVENT",
                entity_type="SERVICE_ACCOUNT",
                entity_id="service-account-1",
                event_json={"_schema": "synthetic.prior", "_version": 1},
                occurred_at_utc=NOW,
            ),
        )
        uow.commit()

    with pytest.raises(sqlite3.IntegrityError):
        _service(factory, event_id=duplicate_id).rotate_reference(_command())
    connection = factory.connect()
    try:
        account = connection.execute(
            "SELECT credential_secret_ref,credential_rotated_at,updated_at "
            "FROM service_accounts WHERE id='service-account-1'"
        ).fetchone()
        audit_count = connection.execute("SELECT COUNT(*) FROM audit_events").fetchone()[0]
    finally:
        connection.close()
    assert tuple(account) == (
        OLD_LOCATOR,
        "2026-09-07T00:00:00Z",
        "2026-09-08T00:00:00Z",
    )
    assert audit_count == 1
