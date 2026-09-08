from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Protocol

from ...domain.projects import Project


class ProjectRepositoryError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class ProjectAlreadyExistsError(ProjectRepositoryError):
    def __init__(self) -> None:
        super().__init__("PROJECT_ALREADY_EXISTS", "project id already exists")


class ProjectNotFoundError(ProjectRepositoryError):
    def __init__(self) -> None:
        super().__init__("PROJECT_NOT_FOUND", "project does not exist in workspace")


class ProjectConflictError(ProjectRepositoryError):
    def __init__(self) -> None:
        super().__init__("PROJECT_VERSION_CONFLICT", "project row version is stale")


class ProjectArchivedError(ProjectRepositoryError):
    def __init__(self) -> None:
        super().__init__("PROJECT_ARCHIVED", "archived project cannot be changed")


class ProjectRepositoryPort(Protocol):
    def create(self, connection: sqlite3.Connection, project: Project) -> None: ...

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, project_id: str
    ) -> Project | None: ...

    def list_active(
        self, connection: sqlite3.Connection, workspace_id: str
    ) -> tuple[Project, ...]: ...

    def update(self, connection: sqlite3.Connection, project: Project) -> Project: ...

    def archive(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        project_id: str,
        expected_row_version: int,
        archived_at_utc: datetime,
    ) -> Project: ...
