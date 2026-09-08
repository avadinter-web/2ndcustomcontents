from __future__ import annotations

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


class ContentType(StrEnum):
    LONG_FORM = "LONG_FORM"
    SHORT = "SHORT"
    REEL = "REEL"
    IMAGE = "IMAGE"
    THUMBNAIL = "THUMBNAIL"
    OTHER = "OTHER"


class ContentStatus(StrEnum):
    IDEA = "IDEA"
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"


@dataclass(frozen=True)
class Content:
    content_id: str
    workspace_id: str
    project_id: str
    title: str
    content_type: ContentType
    primary_platform: str | None
    goal: str | None
    status: ContentStatus
    current_version_id: None
    created_at_utc: datetime
    updated_at_utc: datetime
    archived_at_utc: datetime | None = None
    row_version: int = 1

    def __post_init__(self) -> None:
        _require_trimmed(self.content_id, "content_id")
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.project_id, "project_id")
        _require_trimmed(self.title, "title")
        if not isinstance(self.content_type, ContentType):
            raise TypeError("content_type must be a ContentType")
        _require_optional_trimmed(self.primary_platform, "primary_platform")
        _require_optional_trimmed(self.goal, "goal")
        if not isinstance(self.status, ContentStatus):
            raise TypeError("status must be a ContentStatus")
        if self.current_version_id is not None:
            raise ValueError("current_version_id is not owned by this Content core")
        _require_utc(self.created_at_utc, "created_at_utc")
        _require_utc(self.updated_at_utc, "updated_at_utc")
        if self.updated_at_utc < self.created_at_utc:
            raise ValueError("updated_at_utc cannot precede created_at_utc")
        if self.archived_at_utc is not None:
            _require_utc(self.archived_at_utc, "archived_at_utc")
            if self.archived_at_utc < self.updated_at_utc:
                raise ValueError("archived_at_utc cannot precede updated_at_utc")
        if (self.status is ContentStatus.ARCHIVED) != (self.archived_at_utc is not None):
            raise ValueError("ARCHIVED status and archived_at_utc must agree")
        if isinstance(self.row_version, bool) or not isinstance(self.row_version, int):
            raise ValueError("row_version must be a positive integer")
        if self.row_version < 1:
            raise ValueError("row_version must be a positive integer")

    @property
    def is_archived(self) -> bool:
        return self.status is ContentStatus.ARCHIVED
