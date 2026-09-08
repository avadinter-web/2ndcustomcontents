from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta

from ...domain.content_state_transitions import (
    ContentStateCommand,
    InvalidStateTransitionError,
    require_content_transition,
    require_content_version_transition,
)
from ...domain.content_versions import ContentVersion, ContentVersionStatus
from ...domain.contents import Content, ContentStatus
from ...domain.security import Action, ActorContext, ActorType, SecurityError, require_action
from ...persistence import SQLiteConnectionFactory, SQLiteUnitOfWork
from ..ports.content_state_transition_repository import (
    ContentStateTransitionConflictError,
    ContentStateTransitionInvalidError,
    ContentStateTransitionNotFoundError,
    ContentStateTransitionRepositoryError,
    ContentStateTransitionRepositoryPort,
)


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_positive(value: int, name: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ValueError(f"{name} must be a positive integer")


def _require_utc(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


@dataclass(frozen=True)
class ActivateContent:
    actor: ActorContext
    workspace_id: str
    content_id: str
    expected_row_version: int
    transitioned_at_utc: datetime

    def __post_init__(self) -> None:
        _validate_command(self.actor, self.workspace_id, self.content_id, self.expected_row_version)
        _require_utc(self.transitioned_at_utc, "transitioned_at_utc")


@dataclass(frozen=True)
class ArchiveContent:
    actor: ActorContext
    workspace_id: str
    content_id: str
    expected_row_version: int
    transitioned_at_utc: datetime

    def __post_init__(self) -> None:
        _validate_command(self.actor, self.workspace_id, self.content_id, self.expected_row_version)
        _require_utc(self.transitioned_at_utc, "transitioned_at_utc")


@dataclass(frozen=True)
class SubmitContentVersionForReview:
    actor: ActorContext
    workspace_id: str
    content_version_id: str
    expected_row_version: int
    transitioned_at_utc: datetime

    def __post_init__(self) -> None:
        _validate_command(
            self.actor, self.workspace_id, self.content_version_id, self.expected_row_version
        )
        _require_utc(self.transitioned_at_utc, "transitioned_at_utc")


def _validate_command(
    actor: ActorContext, workspace_id: str, resource_id: str, expected_row_version: int
) -> None:
    if not isinstance(actor, ActorContext):
        raise TypeError("actor must be an ActorContext")
    _require_trimmed(workspace_id, "workspace_id")
    _require_trimmed(resource_id, "resource_id")
    _require_positive(expected_row_version, "expected_row_version")


class ContentStateTransitionService:
    def __init__(
        self,
        factory: SQLiteConnectionFactory,
        repository: ContentStateTransitionRepositoryPort,
    ) -> None:
        self._factory = factory
        self._repository = repository

    def activate(self, command: ActivateContent) -> Content:
        self._authorize(command.actor, command.workspace_id)
        with SQLiteUnitOfWork(self._factory) as uow:
            current = self._repository.get_content(
                uow.connection, command.workspace_id, command.content_id
            )
            if current is None:
                raise self._access_denied()
            self._require_expected_version(current.row_version, command.expected_row_version)
            target = self._content_target(current.status, ContentStateCommand.ACTIVATE_CONTENT)
            if command.transitioned_at_utc <= current.updated_at_utc:
                raise self._domain_error("transition time must advance content state")
            if current.current_version_id is None:
                raise self._domain_error("content activation requires a DRAFT authoring head")
            head = self._repository.get_content_version(
                uow.connection, command.workspace_id, current.current_version_id
            )
            if (
                head is None
                or head.content_id != current.content_id
                or head.status is not ContentVersionStatus.DRAFT
            ):
                raise self._domain_error("content activation requires a DRAFT authoring head")
            updated = self._transition_content(
                uow.connection,
                command.workspace_id,
                command.content_id,
                command.expected_row_version,
                current.status,
                target,
                command.transitioned_at_utc,
                ContentStateCommand.ACTIVATE_CONTENT,
            )
            uow.commit()
            return updated

    def archive(self, command: ArchiveContent) -> Content:
        self._authorize(command.actor, command.workspace_id)
        with SQLiteUnitOfWork(self._factory) as uow:
            current = self._repository.get_content(
                uow.connection, command.workspace_id, command.content_id
            )
            if current is None:
                raise self._access_denied()
            self._require_expected_version(current.row_version, command.expected_row_version)
            target = self._content_target(current.status, ContentStateCommand.ARCHIVE_CONTENT)
            if command.transitioned_at_utc <= current.updated_at_utc:
                raise self._domain_error("transition time must advance content state")
            updated = self._transition_content(
                uow.connection,
                command.workspace_id,
                command.content_id,
                command.expected_row_version,
                current.status,
                target,
                command.transitioned_at_utc,
                ContentStateCommand.ARCHIVE_CONTENT,
            )
            uow.commit()
            return updated

    def submit_for_review(self, command: SubmitContentVersionForReview) -> ContentVersion:
        self._authorize(command.actor, command.workspace_id)
        with SQLiteUnitOfWork(self._factory) as uow:
            current = self._repository.get_content_version(
                uow.connection, command.workspace_id, command.content_version_id
            )
            if current is None:
                raise self._access_denied()
            self._require_expected_version(current.row_version, command.expected_row_version)
            target = self._version_target(
                current.status, ContentStateCommand.SUBMIT_CONTENT_VERSION_FOR_REVIEW
            )
            if command.transitioned_at_utc <= current.created_at_utc:
                raise self._domain_error("transition time must advance content version state")
            try:
                updated = self._repository.transition_content_version(
                    uow.connection,
                    command.workspace_id,
                    command.content_version_id,
                    command.expected_row_version,
                    current.status,
                    target,
                )
            except ContentStateTransitionNotFoundError as error:
                raise self._access_denied() from error
            except ContentStateTransitionConflictError as error:
                raise SecurityError("VERSION_CONFLICT", "resource state changed") from error
            except ContentStateTransitionInvalidError as error:
                raise self._invalid(
                    current.status,
                    command=ContentStateCommand.SUBMIT_CONTENT_VERSION_FOR_REVIEW,
                    resource_type="ContentVersion",
                ) from error
            uow.commit()
            return updated

    def _transition_content(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        content_id: str,
        expected_row_version: int,
        source: ContentStatus,
        target: ContentStatus,
        transitioned_at_utc: datetime,
        command: ContentStateCommand,
    ) -> Content:
        try:
            return self._repository.transition_content(
                connection,
                workspace_id,
                content_id,
                expected_row_version,
                source,
                target,
                transitioned_at_utc,
            )
        except ContentStateTransitionNotFoundError as error:
            raise self._access_denied() from error
        except ContentStateTransitionConflictError as error:
            raise SecurityError("VERSION_CONFLICT", "resource state changed") from error
        except ContentStateTransitionInvalidError as error:
            raise self._invalid(source, command=command, resource_type="Content") from error
        except ContentStateTransitionRepositoryError as error:
            if error.code == "DOMAIN_VALIDATION_FAILED":
                raise self._domain_error("content transition precondition failed") from error
            raise

    @staticmethod
    def _content_target(current: ContentStatus, command: ContentStateCommand) -> ContentStatus:
        try:
            return require_content_transition(current, command)
        except InvalidStateTransitionError as error:
            raise SecurityError(
                "INVALID_STATE_TRANSITION",
                "requested state transition is not allowed",
                error.safe_details,
            ) from error

    @staticmethod
    def _version_target(
        current: ContentVersionStatus, command: ContentStateCommand
    ) -> ContentVersionStatus:
        try:
            return require_content_version_transition(current, command)
        except InvalidStateTransitionError as error:
            raise SecurityError(
                "INVALID_STATE_TRANSITION",
                "requested state transition is not allowed",
                error.safe_details,
            ) from error

    @staticmethod
    def _invalid(
        current: ContentStatus | ContentVersionStatus,
        *,
        command: ContentStateCommand,
        resource_type: str,
    ) -> SecurityError:
        return SecurityError(
            "INVALID_STATE_TRANSITION",
            "requested state transition is not allowed",
            {
                "resource_type": resource_type,
                "current_state": current.value,
                "command": command.value,
            },
        )

    @staticmethod
    def _authorize(actor: ActorContext, workspace_id: str) -> None:
        if actor.actor_type is not ActorType.USER:
            raise ContentStateTransitionService._access_denied()
        require_action(actor, workspace_id, Action.CONTENT_EDIT)

    @staticmethod
    def _require_expected_version(current: int, expected: int) -> None:
        if current != expected:
            raise SecurityError("VERSION_CONFLICT", "resource state changed")

    @staticmethod
    def _access_denied() -> SecurityError:
        return SecurityError("WORKSPACE_ACCESS_DENIED", "workspace action is not permitted")

    @staticmethod
    def _domain_error(message: str) -> SecurityError:
        return SecurityError("DOMAIN_VALIDATION_FAILED", message)
