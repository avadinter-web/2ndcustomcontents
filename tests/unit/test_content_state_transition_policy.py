import pytest

from custom_content_studio.domain import (
    ContentStateCommand,
    ContentStatus,
    ContentVersionStatus,
    InvalidStateTransitionError,
    require_content_transition,
    require_content_version_transition,
)


def test_only_content_idea_active_archived_edges_are_allowed() -> None:
    allowed = {
        (ContentStatus.IDEA, ContentStateCommand.ACTIVATE_CONTENT): ContentStatus.ACTIVE,
        (ContentStatus.ACTIVE, ContentStateCommand.ARCHIVE_CONTENT): ContentStatus.ARCHIVED,
    }
    for state in ContentStatus:
        for command in ContentStateCommand:
            target = allowed.get((state, command))
            if target is not None:
                assert require_content_transition(state, command) is target
                continue
            with pytest.raises(InvalidStateTransitionError) as caught:
                require_content_transition(state, command)
            assert caught.value.safe_details == {
                "resource_type": "Content",
                "current_state": state.value,
                "command": command.value,
            }


def test_only_draft_submit_review_edge_is_allowed() -> None:
    for state in ContentVersionStatus:
        for command in ContentStateCommand:
            if (
                state is ContentVersionStatus.DRAFT
                and command is ContentStateCommand.SUBMIT_CONTENT_VERSION_FOR_REVIEW
            ):
                assert (
                    require_content_version_transition(state, command)
                    is ContentVersionStatus.REVIEW_REQUIRED
                )
                continue
            with pytest.raises(InvalidStateTransitionError):
                require_content_version_transition(state, command)
