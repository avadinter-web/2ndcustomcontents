from __future__ import annotations

import sqlite3
from typing import Protocol

from ...domain.contents import Content


class ContentRepositoryError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class ContentAlreadyExistsError(ContentRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_ALREADY_EXISTS", "content id already exists")


class ContentNotFoundError(ContentRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_SCOPE_NOT_FOUND", "content or project is unavailable")


class ContentConflictError(ContentRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_VERSION_CONFLICT", "content row version is stale")


class ContentArchivedError(ContentRepositoryError):
    def __init__(self) -> None:
        super().__init__("CONTENT_ARCHIVED", "archived content cannot be changed")


class ContentRepositoryPort(Protocol):
    def create(self, connection: sqlite3.Connection, content: Content) -> None: ...

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> Content | None: ...

    def list_for_project(
        self, connection: sqlite3.Connection, workspace_id: str, project_id: str
    ) -> tuple[Content, ...]: ...

    def update(self, connection: sqlite3.Connection, content: Content) -> Content: ...
