# CCS-02-006 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-006
Parent: IMP-022
Predecessor: CCS-02-005
Repository branch: master
Repository baseline: b1511c5c879f2b0a618b7203a3930ee3068460ab
Registry: vc01b-local-20260907-r17
Registry file SHA-256: a05c4c159dd121d01885823a6c8eeffa53a21c1695e40e02b2805f4f618d070b
Registry digest: 01d91d3b8a5833fb8523c34bec57d426b5fa9b390c029bbea26ef86a27be3bfd
Specification package digest: f1083df87ea9bf50fe4c19c60363e7a0e1a5fd2aa7cb562ec84ecdecc88ddd54
Change control: CHG-2026-0024

## Authority

The verified serial LD00 local authority activates one CCS-02-006 attempt against the exact r17
registry and master baseline above. It does not alter r17's immutable DRAFT state and grants no
authority outside the paths and local test process declared here.

## Exact create paths

1. `reports/IMP-022_CCS-02-006_IMPLEMENTATION.md`
2. `src/custom_content_studio/domain/content_state_transitions.py`
3. `src/custom_content_studio/application/ports/content_state_transition_repository.py`
4. `src/custom_content_studio/application/services/content_state_transitions.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/content_state_transitions.py`
6. `tests/unit/test_content_state_transition_policy.py`
7. `tests/repository/test_content_state_transition_repository.py`
8. `tests/integration/test_content_state_transition_service.py`

## Exact modify paths

1. `src/custom_content_studio/domain/__init__.py`
2. `src/custom_content_studio/application/ports/__init__.py`
3. `src/custom_content_studio/application/services/__init__.py`
4. `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
5. `src/custom_content_studio/bootstrap/composition.py`

Any other implementation path is forbidden.

## Exact scope and verification

- Implement only `ActivateContent` (Content `IDEA -> ACTIVE`), `ArchiveContent`
  (Content `ACTIVE -> ARCHIVED`) and `SubmitContentVersionForReview`
  (ContentVersion `DRAFT -> REVIEW_REQUIRED`).
- Require authenticated USER `CONTENT_EDIT`, owning-Workspace scope, exact source-state and
  row-version CAS, and one caller-owned `BEGIN IMMEDIATE` unit of work.
- Reject all reverse, skipped, self and unlisted edges with `INVALID_STATE_TRANSITION`.
- Activate requires the exact current DRAFT authoring head. Archive atomically records matching
  updated/archive timestamps. Submit-review preserves snapshot, hash, parent, creator and approval
  fields.
- Own F-005/T-016; regress T-011, T-014, T-015, T-017, T-INT-031 and T-INT-050 under
  INV-IMM-001 and INV-WS-001.
- Test databases may exist only below pytest `tmp_path`; test data must be synthetic and local.

## Absolute prohibitions

- No CCS-07 approval, revision, rejection or APPROVED-to-SUPERSEDED lineage.
- No ReviewSession, TimelineApproval, approved_at, approved_by, approval selection, restore or
  edit-as-new-revision work.
- No migration SQL, schema, manifest, trigger or backfill change.
- No runtime/production database, API/UI, derived workflow summary, credential, secret, provider,
  network, media, dependency, deployment, publication or external operation.

Stop on registry/spec drift, missing CCS-02-005 acceptance, migration need, an unlisted path or any
external/approval-lineage requirement. This attempt does not authorize scope expansion.
