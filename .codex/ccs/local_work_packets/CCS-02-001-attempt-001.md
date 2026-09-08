# CCS-02-001 Local Work Packet — Attempt 001

Status: `ACTIVE / BOUNDED LOCAL IMPLEMENTATION`
Authority profile: `LD00_DIRECT_USER_AUTHORIZATION / SERIAL LOCAL LEAF`
User decision locator: active Codex conversation, user message `개정하고 진행해`
Baseline commit: `1568a3e9b19ffcc8ba30a3c0f22229b1c36a947c`
Canonical parent: `IMP-020`
Canonical leaf: `CCS-02-001`
Registry source: `vc01b-local-20260907-r13`
Registry file SHA-256: `437e2e138299f0af078937da085f5b08ad32b513dd1beecb76ca88519da7a4a5`

Implement the first IMP-020 slice only: the local Workspace model and SQLite repository over the
already-frozen `workspaces` table. Use temporary SQLite databases only. This packet is the first
eligible leaf in the frozen CCS-02 design order after the completed CCS-01 foundation.

## Exact mutation allowlist

Control records:

- `.codex/ccs/local_work_packets/CCS-02-001-attempt-001.md`
- `.codex/ccs/local_decisions/LD00-CCS-02-001-attempt-001.md`

Create:

- `reports/IMP-020_CCS-02-001_IMPLEMENTATION.md`
- `src/custom_content_studio/application/ports/workspace_repository.py`
- `src/custom_content_studio/domain/workspaces.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/workspaces.py`
- `tests/repository/test_workspace_repository.py`
- `tests/unit/test_workspace_model.py`

Modify:

- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/domain/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`

All other paths are read-only.

## Required behavior

- immutable identity, nonblank name, IANA timezone and JSON-object settings validation;
- deterministic UTC timestamps and `row_version` optimistic compare-and-swap update;
- create, get-by-id, list-active, update and archive operations; archived records are excluded
  from active listing and cannot be updated;
- repository calls use the caller-owned SQLite transaction and never commit implicitly;
- duplicate ID and stale/missing update fail with typed errors without partial writes.

## Forbidden

- schema or migration changes; User or membership CRUD; Project/Asset/Content work;
- API, UI, worker, scheduler, provider, network, media, deployment or publication work;
- credentials, OS secret access, runtime or production database access;
- dependency or lockfile changes; any path not listed above.

## Verification

- new unit and repository tests plus existing persistence regression tests;
- full pytest, Ruff check/format check, mypy strict;
- Git whitespace and exact path-scope checks.

Stop on a frozen-registry digest drift, prerequisite evidence failure, schema/migration need,
unlisted write, external effect, credential requirement or runtime database access.
