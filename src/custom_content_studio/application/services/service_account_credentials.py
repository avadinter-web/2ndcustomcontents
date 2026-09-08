from __future__ import annotations

import hashlib
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from uuid import uuid4

from ...domain.security import (
    Action,
    ActorContext,
    ActorType,
    Role,
    SecretReference,
    SecurityError,
    require_action,
)
from ...persistence import SQLiteConnectionFactory, SQLiteUnitOfWork
from ..ports import AuditEventAppendPort, AuditEventDraft, ServiceAccountRepositoryPort


def _require_identifier(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_utc(value: datetime, name: str) -> None:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


@dataclass(frozen=True)
class RotateServiceAccountCredentialReference:
    workspace_id: str
    service_account_id: str
    actor: ActorContext
    expected_updated_at_utc: datetime
    new_secret_ref: SecretReference = field(repr=False)
    rotated_at_utc: datetime

    def __post_init__(self) -> None:
        _require_identifier(self.workspace_id, "workspace_id")
        _require_identifier(self.service_account_id, "service_account_id")
        if not isinstance(self.actor, ActorContext):
            raise TypeError("actor must be an ActorContext")
        if not isinstance(self.new_secret_ref, SecretReference):
            raise TypeError("new_secret_ref must be a SecretReference")
        _require_utc(self.expected_updated_at_utc, "expected_updated_at_utc")
        _require_utc(self.rotated_at_utc, "rotated_at_utc")


@dataclass(frozen=True)
class ServiceAccountCredentialRotationResult:
    service_account_id: str
    workspace_id: str
    updated_at_utc: datetime
    audit_event_id: str
    audit_sequence_no: int
    audit_event_hash: str


class ServiceAccountCredentialService:
    def __init__(
        self,
        factory: SQLiteConnectionFactory,
        service_accounts: ServiceAccountRepositoryPort,
        audit_events: AuditEventAppendPort,
        *,
        event_id_factory: Callable[[], str] | None = None,
    ) -> None:
        self._factory = factory
        self._service_accounts = service_accounts
        self._audit_events = audit_events
        self._event_id_factory = event_id_factory or (lambda: uuid4().hex)

    def rotate_reference(
        self,
        command: RotateServiceAccountCredentialReference,
    ) -> ServiceAccountCredentialRotationResult:
        self._authorize(command)
        with SQLiteUnitOfWork(self._factory) as uow:
            state = self._service_accounts.get_for_credential_rotation(
                uow.connection,
                command.workspace_id,
                command.service_account_id,
            )
            if state is None:
                raise SecurityError("WORKSPACE_ACCESS_DENIED", "workspace action is not permitted")
            if state.updated_at_utc != command.expected_updated_at_utc:
                raise SecurityError("VERSION_CONFLICT", "service account state changed")
            current_ref = state.credential_secret_ref
            if current_ref is None:
                raise SecurityError(
                    "DOMAIN_VALIDATION_FAILED",
                    "service account credential reference is not initialized",
                )
            if current_ref.locator_for_storage() == command.new_secret_ref.locator_for_storage():
                raise SecurityError(
                    "DOMAIN_VALIDATION_FAILED",
                    "replacement credential reference must be different",
                )
            if command.rotated_at_utc <= state.updated_at_utc or (
                state.credential_rotated_at_utc is not None
                and command.rotated_at_utc <= state.credential_rotated_at_utc
            ):
                raise SecurityError(
                    "DOMAIN_VALIDATION_FAILED", "credential rotation time must advance state"
                )
            updated = self._service_accounts.rotate_credential_reference_cas(
                uow.connection,
                command.workspace_id,
                command.service_account_id,
                command.expected_updated_at_utc,
                command.new_secret_ref,
                command.rotated_at_utc,
            )
            if not updated:
                raise SecurityError("VERSION_CONFLICT", "service account state changed")

            audit = self._audit_events.append(
                uow.connection,
                AuditEventDraft(
                    event_id=self._new_event_id(),
                    workspace_id=command.workspace_id,
                    stream_key=f"workspace:{command.workspace_id}",
                    actor_type=ActorType.USER.value,
                    actor_id=command.actor.actor_id,
                    action="SERVICE_ACCOUNT_CREDENTIAL_ROTATED",
                    entity_type="SERVICE_ACCOUNT",
                    entity_id=command.service_account_id,
                    event_json={
                        "_schema": "ccs.service-account-credential-rotation",
                        "_version": 1,
                        "new_secret_ref_sha256": self._locator_hash(command.new_secret_ref),
                        "old_secret_ref_sha256": self._locator_hash(current_ref),
                    },
                    occurred_at_utc=command.rotated_at_utc,
                ),
            )
            uow.commit()
            return ServiceAccountCredentialRotationResult(
                service_account_id=command.service_account_id,
                workspace_id=command.workspace_id,
                updated_at_utc=command.rotated_at_utc,
                audit_event_id=audit.event_id,
                audit_sequence_no=audit.sequence_no,
                audit_event_hash=audit.event_hash,
            )

    @staticmethod
    def _authorize(command: RotateServiceAccountCredentialReference) -> None:
        actor = command.actor
        if actor.actor_type is not ActorType.USER or Role.ADMIN not in actor.roles:
            raise SecurityError("WORKSPACE_ACCESS_DENIED", "workspace action is not permitted")
        require_action(actor, command.workspace_id, Action.SECRET_REFERENCE_MANAGE)

    def _new_event_id(self) -> str:
        event_id = self._event_id_factory()
        _require_identifier(event_id, "audit event id")
        return event_id

    @staticmethod
    def _locator_hash(secret_ref: SecretReference) -> str:
        locator = secret_ref.locator_for_storage()
        return hashlib.sha256(locator.encode("utf-8")).hexdigest()
