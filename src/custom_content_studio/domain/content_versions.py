from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
from enum import StrEnum
from types import MappingProxyType

type JsonValue = None | bool | int | float | str | tuple[JsonValue, ...] | Mapping[str, JsonValue]

SNAPSHOT_SCHEMA = "ccs.content-version-snapshot"
SNAPSHOT_VERSION = 1


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_non_empty(value: str, name: str) -> None:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{name} must be a non-empty string")


def _require_utc(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


def _freeze_json(value: object) -> JsonValue:
    if value is None or isinstance(value, (bool, str)):
        return value
    if isinstance(value, int) and not isinstance(value, bool):
        if abs(value) > 9_007_199_254_740_991:
            raise ValueError("snapshot integers must be exactly representable as JSON numbers")
        return value
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("snapshot numbers must be finite")
        return value
    if isinstance(value, Mapping):
        frozen: dict[str, JsonValue] = {}
        for key, item in value.items():
            if not isinstance(key, str):
                raise ValueError("snapshot object keys must be strings")
            frozen[key] = _freeze_json(item)
        return MappingProxyType(frozen)
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return tuple(_freeze_json(item) for item in value)
    raise ValueError("snapshot values must be JSON-compatible")


def _jcs_number(value: int | float) -> str:
    if isinstance(value, int):
        return str(value)
    if value == 0:
        return "0"
    decimal = Decimal(repr(value))
    absolute = abs(decimal)
    if Decimal("1e-6") <= absolute < Decimal("1e21"):
        rendered = format(decimal, "f")
        return rendered.rstrip("0").rstrip(".") if "." in rendered else rendered
    sign = "-" if decimal < 0 else ""
    digits = "".join(str(digit) for digit in decimal.copy_abs().as_tuple().digits).rstrip("0")
    exponent = decimal.copy_abs().adjusted()
    coefficient = digits[0]
    if len(digits) > 1:
        coefficient += "." + digits[1:]
    exponent_text = f"+{exponent}" if exponent >= 0 else str(exponent)
    return f"{sign}{coefficient}e{exponent_text}"


def _jcs(value: JsonValue) -> str:
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return _jcs_number(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if isinstance(value, tuple):
        return "[" + ",".join(_jcs(item) for item in value) + "]"
    items = sorted(value.items(), key=lambda item: item[0].encode("utf-16-be", "surrogatepass"))
    return "{" + ",".join(f"{_jcs(key)}:{_jcs(item)}" for key, item in items) + "}"


@dataclass(frozen=True)
class ContentVersionSnapshot:
    title: str
    script: Mapping[str, JsonValue] | None
    content: Mapping[str, JsonValue]

    def __post_init__(self) -> None:
        _require_non_empty(self.title, "snapshot title")
        if self.script is not None and not isinstance(self.script, Mapping):
            raise TypeError("snapshot script must be an object or None")
        if not isinstance(self.content, Mapping):
            raise TypeError("snapshot content must be an object")
        if self.script is not None:
            object.__setattr__(self, "script", _freeze_json(self.script))
        object.__setattr__(self, "content", _freeze_json(self.content))

    def envelope(self) -> Mapping[str, JsonValue]:
        return MappingProxyType(
            {
                "_schema": SNAPSHOT_SCHEMA,
                "_version": SNAPSHOT_VERSION,
                "data": MappingProxyType(
                    {"title": self.title, "script": self.script, "content": self.content}
                ),
            }
        )

    def canonical_json(self) -> str:
        return _jcs(self.envelope())

    def canonical_script_json(self) -> str | None:
        return None if self.script is None else _jcs(self.script)


def compute_snapshot_hash(
    content_id: str, version_number: int, snapshot: ContentVersionSnapshot
) -> str:
    _require_trimmed(content_id, "content_id")
    if (
        isinstance(version_number, bool)
        or not isinstance(version_number, int)
        or version_number < 1
    ):
        raise ValueError("version_number must be a positive integer")
    identity: Mapping[str, JsonValue] = {
        "content_id": content_id,
        "snapshot": snapshot.envelope(),
        "version_number": version_number,
    }
    return hashlib.sha256(_jcs(identity).encode("utf-8")).hexdigest()


class ContentVersionStatus(StrEnum):
    DRAFT = "DRAFT"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    REVISION_REQUIRED = "REVISION_REQUIRED"
    APPROVED = "APPROVED"
    SUPERSEDED = "SUPERSEDED"


@dataclass(frozen=True)
class ContentVersion:
    version_id: str
    content_id: str
    version_number: int
    parent_version_id: str | None
    status: ContentVersionStatus
    snapshot: ContentVersionSnapshot
    snapshot_hash: str
    created_by: str
    created_at_utc: datetime
    row_version: int = 1

    def __post_init__(self) -> None:
        _require_trimmed(self.version_id, "version_id")
        _require_trimmed(self.content_id, "content_id")
        if isinstance(self.version_number, bool) or self.version_number < 1:
            raise ValueError("version_number must be a positive integer")
        if self.parent_version_id is not None:
            _require_trimmed(self.parent_version_id, "parent_version_id")
            if self.parent_version_id == self.version_id:
                raise ValueError("parent_version_id cannot equal version_id")
        if self.version_number == 1 and self.parent_version_id is not None:
            raise ValueError("the first version cannot have a parent")
        if self.version_number > 1 and self.parent_version_id is None:
            raise ValueError("a successor version requires a parent")
        if not isinstance(self.status, ContentVersionStatus):
            raise TypeError("status must be a ContentVersionStatus")
        if not isinstance(self.snapshot, ContentVersionSnapshot):
            raise TypeError("snapshot must be a ContentVersionSnapshot")
        expected_hash = compute_snapshot_hash(self.content_id, self.version_number, self.snapshot)
        if self.snapshot_hash != expected_hash:
            raise ValueError("snapshot_hash does not match canonical snapshot identity")
        _require_trimmed(self.created_by, "created_by")
        _require_utc(self.created_at_utc, "created_at_utc")
        if isinstance(self.row_version, bool) or self.row_version < 1:
            raise ValueError("row_version must be a positive integer")
