from __future__ import annotations

import json
import sqlite3
from collections.abc import Mapping
from datetime import UTC, datetime, timedelta

from ....application.ports.workspace_repository import (
    WorkspaceAlreadyExistsError,
    WorkspaceArchivedError,
    WorkspaceConflictError,
    WorkspaceNotFoundError,
    WorkspaceRepositoryError,
)
from ....domain.workspaces import JsonValue, Workspace


def _iso(value: datetime) -> str:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError("timestamp must be timezone-aware UTC")
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise WorkspaceRepositoryError("WORKSPACE_DATA_INVALID", "workspace timestamp is invalid")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise WorkspaceRepositoryError(
            "WORKSPACE_DATA_INVALID", "workspace timestamp is invalid"
        ) from error
    if parsed.tzinfo is None:
        raise WorkspaceRepositoryError("WORKSPACE_DATA_INVALID", "workspace timestamp is invalid")
    return parsed.astimezone(UTC)


def _settings(value: object) -> dict[str, JsonValue]:
    if not isinstance(value, str):
        raise WorkspaceRepositoryError("WORKSPACE_DATA_INVALID", "workspace settings are invalid")
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as error:
        raise WorkspaceRepositoryError(
            "WORKSPACE_DATA_INVALID", "workspace settings are invalid"
        ) from error
    if not isinstance(parsed, dict):
        raise WorkspaceRepositoryError("WORKSPACE_DATA_INVALID", "workspace settings are invalid")
    return parsed


def _settings_json(settings: Mapping[str, JsonValue]) -> str:
    return json.dumps(
        dict(settings), allow_nan=False, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )


def _to_workspace(row: sqlite3.Row) -> Workspace:
    archived_at = row["archived_at"]
    return Workspace(
        workspace_id=str(row["id"]),
        name=str(row["name"]),
        timezone=str(row["timezone"]),
        settings=_settings(row["settings_json"]),
        created_at_utc=_datetime(row["created_at"]),
        updated_at_utc=_datetime(row["updated_at"]),
        archived_at_utc=None if archived_at is None else _datetime(archived_at),
        row_version=int(row["row_version"]),
    )


_SELECT = (
    "SELECT id,name,timezone,settings_json,created_at,updated_at,archived_at,row_version "
    "FROM workspaces"
)


class SQLiteWorkspaceRepository:
    def create(self, connection: sqlite3.Connection, workspace: Workspace) -> None:
        if workspace.row_version != 1 or workspace.is_archived:
            raise ValueError("new workspace must be active at row_version 1")
        try:
            connection.execute(
                "INSERT INTO workspaces(id,name,timezone,settings_json,created_at,updated_at,"
                "archived_at,row_version) VALUES (?,?,?,?,?,?,NULL,1)",
                (
                    workspace.workspace_id,
                    workspace.name,
                    workspace.timezone,
                    _settings_json(workspace.settings),
                    _iso(workspace.created_at_utc),
                    _iso(workspace.updated_at_utc),
                ),
            )
        except sqlite3.IntegrityError as error:
            existing = connection.execute(
                "SELECT 1 FROM workspaces WHERE id=?", (workspace.workspace_id,)
            ).fetchone()
            if existing is not None:
                raise WorkspaceAlreadyExistsError() from error
            raise WorkspaceRepositoryError(
                "WORKSPACE_WRITE_FAILED", "workspace could not be created"
            ) from error

    def get_by_id(self, connection: sqlite3.Connection, workspace_id: str) -> Workspace | None:
        row = connection.execute(f"{_SELECT} WHERE id=?", (workspace_id,)).fetchone()
        return None if row is None else _to_workspace(row)

    def list_active(self, connection: sqlite3.Connection) -> tuple[Workspace, ...]:
        rows = connection.execute(
            f"{_SELECT} WHERE archived_at IS NULL ORDER BY created_at,id"
        ).fetchall()
        return tuple(_to_workspace(row) for row in rows)

    def update(self, connection: sqlite3.Connection, workspace: Workspace) -> Workspace:
        if workspace.is_archived:
            raise WorkspaceArchivedError()
        cursor = connection.execute(
            "UPDATE workspaces SET name=?,timezone=?,settings_json=?,updated_at=?,"
            "row_version=row_version+1 WHERE id=? AND row_version=? AND archived_at IS NULL",
            (
                workspace.name,
                workspace.timezone,
                _settings_json(workspace.settings),
                _iso(workspace.updated_at_utc),
                workspace.workspace_id,
                workspace.row_version,
            ),
        )
        if cursor.rowcount != 1:
            self._raise_write_failure(connection, workspace.workspace_id, workspace.row_version)
        updated = self.get_by_id(connection, workspace.workspace_id)
        if updated is None:
            raise WorkspaceNotFoundError()
        return updated

    def archive(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        expected_row_version: int,
        archived_at_utc: datetime,
    ) -> Workspace:
        archived_at = _iso(archived_at_utc)
        cursor = connection.execute(
            "UPDATE workspaces SET archived_at=?,updated_at=?,row_version=row_version+1 "
            "WHERE id=? AND row_version=? AND archived_at IS NULL",
            (archived_at, archived_at, workspace_id, expected_row_version),
        )
        if cursor.rowcount != 1:
            self._raise_write_failure(connection, workspace_id, expected_row_version)
        archived = self.get_by_id(connection, workspace_id)
        if archived is None:
            raise WorkspaceNotFoundError()
        return archived

    @staticmethod
    def _raise_write_failure(
        connection: sqlite3.Connection, workspace_id: str, expected_row_version: int
    ) -> None:
        row = connection.execute(
            "SELECT archived_at,row_version FROM workspaces WHERE id=?", (workspace_id,)
        ).fetchone()
        if row is None:
            raise WorkspaceNotFoundError()
        if row["archived_at"] is not None:
            raise WorkspaceArchivedError()
        if int(row["row_version"]) != expected_row_version:
            raise WorkspaceConflictError()
        raise WorkspaceConflictError()
