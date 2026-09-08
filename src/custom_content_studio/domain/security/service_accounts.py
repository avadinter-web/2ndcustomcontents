from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import StrEnum

from .models import SecretReference


def _require_identifier(value: str, name: str) -> None:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")


def _require_utc(value: datetime, name: str) -> None:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


class ServiceAccountStatus(StrEnum):
    ACTIVE = "ACTIVE"
    DISABLED = "DISABLED"


@dataclass(frozen=True)
class ServiceAccountCredentialState:
    service_account_id: str
    workspace_id: str
    status: ServiceAccountStatus
    permissions: frozenset[str]
    credential_secret_ref: SecretReference | None = field(repr=False)
    credential_rotated_at_utc: datetime | None
    updated_at_utc: datetime

    def __post_init__(self) -> None:
        _require_identifier(self.service_account_id, "service_account_id")
        _require_identifier(self.workspace_id, "workspace_id")
        if not isinstance(self.status, ServiceAccountStatus):
            raise TypeError("status must be a ServiceAccountStatus")
        if not isinstance(self.permissions, frozenset) or any(
            not isinstance(permission, str) or not permission or permission != permission.strip()
            for permission in self.permissions
        ):
            raise TypeError("permissions must be a frozenset of non-empty strings")
        if self.credential_secret_ref is not None and not isinstance(
            self.credential_secret_ref, SecretReference
        ):
            raise TypeError("credential_secret_ref must be a SecretReference or None")
        if self.credential_rotated_at_utc is not None:
            _require_utc(self.credential_rotated_at_utc, "credential_rotated_at_utc")
        _require_utc(self.updated_at_utc, "updated_at_utc")
