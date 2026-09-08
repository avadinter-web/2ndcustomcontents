from dataclasses import FrozenInstanceError
from datetime import UTC, datetime, timedelta, timezone
from typing import Any

import pytest

from custom_content_studio.domain import Project, ProjectStatus

NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _project(**overrides: object) -> Project:
    values: dict[str, Any] = {
        "project_id": "project-1",
        "workspace_id": "workspace-1",
        "name": "Launch",
        "description": None,
        "content_type": None,
        "default_language": "ko",
        "default_platforms": ("YOUTUBE", "TIKTOK"),
        "brand_profile_ref": None,
        "status": ProjectStatus.ACTIVE,
        "created_at_utc": NOW,
        "updated_at_utc": NOW,
    }
    values.update(overrides)
    return Project(**values)


def test_project_is_frozen_with_closed_status_and_platform_tuple() -> None:
    project = _project()
    assert project.status is ProjectStatus.ACTIVE
    assert project.default_platforms == ("YOUTUBE", "TIKTOK")
    with pytest.raises(FrozenInstanceError):
        project.project_id = "replacement"  # type: ignore[misc]


@pytest.mark.parametrize("field", ["project_id", "workspace_id", "name", "default_language"])
def test_project_requires_trimmed_nonempty_core_fields(field: str) -> None:
    with pytest.raises(ValueError, match="non-empty trimmed"):
        _project(**{field: " value "})


@pytest.mark.parametrize("field", ["description", "content_type", "brand_profile_ref"])
def test_project_optional_text_uses_none_instead_of_blank(field: str) -> None:
    with pytest.raises(ValueError, match="non-empty trimmed"):
        _project(**{field: ""})


@pytest.mark.parametrize(
    "platforms",
    [(["YOUTUBE"],), (("YOUTUBE", "YOUTUBE"),), ((" YOUTUBE ",),)],
)
def test_project_rejects_invalid_default_platform_array(platforms: tuple[object, ...]) -> None:
    with pytest.raises(ValueError, match="default_platforms"):
        _project(default_platforms=platforms[0])


def test_project_requires_utc_and_consistent_archive_state() -> None:
    with pytest.raises(ValueError, match="timezone-aware UTC"):
        _project(updated_at_utc=datetime(2026, 9, 8, tzinfo=timezone(timedelta(hours=9))))
    with pytest.raises(ValueError, match="archive"):
        _project(status=ProjectStatus.ARCHIVED)


@pytest.mark.parametrize("row_version", [0, -1, True])
def test_project_rejects_invalid_row_version(row_version: object) -> None:
    with pytest.raises(ValueError, match="positive integer"):
        _project(row_version=row_version)
