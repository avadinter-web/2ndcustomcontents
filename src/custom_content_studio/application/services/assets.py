from __future__ import annotations

import json
from collections.abc import Mapping
from dataclasses import dataclass, replace
from datetime import datetime, timedelta
from types import MappingProxyType

from ...domain.assets import Asset, AssetStatus
from ...domain.security import Action, ActorContext, SecurityError, require_action
from ...domain.workspaces import JsonValue
from ...persistence import SQLiteConnectionFactory, SQLiteUnitOfWork
from ..ports.asset_repository import (
    AssetArchivedError,
    AssetConflictError,
    AssetNotFoundError,
    AssetRepositoryPort,
)


def _require_trimmed(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_utc(value: datetime, name: str) -> None:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


def _copy_metadata(value: Mapping[str, JsonValue]) -> Mapping[str, JsonValue]:
    if not isinstance(value, Mapping):
        raise TypeError("metadata must be a JSON object")
    try:
        decoded = json.loads(
            json.dumps(dict(value), allow_nan=False, ensure_ascii=False, sort_keys=True)
        )
    except (TypeError, ValueError) as error:
        raise ValueError("metadata must be a JSON object") from error
    if not isinstance(decoded, dict):
        raise ValueError("metadata must be a JSON object")
    return MappingProxyType(decoded)


@dataclass(frozen=True)
class RegisterAsset:
    actor: ActorContext
    asset: Asset

    def __post_init__(self) -> None:
        if not isinstance(self.actor, ActorContext):
            raise TypeError("actor must be an ActorContext")
        if not isinstance(self.asset, Asset):
            raise TypeError("asset must be an Asset")


@dataclass(frozen=True)
class UpdateAsset:
    actor: ActorContext
    workspace_id: str
    asset_id: str
    expected_row_version: int
    project_id: str | None
    metadata: Mapping[str, JsonValue]
    status: AssetStatus
    updated_at_utc: datetime

    def __post_init__(self) -> None:
        if not isinstance(self.actor, ActorContext):
            raise TypeError("actor must be an ActorContext")
        _require_trimmed(self.workspace_id, "workspace_id")
        _require_trimmed(self.asset_id, "asset_id")
        if isinstance(self.expected_row_version, bool) or self.expected_row_version < 1:
            raise ValueError("expected_row_version must be positive")
        if self.project_id is not None:
            _require_trimmed(self.project_id, "project_id")
        object.__setattr__(self, "metadata", _copy_metadata(self.metadata))
        if not isinstance(self.status, AssetStatus):
            raise TypeError("status must be an AssetStatus")
        _require_utc(self.updated_at_utc, "updated_at_utc")


class AssetService:
    def __init__(self, factory: SQLiteConnectionFactory, assets: AssetRepositoryPort) -> None:
        self._factory = factory
        self._assets = assets

    def register(self, command: RegisterAsset) -> Asset:
        require_action(command.actor, command.asset.workspace_id, Action.CONTENT_EDIT)
        with SQLiteUnitOfWork(self._factory) as uow:
            try:
                self._assets.create(uow.connection, command.asset)
            except AssetNotFoundError as error:
                raise self._access_denied() from error
            uow.commit()
        return command.asset

    def update(self, command: UpdateAsset) -> Asset:
        require_action(command.actor, command.workspace_id, Action.CONTENT_EDIT)
        with SQLiteUnitOfWork(self._factory) as uow:
            current = self._assets.get_by_id(uow.connection, command.workspace_id, command.asset_id)
            if current is None:
                raise self._access_denied()
            if current.row_version != command.expected_row_version:
                raise SecurityError("VERSION_CONFLICT", "asset state changed")
            if current.is_archived:
                raise SecurityError("DOMAIN_VALIDATION_FAILED", "asset is archived")
            if command.updated_at_utc <= current.updated_at_utc:
                raise SecurityError(
                    "DOMAIN_VALIDATION_FAILED", "asset update time must advance state"
                )
            candidate = replace(
                current,
                project_id=command.project_id,
                metadata=command.metadata,
                status=command.status,
                updated_at_utc=command.updated_at_utc,
            )
            try:
                updated = self._assets.update(uow.connection, candidate)
            except AssetNotFoundError as error:
                raise self._access_denied() from error
            except AssetConflictError as error:
                raise SecurityError("VERSION_CONFLICT", "asset state changed") from error
            except AssetArchivedError as error:
                raise SecurityError("DOMAIN_VALIDATION_FAILED", "asset is archived") from error
            uow.commit()
            return updated

    @staticmethod
    def _access_denied() -> SecurityError:
        return SecurityError("WORKSPACE_ACCESS_DENIED", "workspace action is not permitted")
