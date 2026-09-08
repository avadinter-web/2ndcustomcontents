import sqlite3
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.ports import (
    AssetAlreadyExistsError,
    AssetArchivedError,
    AssetConflictError,
    AssetNotFoundError,
)
from custom_content_studio.domain import Asset, AssetStatus, AssetType, StorageProvider
from custom_content_studio.infrastructure.sqlite.repositories import SQLiteAssetRepository
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)
CHECKSUM = "a" * 64


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "assets.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _seed_parents(connection: sqlite3.Connection) -> None:
    for workspace_id in ("workspace-1", "workspace-2"):
        connection.execute(
            "INSERT INTO workspaces(id,name,created_at,updated_at) VALUES (?,?,?,?)",
            (workspace_id, workspace_id, "2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
        )
        connection.execute(
            "INSERT INTO projects(id,workspace_id,name,status,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?)",
            (
                f"project-{workspace_id[-1]}",
                workspace_id,
                workspace_id,
                "ACTIVE",
                "2026-09-08T00:00:00Z",
                "2026-09-08T00:00:00Z",
            ),
        )


def _asset(
    *,
    asset_id: str = "asset-1",
    project_id: str | None = "project-1",
    storage_key: str = "incoming/source.mp4",
) -> Asset:
    return Asset(
        asset_id=asset_id,
        workspace_id="workspace-1",
        project_id=project_id,
        asset_type=AssetType.SOURCE_VIDEO,
        storage_provider=StorageProvider.LOCAL,
        storage_key=storage_key,
        original_filename="source.mp4",
        mime_type="video/mp4",
        size_bytes=42,
        checksum_sha256=CHECKSUM,
        metadata={"width": 1920},
        status=AssetStatus.AVAILABLE,
        created_at_utc=NOW,
        updated_at_utc=NOW,
    )


def test_create_allows_nullable_project_and_never_commits(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAssetRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        repository.create(uow.connection, _asset(project_id=None))
        assert repository.get_by_id(uow.connection, "workspace-1", "asset-1") is not None

    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM assets").fetchone()[0] == 0
    finally:
        connection.close()


def test_project_and_asset_queries_are_workspace_scoped_and_persist_on_reopen(
    tmp_path: Path,
) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAssetRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        with pytest.raises(AssetNotFoundError):
            repository.create(uow.connection, _asset(project_id="project-2"))
        repository.create(uow.connection, _asset())
        uow.commit()

    connection = factory.connect()
    try:
        loaded = repository.get_by_id(connection, "workspace-1", "asset-1")
        assert loaded is not None
        assert loaded.project_id == "project-1"
        assert repository.get_by_id(connection, "workspace-2", "asset-1") is None
        assert repository.list_active(connection, "workspace-2") == ()
    finally:
        connection.close()


def test_duplicate_storage_identity_is_typed_and_has_no_partial_write(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAssetRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        repository.create(uow.connection, _asset())
        with pytest.raises(AssetAlreadyExistsError):
            repository.create(uow.connection, _asset(asset_id="asset-2"))
        assert uow.connection.execute("SELECT COUNT(*) FROM assets").fetchone()[0] == 1


def test_cas_update_keeps_available_physical_identity_and_blocks_archived(
    tmp_path: Path,
) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteAssetRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _seed_parents(uow.connection)
        repository.create(uow.connection, _asset())
        original = repository.get_by_id(uow.connection, "workspace-1", "asset-1")
        assert original is not None
        updated = repository.update(
            uow.connection,
            replace(
                original,
                storage_key="forbidden-change.mp4",
                metadata={"width": 1280},
                updated_at_utc=NOW + timedelta(seconds=1),
            ),
        )
        assert updated.storage_key == "incoming/source.mp4"
        assert updated.metadata == {"width": 1280}
        assert updated.row_version == 2
        with pytest.raises(AssetConflictError):
            repository.update(uow.connection, replace(original, metadata={"stale": True}))
        archived = repository.update(
            uow.connection,
            replace(
                updated,
                status=AssetStatus.ARCHIVED,
                updated_at_utc=NOW + timedelta(seconds=2),
            ),
        )
        assert repository.list_active(uow.connection, "workspace-1") == ()
        with pytest.raises(AssetArchivedError):
            repository.update(
                uow.connection,
                replace(
                    archived,
                    status=AssetStatus.FAILED,
                    updated_at_utc=NOW + timedelta(seconds=3),
                ),
            )
