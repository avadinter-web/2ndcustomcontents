from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Protocol

from ...domain.content_versions import ContentVersion, ContentVersionStatus
from ...domain.contents import Content, ContentStatus


class ContentStateTransitionRepositoryError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class ContentStateTransitionNotFoundError(ContentStateTransitionRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_STATE_SCOPE_NOT_FOUND", "resource is unavailable")


class ContentStateTransitionConflictError(ContentStateTransitionRepositoryError):
    def __init__(self) -> None:
        super().__init__("VERSION_CONFLICT", "resource row version is stale")


class ContentStateTransitionInvalidError(ContentStateTransitionRepositoryError):
    def __init__(self) -> None:
        super().__init__("INVALID_STATE_TRANSITION", "resource source state changed")


class ContentStateTransitionRepositoryPort(Protocol):
    def get_content(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> Content | None: ...

    def get_content_version(
        self, connection: sqlite3.Connection, workspace_id: str, version_id: str
    ) -> ContentVersion | None: ...

    def transition_content(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        content_id: str,
        expected_row_version: int,
        source: ContentStatus,
        target: ContentStatus,
        transitioned_at_utc: datetime,
    ) -> Content: ...

    def transition_content_version(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        version_id: str,
        expected_row_version: int,
        source: ContentVersionStatus,
        target: ContentVersionStatus,
    ) -> ContentVersion: ...
