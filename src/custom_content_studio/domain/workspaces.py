from __future__ import annotations

import json
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta
from types import MappingProxyType
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

type JsonValue = None | bool | int | float | str | list[JsonValue] | dict[str, JsonValue]


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_utc(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


def _validated_settings(value: Mapping[str, JsonValue]) -> Mapping[str, JsonValue]:
    if not isinstance(value, Mapping):
        raise TypeError("settings must be a JSON object")
    try:
        encoded = json.dumps(dict(value), allow_nan=False, ensure_ascii=False, sort_keys=True)
        decoded = json.loads(encoded)
    except (TypeError, ValueError) as error:
        raise ValueError("settings must be a JSON object") from error
    if not isinstance(decoded, dict):
        raise ValueError("settings must be a JSON object")
    return MappingProxyType(decoded)


@dataclass(frozen=True)
class Workspace:
    workspace_id: str
    name: str
    timezone: str
    settings: Mapping[str, JsonValue]
    created_at_utc: datetime
    updated_at_utc: datetime
    archived_at_utc: datetime | None = None
    row_version: int = 1

    def __post_init__(self) -> None:
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.name, "name")
        _require_trimmed(self.timezone, "timezone")
        try:
            ZoneInfo(self.timezone)
        except ZoneInfoNotFoundError as error:
            raise ValueError("timezone must be a valid IANA timezone") from error
        object.__setattr__(self, "settings", _validated_settings(self.settings))
        _require_utc(self.created_at_utc, "created_at_utc")
        _require_utc(self.updated_at_utc, "updated_at_utc")
        if self.updated_at_utc < self.created_at_utc:
            raise ValueError("updated_at_utc cannot precede created_at_utc")
        if self.archived_at_utc is not None:
            _require_utc(self.archived_at_utc, "archived_at_utc")
            if self.archived_at_utc < self.updated_at_utc:
                raise ValueError("archived_at_utc cannot precede updated_at_utc")
        if isinstance(self.row_version, bool) or self.row_version < 1:
            raise ValueError("row_version must be a positive integer")

    @property
    def is_archived(self) -> bool:
        return self.archived_at_utc is not None
