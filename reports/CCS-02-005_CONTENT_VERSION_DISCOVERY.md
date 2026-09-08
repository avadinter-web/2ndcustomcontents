# CCS-02-005 ContentVersion Discovery

Status: DISCOVERY COMPLETE / SPEC CHANGE CONTROL REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository branch: master
Repository commit inspected: b094cd590de0abb2b464cb5e74b1353c2101005f
Registry inspected: vc01b-local-20260907-r15
Canonical task: CCS-02-005 — ContentVersion append-only versions and parent linkage

## Decision

CCS-02-005 belongs to **IMP-022**, not IMP-020. IMP-022 is the canonical “Content,
ContentVersion and independent state services” package and explicitly delivers version lineage. The r15
placeholder parent IMP-020 is the Workspace/Project/membership package and is a normative
traceability conflict. Dependency `CCS-02-004` is correct and must be retained.

The product-code boundary is discoverable, but implementation is not yet safe. The specification
does not freeze three values that affect persisted identity and approval evidence:

1. `content_snapshot_json` and `script_snapshot_json` are named critical persisted JSON families,
   but neither has a registered schema/name/version in
   `13_IMPLEMENTATION_CONTRACTS/SCHEMA_REGISTRY.json`.
2. `snapshot_hash` exists in SQLite and is used by ReviewSession/approval lineage, but the exact
   hash input is not stated. It is unclear whether it hashes only `content_snapshot_json` or a
   canonical envelope containing title, script and content snapshots.
3. `contents.current_version_id` is not defined as latest-created version, authoring head, latest
   approved version or another projection. The atomic compare-and-swap rule for advancing it is
   therefore also unspecified.

Choosing any of these values in product code would invent durable and approval-critical semantics.
An approved specification change must resolve them before an immutable successor may mark this
leaf `RESOLVED` or an ACTIVE attempt may be issued.

## Existing implementation integration boundary

CCS-02-004 is present at the inspected commit. It deliberately treats version linkage as outside
its scope:

- `domain/contents.py` types `current_version_id` as `None` and rejects a non-null value;
- the SQLite Content mapper rejects any row whose pointer is non-null;
- Content creation persists an unversioned `IDEA` row;
- the Content repository update rejects a row after version linkage rather than mutating the pointer.

CCS-02-005 must minimally widen the Content read model to a validated `str | None` pointer and make
the SQLite mapper load linked Content. Pointer mutation must remain absent from `ContentService`.
The new ContentVersion repository/service must insert a version and advance the owning Content
pointer within one caller-owned SQLite transaction after Workspace authorization and exact Content
row-version validation. Direct Content metadata update behavior after linkage remains unchanged
unless the specification separately changes that contract.

## Provisional exact implementation paths

These paths become eligible only after the specification gaps above are resolved and bound by an
immutable successor.

Create:

- `src/custom_content_studio/domain/content_versions.py`
- `src/custom_content_studio/application/ports/content_version_repository.py`
- `src/custom_content_studio/application/services/content_versions.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/content_versions.py`
- `tests/unit/test_content_version_model.py`
- `tests/repository/test_content_version_repository.py`
- `tests/integration/test_content_version_service.py`
- `reports/IMP-022_CCS-02-005_IMPLEMENTATION.md`

Modify only for linkage compatibility, exports, composition and regression:

- `src/custom_content_studio/domain/contents.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/contents.py`
- `src/custom_content_studio/domain/__init__.py`
- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/application/services/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
- `src/custom_content_studio/bootstrap/composition.py`
- `tests/unit/test_content_model.py`
- `tests/repository/test_content_repository.py`

`ContentRepositoryPort` and `ContentService` are not provisional modify paths. The atomic
ContentVersion insert/head-advance operation belongs to `ContentVersionRepositoryPort`; this keeps
the existing Content core from acquiring version-authoring commands.

## Domain and persistence semantics that are already normative

- A ContentVersion is identified by `id` and belongs immutably to one Content.
- `version_number` is positive and unique within a Content; history is never deleted.
- `parent_version_id`, when present, must identify a version of the same Content and cannot be
  re-parented. The first version has no parent; a successor preserves the prior row.
- Every inserted version starts `DRAFT`, with null approval actor/time.
- Persisted statuses are exactly `DRAFT`, `REVIEW_REQUIRED`, `REVISION_REQUIRED`, `APPROVED` and
  `SUPERSEDED`.
- Version payload fields are title snapshot, optional script snapshot JSON, required content
  snapshot JSON and `snapshot_hash`; timestamps are timezone-aware UTC and `row_version` is
  positive.
- The service uses an owning-Workspace `ActorContext` with `CONTENT_EDIT`. Cross-Workspace and
  missing Content are indistinguishable to callers.
- Insertion plus Content pointer advance is atomic, uses the expected Content row version and never
  commits inside a repository. Concurrent creators cannot both advance the same head.
- The repository supports Workspace-scoped get/list through `content_versions JOIN contents`; it
  never exposes a version by global ID alone.
- Draft payload replacement, if retained after change control, uses exact version-row CAS and
  recomputes the frozen canonical snapshot hash. Approved or superseded payload is never changed.

Version numbering should be monotonic per Content, and a new row should link to the exact prior
head. These are the only readings consistent with append-only history and parent linkage, but the
change control must explicitly couple this rule to the selected `current_version_id` meaning before
implementation.

## Approval and current-version ownership split

CCS-02-005 owns only the data model, DRAFT creation/read/list, parent/version preservation,
Workspace scoping, head-link transaction and database-backed immutability surface.

It does **not** own:

- `DRAFT → REVIEW_REQUIRED → APPROVED/REVISION_REQUIRED/SUPERSEDED` transition commands;
  CCS-02-006 owns generic state-transition validation;
- ReviewSession decisions, TimelineApproval, approval actor policy, exact review-target validation,
  edit-as-new-revision/carry-forward or superseding an approved version; those belong to CCS-07 and
  IMP-071;
- selecting a publishable version or substituting an approval/current version; publishing always
  binds the exact version and belongs to CCS-08.

The existing database already rejects non-DRAFT insertion, deletion, backward approved-state
movement, approved/superseded payload mutation, cross-Content parents, multiple APPROVED versions,
non-member creators/approvers and approval without matching review/timeline evidence. CCS-02-005
must not duplicate or weaken these backstops. It may expose status values as a read model but must
not expose approval/transition methods.

## Feature, test and invariant ownership

- Primary ownership: ContentVersion subset of **F-004** and **T-014**
  (`ContentVersion unique/version preservation`).
- Structural subset only: **F-005** for the closed ContentVersion status vocabulary and initial
  DRAFT state. **T-016** remains CCS-02-006 because it tests transition decisions.
- Regression: **F-003/T-011** for concealed cross-Workspace version lookup and **F-006/T-017** for
  Content-head and draft-row optimistic conflicts.
- Immutable-history ownership: ContentVersion delete-preservation subset of **INV-IMM-001** and
  **T-INT-031**. The approved-payload case **T-INT-030** remains a required later regression once
  the review/approval fixture exists; this leaf must not fabricate an approval path to claim it.
- Do not claim **F-041**, **INV-APR-001**, T-INT-080, T-INT-081, T-INT-082, T-INT-108 or
  T-INT-109. Those are review-to-ContentVersion and video-timeline approval lineage owned by
  CCS-07/IMP-071.
- `INV-WS-001` remains a required service/repository constraint. Its catalogued T-INT-050 names
  Project/Asset/Content, so CCS-02-005 regresses T-011 rather than relabeling T-INT-050.

## Existing schema and migration decision

`migrations/0001_initial_v2_2.sql` already contains the complete `content_versions` table,
same-Content parent composite FK, unique `(content_id, version_number)`, one-APPROVED partial unique
index, Content current-version ownership trigger, start-DRAFT trigger, membership/approval lineage
triggers and immutable history/payload/status guards. Its SHA-256 is
`2b532c6fbe5b45241f2cd815b6de4947d0a056b32754165fd06c1e9c12a2980f`.

**Migration decision: NONE.** Product implementation consumes this schema. Migration SQL,
manifest, table replacement, trigger changes and backfill are forbidden. The required change is a
specification-contract clarification/schema registration, not a database migration. Any discovered
need to change SQLite stops with `MIGRATION_DECISION_REQUIRED` and separate change control.

## Required specification change control

At minimum, the approved change must update and re-index:

- `09_SHARED_SPEC/JSON_PAYLOAD_CONTRACTS.md` — exact Content/script snapshot envelopes and the full
  `snapshot_hash` scope;
- `09_SHARED_SPEC/DATA_MODEL.md` — authoritative `current_version_id` meaning and parent/head rule;
- `09_SHARED_SPEC/TRANSACTION_AND_CONCURRENCY.md` — atomic version allocation/head CAS behavior;
- `13_IMPLEMENTATION_CONTRACTS/SCHEMA_REGISTRY.json` plus versioned schema files for every required
  snapshot family;
- related feature/test/invariant traceability and package index/digests.

The change must also decide whether ContentVersion creation is restricted to `ActorType.USER` or
how service-account authorship is represented. SQLite `created_by` references `users(id)` while
`ActorContext` can represent a service account; silently writing null would discard provenance.

## Forbidden implementation scope

- Any product implementation before the specification change and immutable successor.
- ContentVersion approval, ReviewSession, TimelineApproval, revision carry-forward or review UI/API.
- Content/ContentVersion state-transition service behavior owned by CCS-02-006.
- Timeline, render, publication, analytics, generation or Asset behavior.
- Migration/schema/manifest edits, runtime or production database access.
- Credentials, secret stores, provider/network/media calls, dependency changes or external effects.
- Any file outside the eventual successor allowlist.

## Completion criteria for a future authorized implementation

1. Approved spec change freezes schemas, canonical hash scope, head meaning/CAS and author identity.
2. An immutable successor corrects parent to IMP-022, retains dependency CCS-02-004 and binds the
   exact post-change-control allowlist and traceability.
3. First and successor versions persist with monotonic numbers, exact same-Content parent linkage,
   preserved old rows and an atomically advanced Content head.
4. Linked Content remains readable; cross-Workspace reads are concealed; stale head/draft writers
   roll back without partial rows or implicit commits.
5. Non-DRAFT insert and delete are blocked; approval and transition commands remain absent.
6. Fresh-schema persistence/reopen, targeted/full pytest, Ruff, format check and mypy pass without
   migration, runtime DB, credential, network or external activity.

## Current readiness

Not ready for an immutable resolved successor or implementation. The next safe action is
specification change control for the four durable identity questions above, followed by refreshed
package digests and a new discovery binding.

## Skills used

- none
