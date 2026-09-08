from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

from custom_content_studio.domain.security import SecretReference, ServiceAccountStatus
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteServiceAccountRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "service-accounts.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _seed(factory: SQLiteConnectionFactory, *, status: str = "DISABLED") -> None:
    with SQLiteUnitOfWork(factory) as uow:
        uow.connection.execute(
            "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
            ("workspace-1", "Workspace", "2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
        )
        uow.connection.execute(
            "INSERT INTO service_accounts(id,workspace_id,name,status,permissions_json,"
            "credential_secret_ref,credential_rotated_at,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?,?,?,?)",
            (
                "service-account-1",
                "workspace-1",
                "Renderer",
                status,
                '["render","publish"]',
                "synthetic://old/reference",
                "2026-09-07T00:00:00Z",
                "2026-09-07T00:00:00Z",
                "2026-09-08T00:00:00Z",
            ),
        )
        uow.commit()


def test_scoped_lookup_returns_reference_state_without_cross_workspace_fallback(
    tmp_path: Path,
) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    repository = SQLiteServiceAccountRepository()
    connection = factory.connect()
    try:
        state = repository.get_for_credential_rotation(
            connection, "workspace-1", "service-account-1"
        )
        hidden = repository.get_for_credential_rotation(
            connection, "workspace-2", "service-account-1"
        )
    finally:
        connection.close()
    assert state is not None
    assert state.status is ServiceAccountStatus.DISABLED
    assert state.permissions == frozenset({"render", "publish"})
    assert state.credential_secret_ref is not None
    assert state.credential_secret_ref.locator_for_storage() == "synthetic://old/reference"
    assert hidden is None


def test_rotation_cas_updates_only_reference_timestamps_and_does_not_commit(
    tmp_path: Path,
) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    repository = SQLiteServiceAccountRepository()
    rotated_at = NOW + timedelta(minutes=1)
    with SQLiteUnitOfWork(factory) as uow:
        assert repository.rotate_credential_reference_cas(
            uow.connection,
            "workspace-1",
            "service-account-1",
            NOW,
            SecretReference("synthetic://new/reference"),
            rotated_at,
        )
        row = uow.connection.execute(
            "SELECT name,status,permissions_json,credential_secret_ref,credential_rotated_at,"
            "updated_at,created_at FROM service_accounts WHERE id='service-account-1'"
        ).fetchone()
        assert tuple(row) == (
            "Renderer",
            "DISABLED",
            '["render","publish"]',
            "synthetic://new/reference",
            "2026-09-08T00:01:00Z",
            "2026-09-08T00:01:00Z",
            "2026-09-07T00:00:00Z",
        )

    connection = factory.connect()
    try:
        persisted = connection.execute(
            "SELECT credential_secret_ref,updated_at FROM service_accounts"
        ).fetchone()
    finally:
        connection.close()
    assert tuple(persisted) == ("synthetic://old/reference", "2026-09-08T00:00:00Z")


def test_stale_cas_returns_false_without_mutation(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    repository = SQLiteServiceAccountRepository()
    with SQLiteUnitOfWork(factory) as uow:
        assert not repository.rotate_credential_reference_cas(
            uow.connection,
            "workspace-1",
            "service-account-1",
            NOW - timedelta(seconds=1),
            SecretReference("synthetic://new/reference"),
            NOW + timedelta(minutes=1),
        )
        uow.commit()
    connection = factory.connect()
    try:
        row = connection.execute(
            "SELECT credential_secret_ref,updated_at FROM service_accounts"
        ).fetchone()
    finally:
        connection.close()
    assert tuple(row) == ("synthetic://old/reference", "2026-09-08T00:00:00Z")
