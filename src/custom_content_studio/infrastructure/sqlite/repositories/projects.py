from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime, timedelta

from ....application.ports.project_repository import (
    ProjectAlreadyExistsError,
    ProjectArchivedError,
    ProjectConflictError,
    ProjectNotFoundError,
    ProjectRepositoryError,
)
from ....domain.projects import Project, ProjectStatus


def _iso(value: datetime) -> str:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError("timestamp must be timezone-aware UTC")
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise ProjectRepositoryError("PROJECT_DATA_INVALID", "project timestamp is invalid")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ProjectRepositoryError(
            "PROJECT_DATA_INVALID", "project timestamp is invalid"
        ) from error
    if parsed.tzinfo is None:
        raise ProjectRepositoryError("PROJECT_DATA_INVALID", "project timestamp is invalid")
    return parsed.astimezone(UTC)


def _platforms(value: object) -> tuple[str, ...]:
    if not isinstance(value, str):
        raise ProjectRepositoryError("PROJECT_DATA_INVALID", "project platforms are invalid")
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as error:
        raise ProjectRepositoryError(
            "PROJECT_DATA_INVALID", "project platforms are invalid"
        ) from error
    if not isinstance(parsed, list) or any(not isinstance(item, str) for item in parsed):
        raise ProjectRepositoryError("PROJECT_DATA_INVALID", "project platforms are invalid")
    return tuple(parsed)


def _to_project(row: sqlite3.Row) -> Project:
    archived_at = row["archived_at"]
    return Project(
        project_id=str(row["id"]),
        workspace_id=str(row["workspace_id"]),
        name=str(row["name"]),
        description=None if row["description"] is None else str(row["description"]),
        content_type=None if row["content_type"] is None else str(row["content_type"]),
        default_language=str(row["default_language"]),
        default_platforms=_platforms(row["default_platforms_json"]),
        brand_profile_ref=(
            None if row["brand_profile_ref"] is None else str(row["brand_profile_ref"])
        ),
        status=ProjectStatus(str(row["status"])),
        created_at_utc=_datetime(row["created_at"]),
        updated_at_utc=_datetime(row["updated_at"]),
        archived_at_utc=None if archived_at is None else _datetime(archived_at),
        row_version=int(row["row_version"]),
    )


_SELECT = (
    "SELECT id,workspace_id,name,description,content_type,default_language,"
    "default_platforms_json,brand_profile_ref,status,created_at,updated_at,archived_at,"
    "row_version FROM projects"
)


class SQLiteProjectRepository:
    def create(self, connection: sqlite3.Connection, project: Project) -> None:
        if project.row_version != 1 or project.is_archived:
            raise ValueError("new project must be active at row_version 1")
        try:
            connection.execute(
                "INSERT INTO projects(id,workspace_id,name,description,content_type,"
                "default_language,default_platforms_json,brand_profile_ref,status,created_at,"
                "updated_at,archived_at,row_version) VALUES (?,?,?,?,?,?,?,?,?,?,?,NULL,1)",
                (
                    project.project_id,
                    project.workspace_id,
                    project.name,
                    project.description,
                    project.content_type,
                    project.default_language,
                    json.dumps(
                        project.default_platforms, ensure_ascii=False, separators=(",", ":")
                    ),
                    project.brand_profile_ref,
                    project.status.value,
                    _iso(project.created_at_utc),
                    _iso(project.updated_at_utc),
                ),
            )
        except sqlite3.IntegrityError as error:
            existing = connection.execute(
                "SELECT 1 FROM projects WHERE id=?", (project.project_id,)
            ).fetchone()
            if existing is not None:
                raise ProjectAlreadyExistsError() from error
            raise ProjectRepositoryError(
                "PROJECT_WRITE_FAILED", "project could not be created"
            ) from error

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, project_id: str
    ) -> Project | None:
        row = connection.execute(
            f"{_SELECT} WHERE workspace_id=? AND id=?", (workspace_id, project_id)
        ).fetchone()
        return None if row is None else _to_project(row)

    def list_active(self, connection: sqlite3.Connection, workspace_id: str) -> tuple[Project, ...]:
        rows = connection.execute(
            f"{_SELECT} WHERE workspace_id=? AND status<>'ARCHIVED' "
            "AND archived_at IS NULL ORDER BY created_at,id",
            (workspace_id,),
        ).fetchall()
        return tuple(_to_project(row) for row in rows)

    def update(self, connection: sqlite3.Connection, project: Project) -> Project:
        if project.is_archived:
            raise ProjectArchivedError()
        cursor = connection.execute(
            "UPDATE projects SET name=?,description=?,content_type=?,default_language=?,"
            "default_platforms_json=?,brand_profile_ref=?,status=?,updated_at=?,"
            "row_version=row_version+1 WHERE workspace_id=? AND id=? AND row_version=? "
            "AND status<>'ARCHIVED' AND archived_at IS NULL",
            (
                project.name,
                project.description,
                project.content_type,
                project.default_language,
                json.dumps(project.default_platforms, ensure_ascii=False, separators=(",", ":")),
                project.brand_profile_ref,
                project.status.value,
                _iso(project.updated_at_utc),
                project.workspace_id,
                project.project_id,
                project.row_version,
            ),
        )
        if cursor.rowcount != 1:
            self._raise_write_failure(
                connection, project.workspace_id, project.project_id, project.row_version
            )
        updated = self.get_by_id(connection, project.workspace_id, project.project_id)
        if updated is None:
            raise ProjectNotFoundError()
        return updated

    def archive(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        project_id: str,
        expected_row_version: int,
        archived_at_utc: datetime,
    ) -> Project:
        archived_at = _iso(archived_at_utc)
        cursor = connection.execute(
            "UPDATE projects SET status='ARCHIVED',archived_at=?,updated_at=?,"
            "row_version=row_version+1 WHERE workspace_id=? AND id=? AND row_version=? "
            "AND status<>'ARCHIVED' AND archived_at IS NULL",
            (archived_at, archived_at, workspace_id, project_id, expected_row_version),
        )
        if cursor.rowcount != 1:
            self._raise_write_failure(connection, workspace_id, project_id, expected_row_version)
        archived = self.get_by_id(connection, workspace_id, project_id)
        if archived is None:
            raise ProjectNotFoundError()
        return archived

    @staticmethod
    def _raise_write_failure(
        connection: sqlite3.Connection,
        workspace_id: str,
        project_id: str,
        expected_row_version: int,
    ) -> None:
        row = connection.execute(
            "SELECT status,archived_at,row_version FROM projects WHERE workspace_id=? AND id=?",
            (workspace_id, project_id),
        ).fetchone()
        if row is None:
            raise ProjectNotFoundError()
        if row["status"] == "ARCHIVED" or row["archived_at"] is not None:
            raise ProjectArchivedError()
        if int(row["row_version"]) != expected_row_version:
            raise ProjectConflictError()
        raise ProjectConflictError()
