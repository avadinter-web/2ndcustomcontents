from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import StrEnum


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_optional_trimmed(value: str | None, name: str) -> None:
    if value is not None:
        _require_trimmed(value, name)


def _require_utc(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


class ProjectStatus(StrEnum):
    ACTIVE = "ACTIVE"
    PAUSED = "PAUSED"
    ARCHIVED = "ARCHIVED"


@dataclass(frozen=True)
class Project:
    project_id: str
    workspace_id: str
    name: str
    description: str | None
    content_type: str | None
    default_language: str
    default_platforms: tuple[str, ...]
    brand_profile_ref: str | None
    status: ProjectStatus
    created_at_utc: datetime
    updated_at_utc: datetime
    archived_at_utc: datetime | None = None
    row_version: int = 1

    def __post_init__(self) -> None:
        _require_trimmed(self.project_id, "project_id")
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.name, "name")
        _require_optional_trimmed(self.description, "description")
        _require_optional_trimmed(self.content_type, "content_type")
        _require_trimmed(self.default_language, "default_language")
        _require_optional_trimmed(self.brand_profile_ref, "brand_profile_ref")
        if not isinstance(self.default_platforms, tuple) or any(
            not isinstance(item, str) or not item or item != item.strip()
            for item in self.default_platforms
        ):
            raise ValueError("default_platforms must be a JSON array of non-empty strings")
        if len(set(self.default_platforms)) != len(self.default_platforms):
            raise ValueError("default_platforms cannot contain duplicates")
        json.dumps(self.default_platforms, ensure_ascii=False)
        if not isinstance(self.status, ProjectStatus):
            raise TypeError("status must be a ProjectStatus")
        _require_utc(self.created_at_utc, "created_at_utc")
        _require_utc(self.updated_at_utc, "updated_at_utc")
        if self.updated_at_utc < self.created_at_utc:
            raise ValueError("updated_at_utc cannot precede created_at_utc")
        if self.archived_at_utc is not None:
            _require_utc(self.archived_at_utc, "archived_at_utc")
            if self.archived_at_utc < self.updated_at_utc:
                raise ValueError("archived_at_utc cannot precede updated_at_utc")
        if (self.status is ProjectStatus.ARCHIVED) != (self.archived_at_utc is not None):
            raise ValueError("ARCHIVED status and archived_at_utc must agree")
        if isinstance(self.row_version, bool) or not isinstance(self.row_version, int):
            raise ValueError("row_version must be a positive integer")
        if self.row_version < 1:
            raise ValueError("row_version must be a positive integer")

    @property
    def is_archived(self) -> bool:
        return self.status is ProjectStatus.ARCHIVED
