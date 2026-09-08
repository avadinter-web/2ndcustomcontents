from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Protocol

from ...domain.security import Role, StoredSession


class SessionRepositoryPort(Protocol):
    def add(
        self,
        connection: sqlite3.Connection,
        session: StoredSession,
        raw_token: str,
    ) -> None: ...

    def find_by_token(
        self, connection: sqlite3.Connection, raw_token: str
    ) -> StoredSession | None: ...

    def get(self, connection: sqlite3.Connection, session_id: str) -> StoredSession | None: ...

    def user_is_active(self, connection: sqlite3.Connection, user_id: str) -> bool: ...

    def role_for_workspace(
        self,
        connection: sqlite3.Connection,
        user_id: str,
        workspace_id: str,
    ) -> Role | None: ...

    def mark_seen(
        self,
        connection: sqlite3.Connection,
        session_id: str,
        seen_at_utc: datetime,
    ) -> None: ...

    def revoke(
        self,
        connection: sqlite3.Connection,
        session_id: str,
        reason: str,
        revoked_at_utc: datetime,
    ) -> None: ...
