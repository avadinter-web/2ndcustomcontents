# CCS-02-004 Content Model Discovery

Status: DISCOVERY COMPLETE / IMMUTABLE SUCCESSOR REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository commit inspected: 2650c55a91ca22b817aa391a0aeefc5b80172d8d
Registry inspected: vc01b-local-20260907-r14
Canonical task: CCS-02-004 — Content model

## Decision

CCS-02-004 belongs to **IMP-022**, not IMP-023. IMP-022 is the canonical “Content,
ContentVersion and independent state services” package. IMP-023 is the fenced worker kernel and
even points to `CCS-09_TASKS.md`; the current r14 parent is therefore a normative traceability
conflict. A new immutable successor must correct the parent while retaining dependency
`CCS-02-003` before implementation dispatch.

This leaf owns the Content aggregate model, persistence and Workspace/Project-scoped CRUD only.
It owns the closed Content status vocabulary and initial state but **not** transition execution.
CCS-02-006 separately owns the `IDEA -> ACTIVE -> ARCHIVED` transition service and invalid
transition decisions. CCS-02-005 owns ContentVersion identity/history and `current_version_id`
linkage. CCS-02-010 owns HTTP/UI resources.

## Existing schema and migration decision

`migrations/0001_initial_v2_2.sql` already defines `contents` with Workspace/Project FKs, closed
content-type and status checks, nullable platform/goal/current-version fields, archive timestamp,
row-version, Project/status and Workspace/update indexes, same-Workspace Project triggers,
current-version ownership triggers and immutable Workspace identity. Its manifest-bound SHA-256 is
`2b532c6fbe5b45261f2cd815b6de4947d0a056b32754165fd06c1e9c12a2980f`.

**Migration decision: NONE.** CCS-02-004 consumes and tests that existing schema. SQL/manifest
edits, replacement, backfill or a new migration are forbidden. Any schema deficiency stops with
`MIGRATION_DECISION_REQUIRED` and requires separate change control.

## Exact implementation envelope proposed for the successor

Create:

- `src/custom_content_studio/domain/contents.py`
- `src/custom_content_studio/application/ports/content_repository.py`
- `src/custom_content_studio/application/services/contents.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/contents.py`
- `tests/unit/test_content_model.py`
- `tests/repository/test_content_repository.py`
- `tests/integration/test_content_service.py`
- `reports/IMP-022_CCS-02-004_IMPLEMENTATION.md`

Modify only for exports and local composition:

- `src/custom_content_studio/domain/__init__.py`
- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/application/services/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
- `src/custom_content_studio/bootstrap/composition.py`

## Owned behavior

- Immutable `ContentType` and `ContentStatus` enums matching SQLite exactly. Content status accepts
  only `IDEA`, `ACTIVE`, `ARCHIVED`; render, review and publication states are rejected.
- Content value model validates trimmed IDs/title, optional trimmed primary platform/goal,
  timezone-aware UTC timestamps, archive/status agreement and positive row version.
- New Content begins `IDEA`, `current_version_id=None`, `archived_at=None`, `row_version=1`.
- Repository create/get/list/update is always scoped by `(workspace_id, content_id)` and Project is
  resolved by `(workspace_id, project_id)`. Foreign and missing targets share a non-revealing
  result/error.
- Mutable descriptive fields use exact row-version CAS and increment once. Workspace identity and
  initial aggregate identity do not move.
- Service writes require an owning-Workspace ActorContext with `CONTENT_EDIT` and use one
  caller-owned SQLite unit of work. Repositories never commit independently.
- `current_version_id` remains null and is not modified in this leaf; CCS-02-005 owns that linkage.
- Status transition and archive commands are not exposed in this leaf; CCS-02-006 owns them.

## Feature, invariant and test ownership

- Own now: the Content subset of F-004; the closed-state-model subset of F-005; introduce T-015
  proving Content does not contain render/publish states.
- Regress: F-003 Workspace authorization and F-006 optimistic locking through T-011 and T-017.
- Bind the Content-to-Project subset of INV-WS-001 and execute the Content case of T-INT-050.
- Do not claim T-012: it names Workspace/Project persistence and belongs the prior core leaves.
- Do not claim T-014 or F-041/INV-APR-001: ContentVersion lineage is CCS-02-005.
- Do not claim T-016: invalid transition ownership is CCS-02-006.

Required local evidence covers domain validation, initial IDEA state, exclusion of workflow
summary states, same-Workspace Project enforcement, concealed cross-Workspace lookup, CAS stale
writer rejection, rollback without implicit commit, fresh-schema persistence/reopen and absence of
runtime/external database use.

## Forbidden scope

- ContentVersion, ReviewSession, approval/current-version mutation and version numbering.
- State-transition implementation, derived workflow summary, render or publication state.
- Asset changes, API/UI handlers, worker, scheduler, provider and media behavior.
- Migration/schema/manifest edits, runtime or production databases.
- Credentials, secret stores, network calls, dependency/lock changes and external effects.
- Any path outside the exact successor allowlist.

## Completion criteria

1. An immutable successor corrects parent to IMP-022, preserves dependency CCS-02-003 and binds
   the exact 8-create/5-modify envelope above.
2. The successor records F-004/F-005 subset ownership, T-015 introduction and T-011/T-017 plus
   INV-WS-001/T-INT-050 regression without stealing CCS-02-005/006 ownership.
3. A separately authorized ACTIVE attempt implements only the declared model/repository/service
   boundary using pytest temporary SQLite databases.
4. Targeted and full pytest, Ruff, format check and mypy pass; Workspace/Project/Asset/security
   regressions remain green.
5. The implementation report proves no migration, runtime DB, credential, provider, network,
   media, API/UI, deployment or publication action occurred.

## Current readiness

Ready for an immutable successor that repairs the parent and resolves exact ownership. Not ready
for implementation under r14.

## Skills used

- none
