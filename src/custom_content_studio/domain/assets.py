from __future__ import annotations

import json
import re
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import StrEnum
from types import MappingProxyType

from .workspaces import JsonValue

_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_utc(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


def _validated_metadata(value: Mapping[str, JsonValue]) -> Mapping[str, JsonValue]:
    if not isinstance(value, Mapping):
        raise TypeError("metadata must be a JSON object")
    try:
        encoded = json.dumps(dict(value), allow_nan=False, ensure_ascii=False, sort_keys=True)
        decoded = json.loads(encoded)
    except (TypeError, ValueError) as error:
        raise ValueError("metadata must be a JSON object") from error
    if not isinstance(decoded, dict):
        raise ValueError("metadata must be a JSON object")
    return MappingProxyType(decoded)


class AssetType(StrEnum):
    SOURCE_VIDEO = "SOURCE_VIDEO"
    SOURCE_AUDIO = "SOURCE_AUDIO"
    IMAGE = "IMAGE"
    LOGO = "LOGO"
    FONT_REFERENCE = "FONT_REFERENCE"
    THUMBNAIL = "THUMBNAIL"
    PREVIEW_VIDEO = "PREVIEW_VIDEO"
    FINAL_VIDEO = "FINAL_VIDEO"
    CAPTION_FILE = "CAPTION_FILE"
    METADATA = "METADATA"
    BENCHMARK_REFERENCE = "BENCHMARK_REFERENCE"
    OTHER = "OTHER"


class StorageProvider(StrEnum):
    LOCAL = "LOCAL"
    GOOGLE_DRIVE = "GOOGLE_DRIVE"
    CLOUDFLARE_R2 = "CLOUDFLARE_R2"
    S3_REFERENCE = "S3_REFERENCE"


class AssetStatus(StrEnum):
    AVAILABLE = "AVAILABLE"
    MISSING = "MISSING"
    PROCESSING = "PROCESSING"
    FAILED = "FAILED"
    ARCHIVED = "ARCHIVED"


@dataclass(frozen=True)
class Asset:
    asset_id: str
    workspace_id: str
    project_id: str | None
    asset_type: AssetType
    storage_provider: StorageProvider
    storage_key: str
    original_filename: str
    mime_type: str
    size_bytes: int | None
    checksum_sha256: str | None
    metadata: Mapping[str, JsonValue]
    status: AssetStatus
    created_at_utc: datetime
    updated_at_utc: datetime
    row_version: int = 1

    def __post_init__(self) -> None:
        _require_trimmed(self.asset_id, "asset_id")
        _require_trimmed(self.workspace_id, "workspace_id")
        if self.project_id is not None:
            _require_trimmed(self.project_id, "project_id")
        if not isinstance(self.asset_type, AssetType):
            raise TypeError("asset_type must be an AssetType")
        if not isinstance(self.storage_provider, StorageProvider):
            raise TypeError("storage_provider must be a StorageProvider")
        _require_trimmed(self.storage_key, "storage_key")
        _require_trimmed(self.original_filename, "original_filename")
        _require_trimmed(self.mime_type, "mime_type")
        if self.size_bytes is not None and (
            isinstance(self.size_bytes, bool) or self.size_bytes < 0
        ):
            raise ValueError("size_bytes must be non-negative or None")
        if self.checksum_sha256 is not None and not _SHA256.fullmatch(self.checksum_sha256):
            raise ValueError("checksum_sha256 must be lowercase 64-hex")
        if self.status is AssetStatus.AVAILABLE and self.checksum_sha256 is None:
            raise ValueError("AVAILABLE assets require checksum_sha256")
        object.__setattr__(self, "metadata", _validated_metadata(self.metadata))
        if not isinstance(self.status, AssetStatus):
            raise TypeError("status must be an AssetStatus")
        _require_utc(self.created_at_utc, "created_at_utc")
        _require_utc(self.updated_at_utc, "updated_at_utc")
        if self.updated_at_utc < self.created_at_utc:
            raise ValueError("updated_at_utc cannot precede created_at_utc")
        if isinstance(self.row_version, bool) or self.row_version < 1:
            raise ValueError("row_version must be a positive integer")

    @property
    def is_archived(self) -> bool:
        return self.status is AssetStatus.ARCHIVED
