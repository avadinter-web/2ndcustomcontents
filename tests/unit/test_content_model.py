from dataclasses import FrozenInstanceError
from datetime import UTC, datetime, timedelta, timezone
from typing import Any

import pytest

from custom_content_studio.domain import Content, ContentStatus, ContentType

NOW = datetime(2026, 9, 9, tzinfo=UTC)


def _content(**overrides: object) -> Content:
    values: dict[str, Any] = {
        "content_id": "content-1",
        "workspace_id": "workspace-1",
        "project_id": "project-1",
        "title": "Launch video",
        "content_type": ContentType.SHORT,
        "primary_platform": None,
        "goal": None,
        "status": ContentStatus.IDEA,
        "current_version_id": None,
        "created_at_utc": NOW,
        "updated_at_utc": NOW,
    }
    values.update(overrides)
    return Content(**values)


def test_content_is_frozen_and_status_vocabulary_is_closed() -> None:
    content = _content()
    assert set(ContentStatus) == {
        ContentStatus.IDEA,
        ContentStatus.ACTIVE,
        ContentStatus.ARCHIVED,
    }
    with pytest.raises(FrozenInstanceError):
        content.content_id = "replacement"  # type: ignore[misc]


@pytest.mark.parametrize("field", ["content_id", "workspace_id", "project_id", "title"])
def test_content_requires_trimmed_core_fields(field: str) -> None:
    with pytest.raises(ValueError, match="non-empty trimmed"):
        _content(**{field: " value "})


@pytest.mark.parametrize("field", ["primary_platform", "goal"])
def test_optional_fields_use_none_instead_of_blank(field: str) -> None:
    with pytest.raises(ValueError, match="non-empty trimmed"):
        _content(**{field: ""})


def test_current_version_accepts_a_validated_linked_read_projection() -> None:
    assert _content(current_version_id="version-1").current_version_id == "version-1"
    with pytest.raises(ValueError, match="non-empty trimmed"):
        _content(current_version_id=" version-1 ")


def test_content_requires_utc_archive_consistency_and_positive_version() -> None:
    with pytest.raises(ValueError, match="timezone-aware UTC"):
        _content(updated_at_utc=datetime(2026, 9, 9, tzinfo=timezone(timedelta(hours=9))))
    with pytest.raises(ValueError, match="ARCHIVED"):
        _content(status=ContentStatus.ARCHIVED)
    with pytest.raises(ValueError, match="positive integer"):
        _content(row_version=0)
