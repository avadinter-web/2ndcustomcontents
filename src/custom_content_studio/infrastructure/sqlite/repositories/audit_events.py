from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import UTC, datetime

from ....application.ports.audit_event_repository import AuditEventDraft, AuditEventRecord


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def canonical_event_json(event_json: object) -> str:
    return _canonical_json(event_json)


def compute_audit_event_hash(
    *,
    event: AuditEventDraft,
    sequence_no: int,
    previous_event_hash: str | None,
) -> str:
    envelope = {
        "action": event.action,
        "actor_id": event.actor_id,
        "actor_type": event.actor_type,
        "entity_id": event.entity_id,
        "entity_type": event.entity_type,
        "event_json": dict(event.event_json),
        "id": event.event_id,
        "occurred_at": _iso(event.occurred_at_utc),
        "previous_event_hash": previous_event_hash,
        "sequence_no": sequence_no,
        "stream_key": event.stream_key,
        "workspace_id": event.workspace_id,
    }
    return hashlib.sha256(_canonical_json(envelope).encode("utf-8")).hexdigest()


class SQLiteAuditEventRepository:
    def append(
        self,
        connection: sqlite3.Connection,
        event: AuditEventDraft,
    ) -> AuditEventRecord:
        head = connection.execute(
            "SELECT sequence_no,event_hash FROM audit_events WHERE stream_key=? "
            "ORDER BY sequence_no DESC LIMIT 1",
            (event.stream_key,),
        ).fetchone()
        sequence_no = 1 if head is None else int(head["sequence_no"]) + 1
        previous_event_hash = None if head is None else str(head["event_hash"])
        event_hash = compute_audit_event_hash(
            event=event,
            sequence_no=sequence_no,
            previous_event_hash=previous_event_hash,
        )
        connection.execute(
            "INSERT INTO audit_events(id,workspace_id,stream_key,sequence_no,actor_type,"
            "actor_id,action,entity_type,entity_id,event_json,event_hash,previous_event_hash,"
            "occurred_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                event.event_id,
                event.workspace_id,
                event.stream_key,
                sequence_no,
                event.actor_type,
                event.actor_id,
                event.action,
                event.entity_type,
                event.entity_id,
                canonical_event_json(dict(event.event_json)),
                event_hash,
                previous_event_hash,
                _iso(event.occurred_at_utc),
            ),
        )
        return AuditEventRecord(
            event_id=event.event_id,
            workspace_id=event.workspace_id,
            stream_key=event.stream_key,
            sequence_no=sequence_no,
            actor_type=event.actor_type,
            actor_id=event.actor_id,
            action=event.action,
            entity_type=event.entity_type,
            entity_id=event.entity_id,
            event_json=event.event_json,
            event_hash=event_hash,
            previous_event_hash=previous_event_hash,
            occurred_at_utc=event.occurred_at_utc,
        )
