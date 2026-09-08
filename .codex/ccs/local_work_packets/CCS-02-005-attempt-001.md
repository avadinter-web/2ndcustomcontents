# CCS-02-005 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-005
Parent: IMP-022
Predecessor: CCS-02-004
Repository branch: master
Repository baseline: b094cd590de0abb2b464cb5e74b1353c2101005f
Registry: vc01b-local-20260907-r16
Registry file SHA-256: 7fa3621fd8aeb72a627855eabd8ec288c76f012b14f5daa714e2e11d4b8547d4
Registry digest: 62bd1c4b91fc867786c51797fb983c057edaa3c48149fcc377d06df579160645
Specification package digest: cf7fbc99b83f3a258b5c6794df777c10fba4c945a5fffc76791d5bad951c5e1c
Change control: CHG-2026-0023

## Authority

The verified serial LD00 local authority activates one CCS-02-005 attempt against the exact r16
registry and master baseline above. It does not alter r16's immutable DRAFT state and grants no
authority outside the paths, ownership and local test process declared here.

## Exact create paths

1. `reports/IMP-022_CCS-02-005_IMPLEMENTATION.md`
2. `src/custom_content_studio/application/ports/content_version_repository.py`
3. `src/custom_content_studio/application/services/content_versions.py`
4. `src/custom_content_studio/domain/content_versions.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/content_versions.py`
6. `tests/integration/test_content_version_service.py`
7. `tests/repository/test_content_version_repository.py`
8. `tests/unit/test_content_version_model.py`

## Exact modify paths

1. `src/custom_content_studio/application/ports/__init__.py`
2. `src/custom_content_studio/application/services/__init__.py`
3. `src/custom_content_studio/bootstrap/composition.py`
4. `src/custom_content_studio/domain/__init__.py`
5. `src/custom_content_studio/domain/contents.py`
6. `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
7. `src/custom_content_studio/infrastructure/sqlite/repositories/contents.py`
8. `tests/repository/test_content_repository.py`
9. `tests/unit/test_content_model.py`

Any other implementation path is forbidden.

## Traceability, scope and verification

- Parent/package is IMP-022 and predecessor CCS-02-004 must remain accepted.
- Implement the F-004/F-005 ContentVersion subset defined by CHG-2026-0023 and the registered
  `ccs.content-version-snapshot` v1 schema.
- Validate and canonicalize normalized JSON snapshots; compute `snapshot_hash` over the canonical
  snapshot plus Content ID and version number.
- Permit creation only for an authenticated USER actor. ServiceAccount and null-creator creation
  are excluded.
- Create only DRAFT versions with first/null or exact current-head parent linkage and monotonic
  per-Content numbering.
- Insert the version and advance `current_version_id` in one caller-owned `BEGIN IMMEDIATE`
  transaction using exact Content `row_version` and exact prior-head CAS; increment row_version
  once or roll back the entire operation.
- Preserve every prior version, reject version deletion and enforce Workspace-scoped reads under
  INV-IMM-001 and INV-WS-001.
- Introduce T-014 and T-INT-031. T-011, T-014, T-017 and T-INT-031 must pass; T-011, T-017 and
  T-INT-031 are regressions.
- Test databases may exist only below pytest `tmp_path`; test data must be synthetic and local.
- Permitted checks: targeted/full pytest, Ruff check/format-check, mypy and read-only Git
  diff/status.

## Absolute prohibitions

- No migration SQL, schema, manifest, replacement, trigger, backfill or migration execution.
- No runtime, DEV, STAGING or production database access or mutation.
- No ServiceAccount version creation or null creator projection.
- No approval lineage/status transitions, ReviewSession, TimelineApproval, edit-as-new-revision,
  restore or branching behavior.
- No ContentVersion or Content status-transition command owned by CCS-02-006.
- No provider, network, credential, secret-store, media or external-system operation.
- No Asset generation, timeline, render, publication, analytics, API/UI, worker, scheduler,
  deployment or publication.
- No dependency or lockfile change and no path outside the exact allowlist.

Stop with the r16 canonical code on digest drift, missing CCS-02-004 acceptance evidence,
migration need, unlisted path need, external effect or prerequisite failure. Do not repair another
leaf inside this attempt.
