from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

from .content_versions import ContentVersionStatus
from .contents import ContentStatus


class ContentStateCommand(StrEnum):
    ACTIVATE_CONTENT = "ActivateContent"
    ARCHIVE_CONTENT = "ArchiveContent"
    SUBMIT_CONTENT_VERSION_FOR_REVIEW = "SubmitContentVersionForReview"


@dataclass(frozen=True)
class InvalidStateTransitionError(ValueError):
    resource_type: str
    current_state: str
    command: ContentStateCommand

    def __str__(self) -> str:
        return "INVALID_STATE_TRANSITION: requested state transition is not allowed"

    @property
    def safe_details(self) -> dict[str, str]:
        return {
            "resource_type": self.resource_type,
            "current_state": self.current_state,
            "command": self.command.value,
        }


def require_content_transition(
    current: ContentStatus, command: ContentStateCommand
) -> ContentStatus:
    transitions = {
        (ContentStatus.IDEA, ContentStateCommand.ACTIVATE_CONTENT): ContentStatus.ACTIVE,
        (ContentStatus.ACTIVE, ContentStateCommand.ARCHIVE_CONTENT): ContentStatus.ARCHIVED,
    }
    target = transitions.get((current, command))
    if target is None:
        raise InvalidStateTransitionError("Content", current.value, command)
    return target


def require_content_version_transition(
    current: ContentVersionStatus, command: ContentStateCommand
) -> ContentVersionStatus:
    if (
        current is ContentVersionStatus.DRAFT
        and command is ContentStateCommand.SUBMIT_CONTENT_VERSION_FOR_REVIEW
    ):
        return ContentVersionStatus.REVIEW_REQUIRED
    raise InvalidStateTransitionError("ContentVersion", current.value, command)
