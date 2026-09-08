from dataclasses import FrozenInstanceError
from datetime import UTC, datetime, timedelta, timezone
from typing import Any, cast

import pytest

from custom_content_studio.domain import Workspace

NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _workspace(**overrides: object) -> Workspace:
    values: dict[str, Any] = {
        "workspace_id": "workspace-1",
        "name": "Studio",
        "timezone": "UTC",
        "settings": {"language": "ko", "limits": {"daily": 3}},
        "created_at_utc": NOW,
        "updated_at_utc": NOW,
    }
    values.update(overrides)
    return Workspace(**values)


def test_workspace_is_frozen_and_copies_json_settings() -> None:
    settings = {"nested": {"enabled": True}}
    workspace = _workspace(settings=settings)
    settings["nested"] = {"enabled": False}

    assert workspace.settings == {"nested": {"enabled": True}}
    with pytest.raises(FrozenInstanceError):
        workspace.workspace_id = "replacement"  # type: ignore[misc]


@pytest.mark.parametrize("name", ["", " Studio "])
def test_workspace_rejects_invalid_name(name: str) -> None:
    with pytest.raises(ValueError, match="name must be"):
        _workspace(name=name)


def test_workspace_rejects_unknown_timezone() -> None:
    with pytest.raises(ValueError, match="IANA timezone"):
        _workspace(timezone="Mars/Olympus")


@pytest.mark.parametrize("settings", [[], {"bad": float("nan")}, {"bad": object()}])
def test_workspace_rejects_non_json_object_settings(settings: object) -> None:
    with pytest.raises((TypeError, ValueError), match="JSON object"):
        _workspace(settings=cast(Any, settings))


@pytest.mark.parametrize(
    "field,value",
    [
        ("created_at_utc", datetime(2026, 9, 8)),
        ("updated_at_utc", datetime(2026, 9, 8, tzinfo=timezone(timedelta(hours=9)))),
    ],
)
def test_workspace_requires_utc_timestamps(field: str, value: datetime) -> None:
    with pytest.raises(ValueError, match="timezone-aware UTC"):
        _workspace(**{field: value})


@pytest.mark.parametrize("row_version", [0, -1, True])
def test_workspace_rejects_invalid_row_version(row_version: object) -> None:
    with pytest.raises(ValueError, match="positive integer"):
        _workspace(row_version=row_version)
