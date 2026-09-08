# CCS-02-004 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-004
Parent: IMP-022
Predecessor: CCS-02-003
Repository branch: master
Repository baseline: 2650c55a91ca22b817aa391a0aeefc5b80172d8d
Registry: vc01b-local-20260907-r15
Registry file SHA-256: fdc860cf70849c92252c25b4ca9437131e925205488be987ff6dfb457249ec79
Registry digest: 52bbf26225e2c5e6af52cf035af57facb846b8ac2b0ac6b93cca5ca5af5954a6
Specification package digest: 89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278

## Authority

The verified serial LD00 local authority activates one CCS-02-004 attempt against the exact r15
registry and master baseline above. It does not alter r15's immutable DRAFT state and grants no
authority outside the paths, ownership and local test process declared here.

## Exact create paths

1. `reports/IMP-022_CCS-02-004_IMPLEMENTATION.md`
2. `src/custom_content_studio/application/ports/content_repository.py`
3. `src/custom_content_studio/application/services/contents.py`
4. `src/custom_content_studio/domain/contents.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/contents.py`
6. `tests/integration/test_content_service.py`
7. `tests/repository/test_content_repository.py`
8. `tests/unit/test_content_model.py`

## Exact modify paths

1. `src/custom_content_studio/application/ports/__init__.py`
2. `src/custom_content_studio/application/services/__init__.py`
3. `src/custom_content_studio/bootstrap/composition.py`
4. `src/custom_content_studio/domain/__init__.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`

Any other implementation path is forbidden.

## Traceability, scope and verification

- Parent/package is IMP-022 and predecessor CCS-02-003 must remain accepted.
- Own only the Content aggregate and Workspace/Project-scoped CRUD subset of F-004.
- Own only the closed persisted-state vocabulary subset of F-005: `IDEA`, `ACTIVE`, `ARCHIVED`,
  with new Content initially `IDEA`; do not implement transition execution.
- Bind INV-WS-001 for Content-to-Project Workspace isolation.
- Introduce T-015; T-011, T-015, T-017 and T-INT-050 must pass. T-011, T-017 and the Content case
  of T-INT-050 are regressions.
- Keep `current_version_id` null; CCS-02-005 owns ContentVersion and linkage. CCS-02-006 owns state
  transition commands and invalid-transition decisions.
- Use one caller-owned SQLite unit of work and exact `row_version` CAS.
- Test databases may exist only below pytest `tmp_path`; test data must be synthetic and local.
- Permitted checks: targeted/full pytest, Ruff check/format-check, mypy and read-only Git
  diff/status.

## Absolute prohibitions

- No migration SQL, schema, manifest, replacement, backfill or migration execution.
- No runtime, DEV, STAGING or production database access or mutation.
- No ContentVersion, ReviewSession, approval/current-version mutation or version numbering.
- No state-transition implementation, derived workflow summary, render or publication state.
- No provider, network, credential, secret-store, media or external-system operation.
- No Asset change, API/UI work, worker, scheduler, deployment or publication.
- No dependency or lockfile change.

Stop with the r15 canonical code on digest drift, missing CCS-02-003 acceptance evidence,
migration need, unlisted path need, external effect or prerequisite failure. Do not repair another
leaf inside this attempt.
