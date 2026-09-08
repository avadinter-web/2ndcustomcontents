# CCS-02-002 Local Work Packet — Attempt 001

Status: `ACTIVE / BOUNDED LOCAL IMPLEMENTATION`
Authority profile: `LD00_DIRECT_USER_AUTHORIZATION / SERIAL LOCAL LEAF`
User decision locator: active Codex conversation, `개정하고 진행해` and subsequent continuous-delivery directions
Baseline commit: `565eb8ff8ad3bf46165df53535cdfa870dc7a299`
Canonical parent: `IMP-020`
Canonical leaf: `CCS-02-002`
Registry source: `vc01b-local-20260907-r13`
Registry file SHA-256: `437e2e138299f0af078937da085f5b08ad32b513dd1beecb76ca88519da7a4a5`

Implement the Project domain model and SQLite repository over the existing frozen `projects` table.
Use temporary SQLite databases only.

## Exact mutation allowlist

Control records:

- `.codex/ccs/local_work_packets/CCS-02-002-attempt-001.md`
- `.codex/ccs/local_decisions/LD00-CCS-02-002-attempt-001.md`

Create:

- `reports/IMP-020_CCS-02-002_IMPLEMENTATION.md`
- `src/custom_content_studio/application/ports/project_repository.py`
- `src/custom_content_studio/domain/projects.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/projects.py`
- `tests/repository/test_project_repository.py`
- `tests/unit/test_project_model.py`

Modify:

- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/domain/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`

All other paths are read-only.

## Required behavior

- immutable Project identity; valid owning Workspace ID; trimmed name; nullable description/content type/brand reference;
- default language and default-platform JSON array validation; ACTIVE, PAUSED and ARCHIVED status only;
- caller-owned-transaction create, scoped get/list, CAS update and archive; archived Projects cannot mutate;
- Project operations are scoped to Workspace, conceal cross-Workspace records, and never commit implicitly;
- typed duplicate, missing, stale and archived failures without partial writes.

## Forbidden

- schema or migration changes; Workspace, User/membership, Asset, Content or UI/API work;
- external/provider/network/media/deployment/publication work; credentials, runtime/production DB access;
- dependency/lockfile changes or unlisted paths.

## Verification

- new unit/repository tests, full pytest, Ruff, format check, mypy, Git whitespace and path checks.
