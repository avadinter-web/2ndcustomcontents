from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Protocol

from ...domain.security import SecretReference, ServiceAccountCredentialState


class ServiceAccountRepositoryPort(Protocol):
    def get_for_credential_rotation(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        service_account_id: str,
    ) -> ServiceAccountCredentialState | None: ...

    def rotate_credential_reference_cas(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        service_account_id: str,
        expected_updated_at_utc: datetime,
        new_secret_ref: SecretReference,
        rotated_at_utc: datetime,
    ) -> bool: ...
