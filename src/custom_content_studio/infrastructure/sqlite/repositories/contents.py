from __future__ import annotations

import sqlite3
from datetime import UTC, datetime

from ....application.ports.content_repository import (
    ContentAlreadyExistsError,
    ContentArchivedError,
    ContentConflictError,
    ContentNotFoundError,
    ContentRepositoryError,
)
from ....domain.contents import Content, ContentStatus, ContentType


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise ContentRepositoryError("CONTENT_DATA_INVALID", "content timestamp is invalid")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ContentRepositoryError(
            "CONTENT_DATA_INVALID", "content timestamp is invalid"
        ) from error
    if parsed.tzinfo is None:
        raise ContentRepositoryError("CONTENT_DATA_INVALID", "content timestamp is invalid")
    return parsed.astimezone(UTC)


def _to_content(row: sqlite3.Row) -> Content:
    if row["current_version_id"] is not None:
        raise ContentRepositoryError(
            "CONTENT_DATA_INVALID", "current version linkage is outside this repository"
        )
    archived_at = row["archived_at"]
    return Content(
        content_id=str(row["id"]),
        workspace_id=str(row["workspace_id"]),
        project_id=str(row["project_id"]),
        title=str(row["title"]),
        content_type=ContentType(str(row["content_type"])),
        primary_platform=(
            None if row["primary_platform"] is None else str(row["primary_platform"])
        ),
        goal=None if row["goal"] is None else str(row["goal"]),
        status=ContentStatus(str(row["status"])),
        current_version_id=None,
        created_at_utc=_datetime(row["created_at"]),
        updated_at_utc=_datetime(row["updated_at"]),
        archived_at_utc=None if archived_at is None else _datetime(archived_at),
        row_version=int(row["row_version"]),
    )


_SELECT = (
    "SELECT id,workspace_id,project_id,title,content_type,primary_platform,goal,status,"
    "current_version_id,created_at,updated_at,archived_at,row_version FROM contents"
)


class SQLiteContentRepository:
    def create(self, connection: sqlite3.Connection, content: Content) -> None:
        if (
            content.status is not ContentStatus.IDEA
            or content.current_version_id is not None
            or content.archived_at_utc is not None
            or content.row_version != 1
        ):
            raise ValueError("new content must start as unversioned IDEA at row_version 1")
        self._require_project(connection, content.workspace_id, content.project_id)
        try:
            connection.execute(
                "INSERT INTO contents(id,workspace_id,project_id,title,content_type,"
                "primary_platform,goal,status,current_version_id,created_at,updated_at,"
                "archived_at,row_version) VALUES (?,?,?,?,?,?,?,'IDEA',NULL,?,?,NULL,1)",
                (
                    content.content_id,
                    content.workspace_id,
                    content.project_id,
                    content.title,
                    content.content_type.value,
                    content.primary_platform,
                    content.goal,
                    _iso(content.created_at_utc),
                    _iso(content.updated_at_utc),
                ),
            )
        except sqlite3.IntegrityError as error:
            existing = connection.execute(
                "SELECT 1 FROM contents WHERE id=?", (content.content_id,)
            ).fetchone()
            if existing is not None:
                raise ContentAlreadyExistsError() from error
            raise ContentRepositoryError(
                "CONTENT_WRITE_FAILED", "content could not be created"
            ) from error

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> Content | None:
        row = connection.execute(
            f"{_SELECT} WHERE workspace_id=? AND id=?", (workspace_id, content_id)
        ).fetchone()
        return None if row is None else _to_content(row)

    def list_for_project(
        self, connection: sqlite3.Connection, workspace_id: str, project_id: str
    ) -> tuple[Content, ...]:
        rows = connection.execute(
            f"{_SELECT} WHERE workspace_id=? AND project_id=? ORDER BY created_at,id",
            (workspace_id, project_id),
        ).fetchall()
        return tuple(_to_content(row) for row in rows)

    def update(self, connection: sqlite3.Connection, content: Content) -> Content:
        if content.is_archived:
            raise ContentArchivedError()
        cursor = connection.execute(
            "UPDATE contents SET title=?,content_type=?,primary_platform=?,goal=?,updated_at=?,"
            "row_version=row_version+1 WHERE workspace_id=? AND id=? AND project_id=? "
            "AND row_version=? AND status<>'ARCHIVED' AND current_version_id IS NULL",
            (
                content.title,
                content.content_type.value,
                content.primary_platform,
                content.goal,
                _iso(content.updated_at_utc),
                content.workspace_id,
                content.content_id,
                content.project_id,
                content.row_version,
            ),
        )
        if cursor.rowcount != 1:
            self._raise_write_failure(
                connection, content.workspace_id, content.content_id, content.row_version
            )
        updated = self.get_by_id(connection, content.workspace_id, content.content_id)
        if updated is None:
            raise ContentNotFoundError()
        return updated

    @staticmethod
    def _require_project(
        connection: sqlite3.Connection, workspace_id: str, project_id: str
    ) -> None:
        project = connection.execute(
            "SELECT 1 FROM projects WHERE workspace_id=? AND id=? AND status<>'ARCHIVED'",
            (workspace_id, project_id),
        ).fetchone()
        if project is None:
            raise ContentNotFoundError()

    @staticmethod
    def _raise_write_failure(
        connection: sqlite3.Connection,
        workspace_id: str,
        content_id: str,
        expected_row_version: int,
    ) -> None:
        row = connection.execute(
            "SELECT status,current_version_id,row_version FROM contents "
            "WHERE workspace_id=? AND id=?",
            (workspace_id, content_id),
        ).fetchone()
        if row is None:
            raise ContentNotFoundError()
        if row["status"] == "ARCHIVED":
            raise ContentArchivedError()
        if row["current_version_id"] is not None:
            raise ContentRepositoryError(
                "CONTENT_LINKAGE_OWNED_ELSEWHERE", "current version linkage cannot be changed"
            )
        if int(row["row_version"]) != expected_row_version:
            raise ContentConflictError()
        raise ContentConflictError()
