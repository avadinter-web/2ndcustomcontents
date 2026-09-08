# CCS-02-003 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-08
Leaf: CCS-02-003
Parent: IMP-021
Predecessor: CCS-02-002
Repository baseline: 6fc416aecdc814117eb916e87f46a728d089c8a9
Registry: vc01b-local-20260907-r14
Registry file SHA-256: 9c63a5c9a6a4d0941bcf8aa9d0cb2dcf9acfede0fdf5c8356449e4f64ee51a15
Registry digest: 7a6bd34d414ff31db8d815726ac91cd2817cd65f92b84f268b08c4dfc9a38a9b
Specification package digest: 89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278

## Authority

The verified serial LD00 local authority activates one CCS-02-003 attempt against the exact r14
registry and baseline above. It does not alter r14's immutable DRAFT state and grants no authority
outside the paths and local test process declared here.

## Exact create paths

1. `reports/IMP-021_CCS-02-003_IMPLEMENTATION.md`
2. `src/custom_content_studio/application/ports/asset_repository.py`
3. `src/custom_content_studio/application/services/assets.py`
4. `src/custom_content_studio/domain/assets.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/assets.py`
6. `tests/integration/test_asset_service.py`
7. `tests/repository/test_asset_repository.py`
8. `tests/unit/test_asset_model.py`

## Exact modify paths

1. `src/custom_content_studio/application/ports/__init__.py`
2. `src/custom_content_studio/application/services/__init__.py`
3. `src/custom_content_studio/bootstrap/composition.py`
4. `src/custom_content_studio/domain/__init__.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`

Any other implementation path is forbidden.

## Scope and verification

- Implement only the F-004 Asset metadata-registry subset and INV-WS-001 Asset/Project boundary.
- Introduce T-013; regress T-010, T-011 and T-017 for F-003/F-006 behavior.
- Use one caller-owned SQLite unit of work and exact `row_version` CAS.
- Test databases may exist only below pytest `tmp_path`.
- Permitted checks: targeted/full pytest, Ruff check/format-check, mypy and read-only Git diff/status.

## Absolute prohibitions

- No migration SQL, manifest, schema replacement or backfill.
- No runtime, DEV, STAGING or production database access.
- No provider, network, credential, secret-store, storage, upload/download or filesystem Asset-byte
  operation.
- No FFmpeg/FFprobe or media processing.
- No API, UI, deployment, publication or external-system mutation.
- No dependency or lockfile change.

Stop with the r14 canonical code on digest drift, missing predecessor evidence, migration need,
unlisted path need, external effect or prerequisite failure. Do not repair another leaf inside this
attempt.
