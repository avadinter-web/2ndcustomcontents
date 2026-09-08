from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime

from ....application.ports.content_version_repository import (
    ContentVersionAlreadyExistsError,
    ContentVersionConflictError,
    ContentVersionNotFoundError,
    ContentVersionRepositoryError,
)
from ....domain.content_versions import (
    SNAPSHOT_SCHEMA,
    SNAPSHOT_VERSION,
    ContentVersion,
    ContentVersionSnapshot,
    ContentVersionStatus,
)


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "content version timestamp is invalid"
        )
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "content version timestamp is invalid"
        ) from error
    if parsed.tzinfo is None:
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "content version timestamp is invalid"
        )
    return parsed.astimezone(UTC)


def _snapshot(value: object) -> ContentVersionSnapshot:
    if not isinstance(value, str):
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "content version snapshot is invalid"
        )
    try:
        envelope = json.loads(value)
        if not isinstance(envelope, dict) or set(envelope) != {"_schema", "_version", "data"}:
            raise ValueError
        if envelope["_schema"] != SNAPSHOT_SCHEMA or envelope["_version"] != SNAPSHOT_VERSION:
            raise ValueError
        data = envelope["data"]
        if not isinstance(data, dict) or set(data) != {"title", "script", "content"}:
            raise ValueError
        title = data["title"]
        script = data["script"]
        content = data["content"]
        if not isinstance(title, str) or not title:
            raise ValueError
        if script is not None and not isinstance(script, dict):
            raise ValueError
        if not isinstance(content, dict):
            raise ValueError
        return ContentVersionSnapshot(title=title, script=script, content=content)
    except (json.JSONDecodeError, TypeError, ValueError) as error:
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "content version snapshot is invalid"
        ) from error


def _to_version(row: sqlite3.Row) -> ContentVersion:
    snapshot = _snapshot(row["content_snapshot_json"])
    if row["title_snapshot"] != snapshot.title:
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "title snapshot projection is invalid"
        )
    if row["script_snapshot_json"] != snapshot.canonical_script_json():
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "script snapshot projection is invalid"
        )
    try:
        return ContentVersion(
            version_id=str(row["id"]),
            content_id=str(row["content_id"]),
            version_number=int(row["version_number"]),
            parent_version_id=(
                None if row["parent_version_id"] is None else str(row["parent_version_id"])
            ),
            status=ContentVersionStatus(str(row["status"])),
            snapshot=snapshot,
            snapshot_hash=str(row["snapshot_hash"]),
            created_by=str(row["created_by"]),
            created_at_utc=_datetime(row["created_at"]),
            row_version=int(row["row_version"]),
        )
    except (TypeError, ValueError) as error:
        raise ContentVersionRepositoryError(
            "CONTENT_VERSION_DATA_INVALID", "content version row is invalid"
        ) from error


_SELECT = (
    "SELECT cv.id,cv.content_id,cv.version_number,cv.parent_version_id,cv.status,"
    "cv.title_snapshot,cv.script_snapshot_json,cv.content_snapshot_json,cv.snapshot_hash,"
    "cv.created_by,cv.created_at,cv.row_version FROM content_versions cv JOIN contents c "
    "ON c.id=cv.content_id"
)


class SQLiteContentVersionRepository:
    def next_version_number(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> int:
        row = connection.execute(
            "SELECT COALESCE(MAX(cv.version_number),0)+1 FROM contents c "
            "LEFT JOIN content_versions cv ON cv.content_id=c.id "
            "WHERE c.workspace_id=? AND c.id=? GROUP BY c.id",
            (workspace_id, content_id),
        ).fetchone()
        if row is None or row[0] is None:
            raise ContentVersionNotFoundError()
        return int(row[0])

    def create_and_advance_head(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        expected_content_row_version: int,
        expected_current_version_id: str | None,
        version: ContentVersion,
    ) -> None:
        if version.status is not ContentVersionStatus.DRAFT or version.row_version != 1:
            raise ValueError("new content versions must start DRAFT at row_version 1")
        if version.parent_version_id != expected_current_version_id:
            raise ContentVersionConflictError()
        try:
            connection.execute(
                "INSERT INTO content_versions(id,content_id,version_number,parent_version_id,"
                "status,title_snapshot,script_snapshot_json,content_snapshot_json,snapshot_hash,"
                "created_by,created_at,approved_at,approved_by,row_version) "
                "VALUES (?,?,?,?,'DRAFT',?,?,?,?,?,?,NULL,NULL,1)",
                (
                    version.version_id,
                    version.content_id,
                    version.version_number,
                    version.parent_version_id,
                    version.snapshot.title,
                    version.snapshot.canonical_script_json(),
                    version.snapshot.canonical_json(),
                    version.snapshot_hash,
                    version.created_by,
                    _iso(version.created_at_utc),
                ),
            )
        except sqlite3.IntegrityError as error:
            duplicate = connection.execute(
                "SELECT 1 FROM content_versions WHERE id=? OR (content_id=? AND version_number=?)",
                (version.version_id, version.content_id, version.version_number),
            ).fetchone()
            if duplicate is not None:
                raise ContentVersionAlreadyExistsError() from error
            raise ContentVersionRepositoryError(
                "CONTENT_VERSION_WRITE_FAILED", "content version could not be created"
            ) from error

        cursor = connection.execute(
            "UPDATE contents SET current_version_id=?,updated_at=?,row_version=row_version+1 "
            "WHERE workspace_id=? AND id=? AND row_version=? AND status<>'ARCHIVED' "
            "AND current_version_id IS ?",
            (
                version.version_id,
                _iso(version.created_at_utc),
                workspace_id,
                version.content_id,
                expected_content_row_version,
                expected_current_version_id,
            ),
        )
        if cursor.rowcount != 1:
            raise ContentVersionConflictError()

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, version_id: str
    ) -> ContentVersion | None:
        row = connection.execute(
            f"{_SELECT} WHERE c.workspace_id=? AND cv.id=?", (workspace_id, version_id)
        ).fetchone()
        return None if row is None else _to_version(row)

    def list_for_content(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> tuple[ContentVersion, ...]:
        rows = connection.execute(
            f"{_SELECT} WHERE c.workspace_id=? AND cv.content_id=? ORDER BY cv.version_number",
            (workspace_id, content_id),
        ).fetchall()
        return tuple(_to_version(row) for row in rows)
