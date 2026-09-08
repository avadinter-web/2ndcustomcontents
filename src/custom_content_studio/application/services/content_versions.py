from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from ...domain.content_versions import (
    ContentVersion,
    ContentVersionSnapshot,
    ContentVersionStatus,
    compute_snapshot_hash,
)
from ...domain.security import Action, ActorContext, ActorType, SecurityError, require_action
from ...persistence import SQLiteConnectionFactory, SQLiteUnitOfWork
from ..ports.content_repository import ContentRepositoryPort
from ..ports.content_version_repository import (
    ContentVersionConflictError,
    ContentVersionNotFoundError,
    ContentVersionRepositoryPort,
)


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_optional_trimmed(value: str | None, name: str) -> None:
    if value is not None:
        _require_trimmed(value, name)


def _require_utc(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


@dataclass(frozen=True)
class CreateContentVersion:
    actor: ActorContext
    workspace_id: str
    content_id: str
    version_id: str
    expected_content_row_version: int
    expected_current_version_id: str | None
    parent_version_id: str | None
    snapshot: ContentVersionSnapshot
    created_at_utc: datetime

    def __post_init__(self) -> None:
        if not isinstance(self.actor, ActorContext):
            raise TypeError("actor must be an ActorContext")
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.content_id, "content_id")
        _require_trimmed(self.version_id, "version_id")
        if (
            isinstance(self.expected_content_row_version, bool)
            or not isinstance(self.expected_content_row_version, int)
            or self.expected_content_row_version < 1
        ):
            raise ValueError("expected_content_row_version must be a positive integer")
        _require_optional_trimmed(self.expected_current_version_id, "expected_current_version_id")
        _require_optional_trimmed(self.parent_version_id, "parent_version_id")
        if not isinstance(self.snapshot, ContentVersionSnapshot):
            raise TypeError("snapshot must be a ContentVersionSnapshot")
        _require_utc(self.created_at_utc, "created_at_utc")


class ContentVersionService:
    def __init__(
        self,
        factory: SQLiteConnectionFactory,
        contents: ContentRepositoryPort,
        versions: ContentVersionRepositoryPort,
    ) -> None:
        self._factory = factory
        self._contents = contents
        self._versions = versions

    def create(self, command: CreateContentVersion) -> ContentVersion:
        if command.actor.actor_type is not ActorType.USER:
            raise self._access_denied()
        require_action(command.actor, command.workspace_id, Action.CONTENT_EDIT)
        if command.parent_version_id != command.expected_current_version_id:
            raise SecurityError("VERSION_CONFLICT", "content authoring head changed")

        with SQLiteUnitOfWork(self._factory) as uow:
            content = self._contents.get_by_id(
                uow.connection, command.workspace_id, command.content_id
            )
            if content is None:
                raise self._access_denied()
            if content.is_archived:
                raise SecurityError("DOMAIN_VALIDATION_FAILED", "content is archived")
            if (
                content.row_version != command.expected_content_row_version
                or content.current_version_id != command.expected_current_version_id
            ):
                raise SecurityError("VERSION_CONFLICT", "content authoring head changed")
            if command.created_at_utc < content.updated_at_utc:
                raise SecurityError(
                    "DOMAIN_VALIDATION_FAILED", "version creation time cannot precede content"
                )
            try:
                version_number = self._versions.next_version_number(
                    uow.connection, command.workspace_id, command.content_id
                )
            except ContentVersionNotFoundError as error:
                raise self._access_denied() from error
            if (version_number == 1) != (command.parent_version_id is None):
                raise SecurityError("VERSION_CONFLICT", "content authoring head changed")
            version = ContentVersion(
                version_id=command.version_id,
                content_id=command.content_id,
                version_number=version_number,
                parent_version_id=command.parent_version_id,
                status=ContentVersionStatus.DRAFT,
                snapshot=command.snapshot,
                snapshot_hash=compute_snapshot_hash(
                    command.content_id, version_number, command.snapshot
                ),
                created_by=command.actor.actor_id,
                created_at_utc=command.created_at_utc,
            )
            try:
                self._versions.create_and_advance_head(
                    uow.connection,
                    command.workspace_id,
                    command.expected_content_row_version,
                    command.expected_current_version_id,
                    version,
                )
            except ContentVersionConflictError as error:
                raise SecurityError("VERSION_CONFLICT", "content authoring head changed") from error
            uow.commit()
            return version

    @staticmethod
    def _access_denied() -> SecurityError:
        return SecurityError("WORKSPACE_ACCESS_DENIED", "workspace action is not permitted")
