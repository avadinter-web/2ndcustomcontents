from __future__ import annotations

import sqlite3
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

AuditValue = str | int


@dataclass(frozen=True)
class AuditEventDraft:
    event_id: str
    workspace_id: str | None
    stream_key: str
    actor_type: str
    actor_id: str | None
    action: str
    entity_type: str
    entity_id: str | None
    event_json: Mapping[str, AuditValue]
    occurred_at_utc: datetime


@dataclass(frozen=True)
class AuditEventRecord:
    event_id: str
    workspace_id: str | None
    stream_key: str
    sequence_no: int
    actor_type: str
    actor_id: str | None
    action: str
    entity_type: str
    entity_id: str | None
    event_json: Mapping[str, AuditValue]
    event_hash: str
    previous_event_hash: str | None
    occurred_at_utc: datetime


class AuditEventAppendPort(Protocol):
    def append(
        self,
        connection: sqlite3.Connection,
        event: AuditEventDraft,
    ) -> AuditEventRecord: ...
