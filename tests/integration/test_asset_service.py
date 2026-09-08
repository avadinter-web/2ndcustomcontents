import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import AssetService, RegisterAsset, UpdateAsset
from custom_content_studio.domain import Asset, AssetStatus, AssetType, StorageProvider
from custom_content_studio.domain.security import (
    ActorContext,
    ActorType,
    Role,
    SecurityError,
)
from custom_content_studio.infrastructure.sqlite.repositories import SQLiteAssetRepository
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "asset-service.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        uow.commit()
    return factory


def _seed_parents(connection: sqlite3.Connection) -> None:
    for suffix in ("1", "2"):
        workspace_id = f"workspace-{suffix}"
        connection.execute(
            "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
            (workspace_id, workspace_id, "2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
        )
        connection.execute(
            "INSERT INTO projects(id,workspace_id,name,status,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?)",
            (
                f"project-{suffix}",
                workspace_id,
                workspace_id,
                "ACTIVE",
                "2026-09-08T00:00:00Z",
                "2026-09-08T00:00:00Z",
            ),
        )


def _actor(
    *,
    workspace_id: str = "workspace-1",
    role: Role = Role.EDITOR,
    actor_type: ActorType = ActorType.USER,
    scopes: frozenset[str] = frozenset(),
) -> ActorContext:
    return ActorContext(
        actor_type=actor_type,
        actor_id="actor-1",
        authentication_id="session-1",
        workspace_id=workspace_id,
        roles=frozenset() if actor_type is ActorType.SERVICE_ACCOUNT else frozenset({role}),
        scopes=scopes,
        authenticated_at_utc=NOW,
    )


def _asset(
    project_id: str | None = "project-1",
    *,
    asset_id: str = "asset-1",
    workspace_id: str = "workspace-1",
) -> Asset:
    return Asset(
        asset_id=asset_id,
        workspace_id=workspace_id,
        project_id=project_id,
        asset_type=AssetType.IMAGE,
        storage_provider=StorageProvider.LOCAL,
        storage_key="incoming/image.png",
        original_filename="image.png",
        mime_type="image/png",
        size_bytes=64,
        checksum_sha256="b" * 64,
        metadata={},
        status=AssetStatus.AVAILABLE,
        created_at_utc=NOW,
        updated_at_utc=NOW,
    )


@pytest.mark.parametrize(
    "actor",
    [
        _actor(role=Role.EDITOR),
        _actor(
            actor_type=ActorType.SERVICE_ACCOUNT,
            scopes=frozenset({"content_edit"}),
        ),
    ],
)
def test_existing_content_edit_contract_authorizes_registration(
    tmp_path: Path, actor: ActorContext
) -> None:
    factory = _factory(tmp_path)
    service = AssetService(factory, SQLiteAssetRepository())
    registered = service.register(RegisterAsset(actor=actor, asset=_asset()))
    assert registered.asset_id == "asset-1"

    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM assets").fetchone()[0] == 1
    finally:
        connection.close()


@pytest.mark.parametrize(
    "actor",
    [_actor(role=Role.VIEWER), _actor(workspace_id="workspace-2")],
)
def test_unauthorized_registration_has_no_partial_write(
    tmp_path: Path, actor: ActorContext
) -> None:
    factory = _factory(tmp_path)
    service = AssetService(factory, SQLiteAssetRepository())
    with pytest.raises(SecurityError) as caught:
        service.register(RegisterAsset(actor=actor, asset=_asset()))
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM assets").fetchone()[0] == 0
    finally:
        connection.close()


def test_update_preserves_identity_and_uses_exact_cas(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = AssetService(factory, SQLiteAssetRepository())
    actor = _actor()
    service.register(RegisterAsset(actor=actor, asset=_asset()))
    updated = service.update(
        UpdateAsset(
            actor=actor,
            workspace_id="workspace-1",
            asset_id="asset-1",
            expected_row_version=1,
            project_id=None,
            metadata={"label": "approved"},
            status=AssetStatus.AVAILABLE,
            updated_at_utc=NOW + timedelta(seconds=1),
        )
    )
    assert updated.row_version == 2
    assert updated.storage_key == "incoming/image.png"
    with pytest.raises(SecurityError) as caught:
        service.update(
            UpdateAsset(
                actor=actor,
                workspace_id="workspace-1",
                asset_id="asset-1",
                expected_row_version=1,
                project_id=None,
                metadata={},
                status=AssetStatus.AVAILABLE,
                updated_at_utc=NOW + timedelta(seconds=2),
            )
        )
    assert caught.value.code == "VERSION_CONFLICT"


@pytest.mark.parametrize("asset_id", ["missing", "foreign"])
def test_missing_and_cross_workspace_assets_share_safe_denial(
    tmp_path: Path, asset_id: str
) -> None:
    factory = _factory(tmp_path)
    with SQLiteUnitOfWork(factory) as uow:
        if asset_id == "foreign":
            foreign = _asset("project-2", asset_id="foreign", workspace_id="workspace-2")
            SQLiteAssetRepository().create(uow.connection, foreign)
        uow.commit()
    command = UpdateAsset(
        actor=_actor(),
        workspace_id="workspace-1",
        asset_id=asset_id,
        expected_row_version=1,
        project_id=None,
        metadata={},
        status=AssetStatus.AVAILABLE,
        updated_at_utc=NOW + timedelta(seconds=1),
    )
    with pytest.raises(SecurityError) as caught:
        AssetService(factory, SQLiteAssetRepository()).update(command)
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
    assert asset_id not in str(caught.value)


def test_cross_workspace_project_association_is_concealed(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    service = AssetService(factory, SQLiteAssetRepository())
    with pytest.raises(SecurityError) as caught:
        service.register(RegisterAsset(actor=_actor(), asset=_asset("project-2")))
    assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
