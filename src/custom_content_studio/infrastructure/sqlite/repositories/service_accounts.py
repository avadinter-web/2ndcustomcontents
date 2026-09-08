from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime

from ....domain.security import (
    SecretReference,
    SecurityError,
    ServiceAccountCredentialState,
    ServiceAccountStatus,
)


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise SecurityError("DOMAIN_VALIDATION_FAILED", "service account timestamp is invalid")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise SecurityError(
            "DOMAIN_VALIDATION_FAILED", "service account timestamp is invalid"
        ) from error
    if parsed.tzinfo is None:
        raise SecurityError("DOMAIN_VALIDATION_FAILED", "service account timestamp is invalid")
    return parsed.astimezone(UTC)


def _permissions(value: object) -> frozenset[str]:
    if not isinstance(value, str):
        raise SecurityError("DOMAIN_VALIDATION_FAILED", "service account permissions are invalid")
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as error:
        raise SecurityError(
            "DOMAIN_VALIDATION_FAILED", "service account permissions are invalid"
        ) from error
    if not isinstance(parsed, list) or any(not isinstance(item, str) for item in parsed):
        raise SecurityError("DOMAIN_VALIDATION_FAILED", "service account permissions are invalid")
    return frozenset(parsed)


def _to_state(row: sqlite3.Row) -> ServiceAccountCredentialState:
    secret_ref = row["credential_secret_ref"]
    return ServiceAccountCredentialState(
        service_account_id=str(row["id"]),
        workspace_id=str(row["workspace_id"]),
        status=ServiceAccountStatus(str(row["status"])),
        permissions=_permissions(row["permissions_json"]),
        credential_secret_ref=(None if secret_ref is None else SecretReference(str(secret_ref))),
        credential_rotated_at_utc=(
            None
            if row["credential_rotated_at"] is None
            else _datetime(row["credential_rotated_at"])
        ),
        updated_at_utc=_datetime(row["updated_at"]),
    )


class SQLiteServiceAccountRepository:
    def get_for_credential_rotation(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        service_account_id: str,
    ) -> ServiceAccountCredentialState | None:
        row = connection.execute(
            "SELECT id,workspace_id,status,permissions_json,credential_secret_ref,"
            "credential_rotated_at,updated_at FROM service_accounts "
            "WHERE workspace_id=? AND id=?",
            (workspace_id, service_account_id),
        ).fetchone()
        return None if row is None else _to_state(row)

    def rotate_credential_reference_cas(
        self,
        connection: sqlite3.Connection,
        workspace_id: str,
        service_account_id: str,
        expected_updated_at_utc: datetime,
        new_secret_ref: SecretReference,
        rotated_at_utc: datetime,
    ) -> bool:
        cursor = connection.execute(
            "UPDATE service_accounts SET credential_secret_ref=?,credential_rotated_at=?,"
            "updated_at=? WHERE workspace_id=? AND id=? AND updated_at=?",
            (
                new_secret_ref.locator_for_storage(),
                _iso(rotated_at_utc),
                _iso(rotated_at_utc),
                workspace_id,
                service_account_id,
                _iso(expected_updated_at_utc),
            ),
        )
        return cursor.rowcount == 1
