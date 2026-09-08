from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Protocol

from ...domain.workspaces import Workspace


class WorkspaceRepositoryError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class WorkspaceAlreadyExistsError(WorkspaceRepositoryError):
    def __init__(self) -> None:
        super().__init__("WORKSPACE_ALREADY_EXISTS", "workspace id already exists")


class WorkspaceNotFoundError(WorkspaceRepositoryError):
    def __init__(self) -> None:
        super().__init__("WORKSPACE_NOT_FOUND", "workspace does not exist")


class WorkspaceConflictError(WorkspaceRepositoryError):
    def __init__(self) -> None:
        super().__init__("WORKSPACE_VERSION_CONFLICT", "workspace row version is stale")


class WorkspaceArchivedError(WorkspaceRepositoryError):
    def __init__(self) -> None:
        super().__init__("WORKSPACE_ARCHIVED", "archived workspace cannot be changed")


class WorkspaceRepositoryPort(Protocol):
    def create(self, connection: sqlite3.Connection, workspace: Workspace) -> None: ...

    def get_by_id(self, connection: sqlite3.Connection, workspace_id: str) -> Workspace | None: ...

    def list_active(self, connection: sqlite3.Connection) -> tuple[Workspace, ...]: ...

    def update(self, connection: sqlite3.Connection, workspace: Workspace) -> Workspace: ...

    def archive(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        expected_row_version: int,
        archived_at_utc: datetime,
    ) -> Workspace: ...
