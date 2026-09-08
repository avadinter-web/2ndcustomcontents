# CCS-02-003 Asset Registry Discovery

Status: DISCOVERY COMPLETE / IMMUTABLE SUCCESSOR REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-08
Repository commit inspected: 6fc416aecdc814117eb916e87f46a728d089c8a9
Registry inspected: vc01b-local-20260907-r13
Canonical task: CCS-02-003 — Asset registry

## Read check

Understood as: define the smallest local Asset metadata registry that can be implemented after the
existing Workspace and Project core, including checksum/storage-reference identity and optional
same-Workspace Project association, while excluding storage/media/provider behavior. This report
is discovery evidence only and grants no code, test, registry, migration or external authority.

## Decision

CCS-02-003 belongs to **IMP-021**, not IMP-022. IMP-021 is the canonical “Asset identity, storage
registration and media probe” work package and depends on IMP-020. IMP-022 owns Content and
ContentVersion. The r13 row currently says `parent_work_package_id=IMP-022`; that is a normative
traceability conflict and must be corrected in a new immutable registry successor before dispatch.

The leaf must implement only the Asset registry portion of IMP-021. It must not absorb MediaProbe,
StoragePort, proxy, waveform or FFprobe work merely because the parent package later contains
those deliverables.

## Existing prerequisite and schema

- Workspace and Project domain/repository code exists at the inspected commit and is the direct
  prerequisite surface.
- `migrations/0001_initial_v2_2.sql` already defines `assets` with Workspace FK, optional Project
  FK, closed type/provider/status values, JSON metadata, checksum, size, `row_version`, unique
  `(workspace_id, storage_provider, storage_key)` and `UNIQUE(id, workspace_id)`.
- The same migration already has `trg_assets_project_workspace_ins/upd`, AVAILABLE physical
  identity immutability and referenced Project immutability backstops.
- Current migration SHA-256 is
  `2b532c6fbe5b45261f2cd815b6de4947d0a056b32754165fd06c1e9c12a2980f`.

**Migration decision: NONE.** This leaf consumes and tests the existing version-1 schema. Editing
the SQL or manifest, adding a migration, table replacement or backfill is forbidden. Any newly
discovered schema deficiency stops with `MIGRATION_DECISION_REQUIRED` and requires separate
change control.

## Exact implementation envelope proposed for the successor

Create:

- `src/custom_content_studio/domain/assets.py`
- `src/custom_content_studio/application/ports/asset_repository.py`
- `src/custom_content_studio/application/services/assets.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/assets.py`
- `tests/unit/test_asset_model.py`
- `tests/repository/test_asset_repository.py`
- `tests/integration/test_asset_service.py`
- `reports/IMP-021_CCS-02-003_IMPLEMENTATION.md`

Modify only to export/compose those types:

- `src/custom_content_studio/domain/__init__.py`
- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/application/services/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
- `src/custom_content_studio/bootstrap/composition.py`

No API/UI path is owned by CCS-02-003; CCS-02-010 owns Core UI/API.

## Owned behavior

- Immutable value model for Asset type, storage-provider reference, status, checksum, basic
  metadata, timestamps and positive row version.
- Register metadata only after a caller supplies an already-established storage reference; the
  service never reads, writes, uploads, downloads or verifies remote bytes.
- Workspace-scoped get/list and optional Project association. Project lookup is always
  `(workspace_id, project_id)`; missing and foreign Project/Asset targets share a non-revealing
  not-found/access-denied result.
- Lowercase 64-hex SHA-256 is required when an Asset is AVAILABLE. Size is non-negative. Critical
  metadata is a JSON object and is serialized deterministically.
- Project-link/status/basic-metadata mutation uses exact `row_version` CAS and increments once.
  AVAILABLE physical identity fields are never patched; replacement creates a new Asset.
- One caller-owned SQLite unit of work; repositories never commit independently.
- ActorContext Workspace and an existing content-edit permission protect service writes. If a
  distinct `ASSET_MANAGE` action is desired, that is a separate security-contract change rather
  than an invention inside this leaf.

## Feature, invariant and test ownership

- Own now: the Asset subset of F-004 and T-013 (unique storage identity, FK and restart
  persistence).
- Regress: F-003 Workspace boundary, F-006 optimistic locking, T-010/T-011 and T-017 through
  same-Workspace lookup and stale CAS cases.
- Regress DB backstop `INV-WS-001` only for Asset-to-Project Workspace consistency.
- Do not claim F-052 or T-INT-118..121 complete: immutable byte/derivative evidence needs later
  storage/proxy/waveform behavior.
- Do not claim F-056 or T-INT-130..132/T-MED-100..105: MediaProbe/timebase normalization is a
  separate later IMP-021 leaf.

Required tests include domain validation, duplicate storage identity, nullable Project,
same-Workspace Project link, cross-Workspace concealment, stale row-version conflict, AVAILABLE
identity immutability, rollback without implicit commit, fresh migration/reopen persistence and
no external/storage calls.

## Forbidden scope

- `migrations/**`, schema/manifest edits and runtime or production databases.
- Asset byte access, filesystem copy/move/delete, object storage, signed URLs and provider SDKs.
- FFmpeg/FFprobe, MediaProbe, proxy, waveform, analysis or render behavior.
- Content/ContentVersion, API/UI, publication, scheduler and worker implementation.
- Credential or secret-store access, network calls, external side effects and any path not listed
  in the successor envelope.

## Completion criteria

1. Parent is corrected to IMP-021 and dependency remains CCS-02-002.
2. Exact paths and F-004/T-013 ownership are bound in an immutable DRAFT successor before a
   separate ACTIVE attempt.
3. Unit/repository/integration tests prove every behavior above using only pytest temporary DBs.
4. Full pytest, Ruff, format check and mypy pass; existing Workspace/Project/session/security
   regressions remain green.
5. Implementation report records hashes, command results, no-migration proof and zero external
   effects.

## Current readiness

Ready for an immutable registry successor that repairs the parent and binds the envelope. Not
ready for implementation under r13 because the parent/traceability and path ownership are still
unresolved.

## Skills used

- none
