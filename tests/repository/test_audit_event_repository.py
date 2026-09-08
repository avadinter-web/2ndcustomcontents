from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import AuditEventDraft
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteAuditEventRepository,
    canonical_event_json,
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
    factory = SQLiteConnectionFactory((tmp_path / "audit.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        uow.connection.execute(
            "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
            ("workspace-1", "Workspace", "2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
        )
        uow.commit()
    return factory


def _event(event_id: str, occurred_at: datetime = NOW) -> AuditEventDraft:
    return AuditEventDraft(
        event_id=event_id,
        workspace_id="workspace-1",
        stream_key="workspace:workspace-1",
        actor_type="USER",
        actor_id="user-1",
        action="SERVICE_ACCOUNT_CREDENTIAL_ROTATED",
        entity_type="SERVICE_ACCOUNT",
        entity_id="service-account-1",
        event_json={"z": "last", "_version": 1, "a": "first"},
        occurred_at_utc=occurred_at,
    )


def _expected_hash(
    event: AuditEventDraft, sequence_no: int, previous_event_hash: str | None
) -> str:
    envelope = {
        "id": event.event_id,
        "workspace_id": event.workspace_id,
        "stream_key": event.stream_key,
        "sequence_no": sequence_no,
        "actor_type": event.actor_type,
        "actor_id": event.actor_id,
        "action": event.action,
        "entity_type": event.entity_type,
        "entity_id": event.entity_id,
        "event_json": dict(event.event_json),
        "previous_event_hash": previous_event_hash,
        "occurred_at": event.occurred_at_utc.isoformat().replace("+00:00", "Z"),
    }
    canonical = json.dumps(envelope, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def test_append_persists_canonical_hash_chain(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAuditEventRepository()
    first_event = _event("event-1")
    second_event = _event("event-2", NOW + timedelta(seconds=1))
    with SQLiteUnitOfWork(factory) as uow:
        first = repository.append(uow.connection, first_event)
        second = repository.append(uow.connection, second_event)
        uow.commit()

    assert first.sequence_no == 1
    assert first.previous_event_hash is None
    assert first.event_hash == _expected_hash(first_event, 1, None)
    assert second.sequence_no == 2
    assert second.previous_event_hash == first.event_hash
    assert second.event_hash == _expected_hash(second_event, 2, first.event_hash)
    connection = factory.connect()
    try:
        rows = connection.execute(
            "SELECT sequence_no,event_json,event_hash,previous_event_hash "
            "FROM audit_events ORDER BY sequence_no"
        ).fetchall()
    finally:
        connection.close()
    assert len(rows) == 2
    assert rows[0]["event_json"] == '{"_version":1,"a":"first","z":"last"}'
    assert rows[1]["previous_event_hash"] == rows[0]["event_hash"]


def test_repository_does_not_commit_caller_transaction(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAuditEventRepository()
    with SQLiteUnitOfWork(factory) as uow:
        repository.append(uow.connection, _event("event-rollback"))
    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM audit_events").fetchone()[0] == 0
    finally:
        connection.close()


def test_database_rejects_audit_update_and_delete(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAuditEventRepository()
    with SQLiteUnitOfWork(factory) as uow:
        repository.append(uow.connection, _event("immutable-event"))
        uow.commit()

    for statement in (
        "UPDATE audit_events SET action='CHANGED' WHERE id='immutable-event'",
        "DELETE FROM audit_events WHERE id='immutable-event'",
    ):
        with (
            SQLiteUnitOfWork(factory) as uow,
            pytest.raises(sqlite3.IntegrityError, match="append-only"),
        ):
            uow.connection.execute(statement)


def test_canonical_event_json_is_utf8_stable_and_space_free() -> None:
    assert canonical_event_json({"한글": "값", "a": 1}) == '{"a":1,"한글":"값"}'
