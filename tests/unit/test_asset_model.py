from dataclasses import FrozenInstanceError
from datetime import UTC, datetime, timedelta, timezone
from typing import Any

import pytest

from custom_content_studio.domain import Asset, AssetStatus, AssetType, StorageProvider

NOW = datetime(2026, 9, 8, tzinfo=UTC)
CHECKSUM = "a" * 64


def _asset(**overrides: object) -> Asset:
    values: dict[str, Any] = {
        "asset_id": "asset-1",
        "workspace_id": "workspace-1",
        "project_id": None,
        "asset_type": AssetType.SOURCE_VIDEO,
        "storage_provider": StorageProvider.LOCAL,
        "storage_key": "incoming/source.mp4",
        "original_filename": "source.mp4",
        "mime_type": "video/mp4",
        "size_bytes": 42,
        "checksum_sha256": CHECKSUM,
        "metadata": {"width": 1920, "height": 1080},
        "status": AssetStatus.AVAILABLE,
        "created_at_utc": NOW,
        "updated_at_utc": NOW,
    }
    values.update(overrides)
    return Asset(**values)


def test_asset_is_frozen_and_copies_json_metadata() -> None:
    metadata = {"nested": {"value": 1}}
    asset = _asset(metadata=metadata)
    metadata["nested"] = {"value": 2}
    assert asset.metadata == {"nested": {"value": 1}}
    with pytest.raises(FrozenInstanceError):
        asset.asset_id = "replacement"  # type: ignore[misc]


@pytest.mark.parametrize("checksum", [None, "A" * 64, "a" * 63, "not-a-checksum"])
def test_available_asset_requires_lowercase_sha256(checksum: str | None) -> None:
    with pytest.raises(ValueError, match="checksum"):
        _asset(checksum_sha256=checksum)


@pytest.mark.parametrize("size", [-1, True])
def test_asset_rejects_invalid_size(size: object) -> None:
    with pytest.raises(ValueError, match="size_bytes"):
        _asset(size_bytes=size)


@pytest.mark.parametrize("metadata", [[], {"value": float("nan")}, {"value": object()}])
def test_asset_requires_json_object_metadata(metadata: object) -> None:
    with pytest.raises((TypeError, ValueError), match="JSON object"):
        _asset(metadata=metadata)


def test_asset_requires_utc_timestamps_and_positive_version() -> None:
    with pytest.raises(ValueError, match="timezone-aware UTC"):
        _asset(updated_at_utc=datetime(2026, 9, 8, tzinfo=timezone(timedelta(hours=9))))
    with pytest.raises(ValueError, match="positive integer"):
        _asset(row_version=0)
