from __future__ import annotations

import sqlite3
from datetime import UTC, datetime

from ....application.ports.content_state_transition_repository import (
    ContentStateTransitionConflictError,
    ContentStateTransitionInvalidError,
    ContentStateTransitionNotFoundError,
    ContentStateTransitionRepositoryError,
)
from ....domain.content_versions import ContentVersion, ContentVersionStatus
from ....domain.contents import Content, ContentStatus
from .content_versions import SQLiteContentVersionRepository
from .contents import SQLiteContentRepository


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


class SQLiteContentStateTransitionRepository:
    def __init__(self) -> None:
        self._contents = SQLiteContentRepository()
        self._versions = SQLiteContentVersionRepository()

    def get_content(
        self, connection: sqlite3.Connection, workspace_id: str, content_id: str
    ) -> Content | None:
        return self._contents.get_by_id(connection, workspace_id, content_id)

    def get_content_version(
        self, connection: sqlite3.Connection, workspace_id: str, version_id: str
    ) -> ContentVersion | None:
        return self._versions.get_by_id(connection, workspace_id, version_id)

    def transition_content(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        content_id: str,
        expected_row_version: int,
        source: ContentStatus,
        target: ContentStatus,
        transitioned_at_utc: datetime,
    ) -> Content:
        if (source, target) not in {
            (ContentStatus.IDEA, ContentStatus.ACTIVE),
            (ContentStatus.ACTIVE, ContentStatus.ARCHIVED),
        }:
            raise ContentStateTransitionInvalidError()
        archived_at = _iso(transitioned_at_utc) if target is ContentStatus.ARCHIVED else None
        draft_head_predicate = (
            " AND current_version_id IS NOT NULL AND EXISTS(SELECT 1 FROM content_versions cv "
            "WHERE cv.id=contents.current_version_id AND cv.content_id=contents.id "
            "AND cv.status='DRAFT')"
            if target is ContentStatus.ACTIVE
            else ""
        )
        cursor = connection.execute(
            "UPDATE contents SET status=?,updated_at=?,archived_at=?,row_version=row_version+1 "
            "WHERE workspace_id=? AND id=? AND row_version=? AND status=?" + draft_head_predicate,
            (
                target.value,
                _iso(transitioned_at_utc),
                archived_at,
                workspace_id,
                content_id,
                expected_row_version,
                source.value,
            ),
        )
        if cursor.rowcount != 1:
            self._raise_failure(connection, workspace_id, content_id, expected_row_version, source)
        updated = self.get_content(connection, workspace_id, content_id)
        if updated is None:
            raise ContentStateTransitionNotFoundError()
        return updated

    def transition_content_version(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        version_id: str,
        expected_row_version: int,
        source: ContentVersionStatus,
        target: ContentVersionStatus,
    ) -> ContentVersion:
        if (
            source is not ContentVersionStatus.DRAFT
            or target is not ContentVersionStatus.REVIEW_REQUIRED
        ):
            raise ContentStateTransitionInvalidError()
        cursor = connection.execute(
            "UPDATE content_versions SET status=?,row_version=row_version+1 "
            "WHERE id=? AND row_version=? AND status=? AND EXISTS(SELECT 1 FROM contents c "
            "WHERE c.id=content_versions.content_id AND c.workspace_id=?)",
            (target.value, version_id, expected_row_version, source.value, workspace_id),
        )
        if cursor.rowcount != 1:
            current = self.get_content_version(connection, workspace_id, version_id)
            if current is None:
                raise ContentStateTransitionNotFoundError()
            if current.row_version != expected_row_version:
                raise ContentStateTransitionConflictError()
            raise ContentStateTransitionInvalidError()
        updated = self.get_content_version(connection, workspace_id, version_id)
        if updated is None:
            raise ContentStateTransitionNotFoundError()
        return updated

    def _raise_failure(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        content_id: str,
        expected_row_version: int,
        source: ContentStatus,
    ) -> None:
        current = self.get_content(connection, workspace_id, content_id)
        if current is None:
            raise ContentStateTransitionNotFoundError()
        if current.row_version != expected_row_version:
            raise ContentStateTransitionConflictError()
        if current.status is not source:
            raise ContentStateTransitionInvalidError()
        raise ContentStateTransitionRepositoryError(
            "DOMAIN_VALIDATION_FAILED", "content transition precondition failed"
        )
