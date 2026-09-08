from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime

from ....application.ports.asset_repository import (
    AssetAlreadyExistsError,
    AssetArchivedError,
    AssetConflictError,
    AssetNotFoundError,
    AssetRepositoryError,
)
from ....domain.assets import Asset, AssetStatus, AssetType, StorageProvider
from ....domain.workspaces import JsonValue


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise AssetRepositoryError("ASSET_DATA_INVALID", "asset timestamp is invalid")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise AssetRepositoryError("ASSET_DATA_INVALID", "asset timestamp is invalid") from error
    if parsed.tzinfo is None:
        raise AssetRepositoryError("ASSET_DATA_INVALID", "asset timestamp is invalid")
    return parsed.astimezone(UTC)


def _metadata(value: object) -> dict[str, JsonValue]:
    if not isinstance(value, str):
        raise AssetRepositoryError("ASSET_DATA_INVALID", "asset metadata is invalid")
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as error:
        raise AssetRepositoryError("ASSET_DATA_INVALID", "asset metadata is invalid") from error
    if not isinstance(parsed, dict):
        raise AssetRepositoryError("ASSET_DATA_INVALID", "asset metadata is invalid")
    return parsed


def _metadata_json(asset: Asset) -> str:
    return json.dumps(
        dict(asset.metadata),
        allow_nan=False,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def _to_asset(row: sqlite3.Row) -> Asset:
    return Asset(
        asset_id=str(row["id"]),
        workspace_id=str(row["workspace_id"]),
        project_id=None if row["project_id"] is None else str(row["project_id"]),
        asset_type=AssetType(str(row["asset_type"])),
        storage_provider=StorageProvider(str(row["storage_provider"])),
        storage_key=str(row["storage_key"]),
        original_filename=str(row["original_filename"]),
        mime_type=str(row["mime_type"]),
        size_bytes=None if row["size_bytes"] is None else int(row["size_bytes"]),
        checksum_sha256=(None if row["checksum_sha256"] is None else str(row["checksum_sha256"])),
        metadata=_metadata(row["metadata_json"]),
        status=AssetStatus(str(row["status"])),
        created_at_utc=_datetime(row["created_at"]),
        updated_at_utc=_datetime(row["updated_at"]),
        row_version=int(row["row_version"]),
    )


_SELECT = (
    "SELECT id,workspace_id,project_id,asset_type,storage_provider,storage_key,"
    "original_filename,mime_type,size_bytes,checksum_sha256,metadata_json,status,"
    "created_at,updated_at,row_version FROM assets"
)


class SQLiteAssetRepository:
    def create(self, connection: sqlite3.Connection, asset: Asset) -> None:
        if asset.row_version != 1 or asset.is_archived:
            raise ValueError("new asset must be non-archived at row_version 1")
        self._require_project(connection, asset.workspace_id, asset.project_id)
        try:
            connection.execute(
                "INSERT INTO assets(id,workspace_id,project_id,asset_type,storage_provider,"
                "storage_key,original_filename,mime_type,size_bytes,checksum_sha256,metadata_json,"
                "status,created_at,updated_at,row_version) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1)",
                (
                    asset.asset_id,
                    asset.workspace_id,
                    asset.project_id,
                    asset.asset_type.value,
                    asset.storage_provider.value,
                    asset.storage_key,
                    asset.original_filename,
                    asset.mime_type,
                    asset.size_bytes,
                    asset.checksum_sha256,
                    _metadata_json(asset),
                    asset.status.value,
                    _iso(asset.created_at_utc),
                    _iso(asset.updated_at_utc),
                ),
            )
        except sqlite3.IntegrityError as error:
            duplicate = connection.execute(
                "SELECT 1 FROM assets WHERE id=? OR "
                "(workspace_id=? AND storage_provider=? AND storage_key=?)",
                (
                    asset.asset_id,
                    asset.workspace_id,
                    asset.storage_provider.value,
                    asset.storage_key,
                ),
            ).fetchone()
            if duplicate is not None:
                raise AssetAlreadyExistsError() from error
            raise AssetRepositoryError(
                "ASSET_WRITE_FAILED", "asset could not be registered"
            ) from error

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, asset_id: str
    ) -> Asset | None:
        row = connection.execute(
            f"{_SELECT} WHERE workspace_id=? AND id=?", (workspace_id, asset_id)
        ).fetchone()
        return None if row is None else _to_asset(row)

    def list_active(self, connection: sqlite3.Connection, workspace_id: str) -> tuple[Asset, ...]:
        rows = connection.execute(
            f"{_SELECT} WHERE workspace_id=? AND status<>'ARCHIVED' ORDER BY created_at,id",
            (workspace_id,),
        ).fetchall()
        return tuple(_to_asset(row) for row in rows)

    def update(self, connection: sqlite3.Connection, asset: Asset) -> Asset:
        self._require_project(connection, asset.workspace_id, asset.project_id)
        cursor = connection.execute(
            "UPDATE assets SET project_id=?,metadata_json=?,status=?,updated_at=?,"
            "row_version=row_version+1 WHERE workspace_id=? AND id=? AND row_version=? "
            "AND status<>'ARCHIVED'",
            (
                asset.project_id,
                _metadata_json(asset),
                asset.status.value,
                _iso(asset.updated_at_utc),
                asset.workspace_id,
                asset.asset_id,
                asset.row_version,
            ),
        )
        if cursor.rowcount != 1:
            self._raise_write_failure(
                connection, asset.workspace_id, asset.asset_id, asset.row_version
            )
        updated = self.get_by_id(connection, asset.workspace_id, asset.asset_id)
        if updated is None:
            raise AssetNotFoundError()
        return updated

    @staticmethod
    def _require_project(
        connection: sqlite3.Connection, workspace_id: str, project_id: str | None
    ) -> None:
        if project_id is None:
            return
        project = connection.execute(
            "SELECT 1 FROM projects WHERE workspace_id=? AND id=? AND status<>'ARCHIVED'",
            (workspace_id, project_id),
        ).fetchone()
        if project is None:
            raise AssetNotFoundError()

    @staticmethod
    def _raise_write_failure(
        connection: sqlite3.Connection,
        workspace_id: str,
        asset_id: str,
        expected_row_version: int,
    ) -> None:
        row = connection.execute(
            "SELECT status,row_version FROM assets WHERE workspace_id=? AND id=?",
            (workspace_id, asset_id),
        ).fetchone()
        if row is None:
            raise AssetNotFoundError()
        if row["status"] == "ARCHIVED":
            raise AssetArchivedError()
        if int(row["row_version"]) != expected_row_version:
            raise AssetConflictError()
        raise AssetConflictError()
