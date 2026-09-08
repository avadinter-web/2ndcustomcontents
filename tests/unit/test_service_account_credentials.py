from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import (
    RotateServiceAccountCredentialReference,
    ServiceAccountCredentialService,
)
from custom_content_studio.domain.security import (
    Action,
    ActorContext,
    ActorType,
    Role,
    SecretReference,
    SecurityError,
)
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteAuditEventRepository,
    SQLiteServiceAccountRepository,
)
from custom_content_studio.persistence import SQLiteConnectionFactory

NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _actor(
    *,
    actor_type: ActorType = ActorType.USER,
    role: Role = Role.ADMIN,
    workspace_id: str = "workspace-1",
    scopes: frozenset[str] = frozenset(),
) -> ActorContext:
    return ActorContext(
        actor_type=actor_type,
        actor_id="actor-1",
        authentication_id="auth-1",
        workspace_id=workspace_id,
        roles=frozenset({role}),
        scopes=scopes,
        authenticated_at_utc=NOW,
    )


def _command(
    actor: ActorContext, locator: str = "synthetic://new/reference"
) -> RotateServiceAccountCredentialReference:
    return RotateServiceAccountCredentialReference(
        workspace_id="workspace-1",
        service_account_id="service-account-1",
        actor=actor,
        expected_updated_at_utc=NOW,
        new_secret_ref=SecretReference(locator),
        rotated_at_utc=NOW + timedelta(minutes=1),
    )


def _service(tmp_path: Path) -> ServiceAccountCredentialService:
    return ServiceAccountCredentialService(
        SQLiteConnectionFactory((tmp_path / "never-opened.sqlite3").resolve()),
        SQLiteServiceAccountRepository(),
        SQLiteAuditEventRepository(),
    )


@pytest.mark.parametrize(
    "actor",
    [
        _actor(role=Role.EDITOR),
        _actor(actor_type=ActorType.SERVICE_ACCOUNT),
        _actor(workspace_id="workspace-2"),
        _actor(scopes=frozenset({Action.WORKSPACE_READ.value.casefold()})),
    ],
)
def test_non_user_admin_or_wrong_scope_is_denied_before_database_open(
    tmp_path: Path,
    actor: ActorContext,
) -> None:
    service = _service(tmp_path)
    with pytest.raises(SecurityError) as caught:
        service.rotate_reference(_command(actor))
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
    assert not (tmp_path / "never-opened.sqlite3").exists()


def test_command_requires_utc_and_masks_reference() -> None:
    locator = "synthetic://new/reference"
    command = _command(_actor(), locator)
    assert locator not in repr(command)
    with pytest.raises(ValueError, match="timezone-aware UTC"):
        RotateServiceAccountCredentialReference(
            workspace_id="workspace-1",
            service_account_id="service-account-1",
            actor=_actor(),
            expected_updated_at_utc=NOW.replace(tzinfo=None),
            new_secret_ref=SecretReference(locator),
            rotated_at_utc=NOW + timedelta(minutes=1),
        )
