from __future__ import annotations

import sqlite3
from typing import Protocol

from ...domain.content_versions import ContentVersion


class ContentVersionRepositoryError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class ContentVersionAlreadyExistsError(ContentVersionRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_VERSION_ALREADY_EXISTS", "content version already exists")


class ContentVersionNotFoundError(ContentVersionRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_VERSION_SCOPE_NOT_FOUND", "content version is unavailable")


class ContentVersionConflictError(ContentVersionRepositoryError):
    def __init__(self) -> None:
        super().__init__("VERSION_CONFLICT", "content authoring head changed")


class ContentVersionRepositoryPort(Protocol):
    def next_version_number(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> int: ...

    def create_and_advance_head(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        expected_content_row_version: int,
        expected_current_version_id: str | None,
        version: ContentVersion,
    ) -> None: ...

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, version_id: str
    ) -> ContentVersion | None: ...

    def list_for_content(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> tuple[ContentVersion, ...]: ...
