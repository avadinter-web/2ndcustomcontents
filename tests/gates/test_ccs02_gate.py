from __future__ import annotations

import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import (
    ActivateContent,
    ArchiveContent,
    AssetService,
    ContentService,
    ContentStateTransitionService,
    ContentVersionService,
    CreateContent,
    CreateContentVersion,
    RegisterAsset,
    SubmitContentVersionForReview,
    UpdateContent,
)
from custom_content_studio.domain import (
    Asset,
    AssetStatus,
    AssetType,
    ContentStatus,
    ContentType,
    ContentVersionSnapshot,
    Project,
    ProjectStatus,
    StorageProvider,
    Workspace,
)
from custom_content_studio.domain.security import ActorContext, ActorType, Role, SecurityError
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteAssetRepository,
    SQLiteContentRepository,
    SQLiteContentStateTransitionRepository,
    SQLiteContentVersionRepository,
    SQLiteProjectRepository,
    SQLiteWorkspaceRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

ROOT = Path(__file__).resolve().parents[2]
NOW = datetime(2026, 9, 9, tzinfo=UTC)


def _actor(workspace_id: str = "workspace-1") -> ActorContext:
    return ActorContext(
        actor_type=ActorType.USER,
        actor_id="user-1",
        authentication_id="gate-auth",
        workspace_id=workspace_id,
        roles=frozenset({Role.EDITOR}),
        scopes=frozenset(),
        authenticated_at_utc=NOW,
    )


def _seed(factory: SQLiteConnectionFactory) -> None:
    workspaces = SQLiteWorkspaceRepository()
    projects = SQLiteProjectRepository()
    with SQLiteUnitOfWork(factory) as uow:
        connection = uow.connection
        connection.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES ('user-1','gate@example.test','gate@example.test','ACTIVE',?,?)",
            ("2026-09-09T00:00:00Z",) * 2,
        )
        for suffix in ("1", "2"):
            workspace_id = f"workspace-{suffix}"
            workspaces.create(
                connection,
                Workspace(
                    workspace_id=workspace_id,
                    name=f"Workspace {suffix}",
                    timezone="UTC",
                    settings={"gate": True},
                    created_at_utc=NOW,
                    updated_at_utc=NOW,
                ),
            )
            projects.create(
                connection,
                Project(
                    project_id=f"project-{suffix}",
                    workspace_id=workspace_id,
                    name=f"Project {suffix}",
                    description=None,
                    content_type=None,
                    default_language="ko",
                    default_platforms=("YOUTUBE",),
                    brand_profile_ref=None,
                    status=ProjectStatus.ACTIVE,
                    created_at_utc=NOW,
                    updated_at_utc=NOW,
                ),
            )
        connection.execute(
            "INSERT INTO workspace_memberships(workspace_id,user_id,role,created_at,updated_at) "
            "VALUES ('workspace-1','user-1','EDITOR',?,?)",
            ("2026-09-09T00:00:00Z",) * 2,
        )
        uow.commit()


def test_ccs02_fresh_sqlite_persistence_restart_and_immutable_core_gate(tmp_path: Path) -> None:
    """T-011/013/014/015/016/017/INT-031/INT-050 for F-003..006 and INV-WS/IMM."""
    factory = SQLiteConnectionFactory((tmp_path / "ccs02-gate.sqlite3").resolve())
    MigrationRunner(factory, ROOT / "migrations").migrate_fresh()
    _seed(factory)

    assets = SQLiteAssetRepository()
    contents = SQLiteContentRepository()
    versions = SQLiteContentVersionRepository()
    asset_service = AssetService(factory, assets)
    content_service = ContentService(factory, contents)
    version_service = ContentVersionService(factory, contents, versions)
    transition_service = ContentStateTransitionService(
        factory, SQLiteContentStateTransitionRepository()
    )
    actor = _actor()

    asset_service.register(
        RegisterAsset(
            actor=actor,
            asset=Asset(
                asset_id="asset-1",
                workspace_id="workspace-1",
                project_id="project-1",
                asset_type=AssetType.IMAGE,
                storage_provider=StorageProvider.LOCAL,
                storage_key="gate/asset-1.png",
                original_filename="asset-1.png",
                mime_type="image/png",
                size_bytes=1,
                checksum_sha256="a" * 64,
                metadata={"source": "gate"},
                status=AssetStatus.AVAILABLE,
                created_at_utc=NOW,
                updated_at_utc=NOW,
            ),
        )
    )
    created = content_service.create(
        CreateContent(
            actor=actor,
            content_id="content-1",
            workspace_id="workspace-1",
            project_id="project-1",
            title="Gate content",
            content_type=ContentType.SHORT,
            primary_platform="YOUTUBE",
            goal="Verify restart",
            created_at_utc=NOW,
        )
    )
    assert created.status is ContentStatus.IDEA and created.row_version == 1
    draft = version_service.create(
        CreateContentVersion(
            actor=actor,
            workspace_id="workspace-1",
            content_id="content-1",
            version_id="version-1",
            expected_content_row_version=1,
            expected_current_version_id=None,
            parent_version_id=None,
            snapshot=ContentVersionSnapshot(
                title="Gate content", script={"body": "verified"}, content={"kind": "gate"}
            ),
            created_at_utc=NOW + timedelta(seconds=1),
        )
    )
    with pytest.raises(SecurityError, match="VERSION_CONFLICT"):
        version_service.create(
            CreateContentVersion(
                actor=actor,
                workspace_id="workspace-1",
                content_id="content-1",
                version_id="orphan-version",
                expected_content_row_version=1,
                expected_current_version_id=None,
                parent_version_id=None,
                snapshot=ContentVersionSnapshot(title="Orphan", script=None, content={}),
                created_at_utc=NOW + timedelta(seconds=2),
            )
        )
    active = transition_service.activate(
        ActivateContent(
            actor=actor,
            workspace_id="workspace-1",
            content_id="content-1",
            expected_row_version=2,
            transitioned_at_utc=NOW + timedelta(seconds=2),
        )
    )
    reviewed = transition_service.submit_for_review(
        SubmitContentVersionForReview(
            actor=actor,
            workspace_id="workspace-1",
            content_version_id="version-1",
            expected_row_version=draft.row_version,
            transitioned_at_utc=NOW + timedelta(seconds=3),
        )
    )
    archived = transition_service.archive(
        ArchiveContent(
            actor=actor,
            workspace_id="workspace-1",
            content_id="content-1",
            expected_row_version=active.row_version,
            transitioned_at_utc=NOW + timedelta(seconds=4),
        )
    )
    assert (active.status, reviewed.status, archived.status, archived.row_version) == (
        ContentStatus.ACTIVE,
        "REVIEW_REQUIRED",
        ContentStatus.ARCHIVED,
        4,
    )
    assert {status.value for status in ContentStatus} == {"IDEA", "ACTIVE", "ARCHIVED"}

    with pytest.raises(SecurityError) as stale_update:
        content_service.update(
            UpdateContent(
                actor=actor,
                workspace_id="workspace-1",
                content_id="content-1",
                expected_row_version=3,
                title="stale",
                content_type=ContentType.SHORT,
                primary_platform="YOUTUBE",
                goal=None,
                updated_at_utc=NOW + timedelta(seconds=5),
            )
        )
    assert stale_update.value.code == "VERSION_CONFLICT"
    with pytest.raises(SecurityError) as hidden_foreign:
        content_service.create(
            CreateContent(
                actor=actor,
                content_id="foreign-content",
                workspace_id="workspace-1",
                project_id="project-2",
                title="Hidden",
                content_type=ContentType.SHORT,
                primary_platform=None,
                goal=None,
                created_at_utc=NOW,
            )
        )
    assert hidden_foreign.value.code == "WORKSPACE_ACCESS_DENIED"

    connection = factory.connect()
    try:
        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                "INSERT INTO projects(id,workspace_id,name,status,created_at,updated_at) "
                "VALUES ('foreign-project','missing-workspace','invalid','ACTIVE',?,?)",
                ("2026-09-09T00:00:00Z",) * 2,
            )
        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                "INSERT INTO assets(id,workspace_id,asset_type,storage_provider,storage_key,"
                "original_filename,mime_type,metadata_json,status,created_at,updated_at) "
                "VALUES ('duplicate-asset','workspace-1','IMAGE','LOCAL','gate/asset-1.png',"
                "'duplicate.png','image/png','{}','MISSING',?,?)",
                ("2026-09-09T00:00:00Z",) * 2,
            )
        with pytest.raises(sqlite3.IntegrityError, match="content version history is immutable"):
            connection.execute("DELETE FROM content_versions WHERE id='version-1'")
        assert (
            connection.execute(
                "SELECT COUNT(*) FROM content_versions WHERE id='orphan-version'"
            ).fetchone()[0]
            == 0
        )
    finally:
        connection.close()

    restarted = SQLiteConnectionFactory(factory.database_path)
    reopened = restarted.connect()
    try:
        workspace = SQLiteWorkspaceRepository().get_by_id(reopened, "workspace-1")
        project = SQLiteProjectRepository().get_by_id(reopened, "workspace-1", "project-1")
        asset = assets.get_by_id(reopened, "workspace-1", "asset-1")
        content = contents.get_by_id(reopened, "workspace-1", "content-1")
        version = versions.get_by_id(reopened, "workspace-1", "version-1")
        assert workspace is not None and workspace.row_version == 1
        assert project is not None and project.row_version == 1
        assert asset is not None and asset.row_version == 1
        assert content is not None and content.current_version_id == "version-1"
        assert content.status is ContentStatus.ARCHIVED and content.row_version == 4
        assert version is not None
        assert version.row_version == 2
        assert version.status == "REVIEW_REQUIRED"
        assert contents.get_by_id(reopened, "workspace-2", "content-1") is None
        assert assets.get_by_id(reopened, "workspace-2", "asset-1") is None
    finally:
        reopened.close()
