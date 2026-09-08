from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime, timedelta

from ...domain.contents import Content, ContentStatus, ContentType
from ...domain.security import Action, ActorContext, SecurityError, require_action
from ...persistence import SQLiteConnectionFactory, SQLiteUnitOfWork
from ..ports.content_repository import (
    ContentArchivedError,
    ContentConflictError,
    ContentNotFoundError,
    ContentRepositoryPort,
)


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_optional_trimmed(value: str | None, name: str) -> None:
    if value is not None:
        _require_trimmed(value, name)


def _require_utc(value: datetime, name: str) -> None:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


@dataclass(frozen=True)
class CreateContent:
    actor: ActorContext
    content_id: str
    workspace_id: str
    project_id: str
    title: str
    content_type: ContentType
    primary_platform: str | None
    goal: str | None
    created_at_utc: datetime

    def __post_init__(self) -> None:
        if not isinstance(self.actor, ActorContext):
            raise TypeError("actor must be an ActorContext")
        _require_trimmed(self.content_id, "content_id")
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.project_id, "project_id")
        _require_trimmed(self.title, "title")
        if not isinstance(self.content_type, ContentType):
            raise TypeError("content_type must be a ContentType")
        _require_optional_trimmed(self.primary_platform, "primary_platform")
        _require_optional_trimmed(self.goal, "goal")
        _require_utc(self.created_at_utc, "created_at_utc")


@dataclass(frozen=True)
class UpdateContent:
    actor: ActorContext
    workspace_id: str
    content_id: str
    expected_row_version: int
    title: str
    content_type: ContentType
    primary_platform: str | None
    goal: str | None
    updated_at_utc: datetime

    def __post_init__(self) -> None:
        if not isinstance(self.actor, ActorContext):
            raise TypeError("actor must be an ActorContext")
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.content_id, "content_id")
        if isinstance(self.expected_row_version, bool) or self.expected_row_version < 1:
            raise ValueError("expected_row_version must be positive")
        _require_trimmed(self.title, "title")
        if not isinstance(self.content_type, ContentType):
            raise TypeError("content_type must be a ContentType")
        _require_optional_trimmed(self.primary_platform, "primary_platform")
        _require_optional_trimmed(self.goal, "goal")
        _require_utc(self.updated_at_utc, "updated_at_utc")


class ContentService:
    def __init__(self, factory: SQLiteConnectionFactory, contents: ContentRepositoryPort) -> None:
        self._factory = factory
        self._contents = contents

    def create(self, command: CreateContent) -> Content:
        require_action(command.actor, command.workspace_id, Action.CONTENT_EDIT)
        content = Content(
            content_id=command.content_id,
            workspace_id=command.workspace_id,
            project_id=command.project_id,
            title=command.title,
            content_type=command.content_type,
            primary_platform=command.primary_platform,
            goal=command.goal,
            status=ContentStatus.IDEA,
            current_version_id=None,
            created_at_utc=command.created_at_utc,
            updated_at_utc=command.created_at_utc,
        )
        with SQLiteUnitOfWork(self._factory) as uow:
            try:
                self._contents.create(uow.connection, content)
            except ContentNotFoundError as error:
                raise self._access_denied() from error
            uow.commit()
        return content

    def update(self, command: UpdateContent) -> Content:
        require_action(command.actor, command.workspace_id, Action.CONTENT_EDIT)
        with SQLiteUnitOfWork(self._factory) as uow:
            current = self._contents.get_by_id(
                uow.connection, command.workspace_id, command.content_id
            )
            if current is None:
                raise self._access_denied()
            if current.row_version != command.expected_row_version:
                raise SecurityError("VERSION_CONFLICT", "content state changed")
            if current.is_archived:
                raise SecurityError("DOMAIN_VALIDATION_FAILED", "content is archived")
            if command.updated_at_utc <= current.updated_at_utc:
                raise SecurityError(
                    "DOMAIN_VALIDATION_FAILED", "content update time must advance state"
                )
            candidate = replace(
                current,
                title=command.title,
                content_type=command.content_type,
                primary_platform=command.primary_platform,
                goal=command.goal,
                updated_at_utc=command.updated_at_utc,
            )
            try:
                updated = self._contents.update(uow.connection, candidate)
            except ContentNotFoundError as error:
                raise self._access_denied() from error
            except ContentConflictError as error:
                raise SecurityError("VERSION_CONFLICT", "content state changed") from error
            except ContentArchivedError as error:
                raise SecurityError("DOMAIN_VALIDATION_FAILED", "content is archived") from error
            uow.commit()
            return updated

    @staticmethod
    def _access_denied() -> SecurityError:
        return SecurityError("WORKSPACE_ACCESS_DENIED", "workspace action is not permitted")
