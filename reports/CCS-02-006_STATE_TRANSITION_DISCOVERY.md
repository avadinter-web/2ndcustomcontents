# CCS-02-006 State Transition Service Discovery

Status: DISCOVERY COMPLETE / CONTRACT CHANGE REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository baseline: `b1511c5c879f2b0a618b7203a3930ee3068460ab`
Current registry: `vc01b-local-20260907-r16`

## 1. Parent and dependency resolution

CCS-02-006 belongs to **IMP-022**, whose normative title is “Content, ContentVersion and
independent state services.” The r16 placeholder parent `IMP-021` is incorrect because IMP-021 is
the Asset identity/storage/media-probe package. The immediate dependency remains
**CCS-02-005**; CCS-02-004 is already a transitive prerequisite through CCS-02-005.

The current master baseline contains the accepted Content core (`b094cd5`) and ContentVersion core
(`b1511c5`). No transition command is present yet.

## 2. Normative state boundary discovered

The existing specifications establish these graphs:

- Content: `IDEA -> ACTIVE -> ARCHIVED`.
- ContentVersion authoring handoff: `DRAFT -> REVIEW_REQUIRED`.
- Review-owned ContentVersion results: `REVIEW_REQUIRED -> APPROVED` or
  `REVIEW_REQUIRED -> REVISION_REQUIRED`; an approved predecessor may later become
  `SUPERSEDED` as part of approval lineage.

The smallest non-overlapping CCS-02-006 implementation should therefore own only:

1. `ActivateContent`: Content `IDEA -> ACTIVE`.
2. `ArchiveContent`: Content `ACTIVE -> ARCHIVED`.
3. `SubmitContentVersionForReview`: ContentVersion `DRAFT -> REVIEW_REQUIRED`.
4. Rejection of every other source/target pair through `INVALID_STATE_TRANSITION`.
5. Workspace-scoped authorization and a CAS containing exact row version and exact source state.

Approval, revision-request, rejection and supersession execution must remain with CCS-07 review
and approval-lineage services. CCS-02-006 must not write `approved_at` or `approved_by`, select an
approved version, create a ReviewSession/TimelineApproval, or infer a derived workflow summary.

## 3. Contract gap

Implementation is not yet safe from the present prose alone. The package does not normatively
bind all of the following:

- whether `IDEA -> ACTIVE` requires a non-null current ContentVersion head and, if so, which
  version status is acceptable;
- the exact actor rule for the three commands (recommended: authenticated USER with
  `CONTENT_EDIT`; ServiceAccount transition authority must be explicitly included or excluded);
- command field names, timestamp monotonicity and stable return representation;
- the CCS-02-006/CCS-07 split for ContentVersion transitions;
- atomic companion writes for archive timestamps and ContentVersion review submission;
- exact ownership of T-015 versus T-016 after CCS-02-004 already used T-015 for the closed Content
  state vocabulary.

Although `APPLICATION_SERVICE_CONTRACTS.md` supplies the general rule—one target, an explicit
source set, source-state plus row-version CAS, and `INVALID_STATE_TRANSITION`—it does not close
these resource-specific decisions. Choosing them in code would be an unauthorized design choice.

## 4. Required change control

A minimal normative change-control record is required before an immutable successor can resolve
this leaf. It should bind:

- the three commands and graphs in section 2;
- `CONTENT_EDIT`, actor type, Workspace concealment and stable error mapping;
- `expected_row_version`, expected source state, `transitioned_at_utc`, and the exact transition
  result;
- `ActivateContent` preconditions;
- `ArchiveContent` setting `status=ARCHIVED`, `updated_at=archived_at=transitioned_at_utc`, and
  incrementing row_version once;
- `SubmitContentVersionForReview` changing only status and row_version, preserving every snapshot,
  hash, parent, creator and approval field;
- CCS-07 exclusive ownership of review-decision/approval/supersession transitions;
- transaction rollback and the errors `WORKSPACE_ACCESS_DENIED`, `VERSION_CONFLICT`,
  `INVALID_STATE_TRANSITION`, and `DOMAIN_VALIDATION_FAILED`.

Recommended specification files are:

1. `09_SHARED_SPEC/STATE_MACHINES.md`
2. `09_SHARED_SPEC/APPLICATION_SERVICE_CONTRACTS.md`
3. `09_SHARED_SPEC/TRANSACTION_AND_CONCURRENCY.md`
4. `09_SHARED_SPEC/API_CONTRACTS.md`
5. `01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md`
6. `11_CODEX_TASKS/CCS-02_TASKS.md`
7. `FEATURE_REGISTRY.json`
8. `TEST_CATALOG.json`
9. `IMPLEMENTATION_REGISTRY.json`
10. `12_CHANGE_CONTROL/TRACEABILITY_MATRIX.md`
11. `12_CHANGE_CONTROL/DECISIONS.md`
12. `12_CHANGE_CONTROL/CHANGELOG.md`
13. `PACKAGE_INDEX.json`

The package index and strict synchronization must be regenerated after the change.

## 5. Candidate exact implementation envelope

After the change-control record is accepted, an immutable r17 successor should correct the parent
to IMP-022, retain dependency CCS-02-005, bind the new package digest and authorize only this
candidate path envelope.

### Create paths (8)

1. `reports/IMP-022_CCS-02-006_IMPLEMENTATION.md`
2. `src/custom_content_studio/domain/content_state_transitions.py`
3. `src/custom_content_studio/application/ports/content_state_transition_repository.py`
4. `src/custom_content_studio/application/services/content_state_transitions.py`
5. `src/custom_content_studio/infrastructure/sqlite/repositories/content_state_transitions.py`
6. `tests/unit/test_content_state_transition_policy.py`
7. `tests/repository/test_content_state_transition_repository.py`
8. `tests/integration/test_content_state_transition_service.py`

### Modify paths (5)

1. `src/custom_content_studio/domain/__init__.py`
2. `src/custom_content_studio/application/ports/__init__.py`
3. `src/custom_content_studio/application/services/__init__.py`
4. `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
5. `src/custom_content_studio/bootstrap/composition.py`

The dedicated transition port/adapter keeps transition SQL out of the existing descriptive CRUD
and append-only version repositories. No existing Content or ContentVersion source file needs to
be modified for the discovered boundary.

## 6. Ownership and verification

- Primary feature: **F-005** independent state machines.
- Supporting enforcement/regression: **F-003** Workspace authorization and **F-006** optimistic
  locking; no new ownership claim over their broader feature scope.
- Introduced test: **T-016**, narrowed to the three CCS-02-006 commands and their invalid edges.
- Required regressions: **T-011**, **T-014**, **T-015**, **T-017**, **T-INT-031** and the Content
  case of **T-INT-050**.
- Invariants: **INV-WS-001** for scoped reads/writes and **INV-IMM-001** for preservation of the
  ContentVersion snapshot/history during review submission.
- Explicitly excluded: **F-041** and **INV-APR-001**, which belong to review/approval lineage.

Completion evidence must prove all valid edges, every reverse/skip/self edge denial, stale CAS,
wrong-Workspace concealment, rollback, monotonic timestamps, archive timestamp projection,
ContentVersion snapshot/hash/parent preservation, caller-owned transaction behavior, and no
external effect.

## 7. Migration and forbidden areas

No migration is required for this scope. The frozen SQLite schema already contains the complete
Content/ContentVersion status vocabularies, row versions, Content timestamps and approval fields.
Repository transition updates can predicate on Workspace, ID, row version and exact source state.

If implementation requires a new column, trigger, table, backfill or change to
`migrations/0001_initial_v2_2.sql`, it must stop with `MIGRATION_DECISION_REQUIRED`; migration is
not part of CCS-02-006.

Also forbidden are approval/review/timeline writes, derived workflow summaries, API/UI work,
runtime or production databases, credentials/secrets, provider/network/media operations,
dependencies/lockfiles, deployment, publication and every external side effect.

## 8. Resolution decision

**Both artifacts are required:** first a normative change-control record closing section 3, then
an immutable r17 successor resolving the CCS-02-006 task envelope. r16 must remain unchanged and
no ACTIVE work packet should be issued until both are validated.
