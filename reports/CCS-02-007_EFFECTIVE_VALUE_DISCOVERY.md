# CCS-02-007 Effective Value Utility Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR AND NARROW CHANGE CONTROL REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository baseline: `40c584c` (CCS-02-006 accepted local implementation)
Registry inspected: `vc01b-local-20260907-r17`
Canonical task: CCS-02-007 — Effective value utility

## 1. Parent and dependency resolution

The r17 parent mapping is already correct: **CCS-02-007 belongs to IMP-022**,
`Content, ContentVersion and independent state services`. It must not be moved to IMP-050:
IMP-050 is the later CCS-05 Design override/preset/thumbnails work package, while this leaf is the
shared resolver foundation explicitly sequenced in `CCS-02_TASKS.md`.

The serial delivery predecessor is **CCS-02-006**, which is present in the inspected baseline.
The resolver has no persistence, transaction, actor, state-transition, external-service, or runtime
dependency. Its only functional inputs are caller-supplied candidate values; it must not query a
Project, Content, preset, repository, configuration file, or environment itself.

## 2. Normative semantic boundary

The canonical precedence is fixed in `01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md` and
`09_SHARED_SPEC/AUTHORING_TO_TIMELINE_COMPILATION.md`:

```text
human override -> content AI auto -> project default -> system default
```

`03_CREATION/CCS-05_DESIGN_STUDIO.md` uses the equivalent wording
`System preset -> Project preset -> Content auto -> Human override`. The utility therefore selects
the first **present** candidate in the precedence order above. It must not use Python truthiness:
`0`, `false`, `""`, empty collections, and a caller's explicit JSON `null` are values when the
caller marks them present, not implicit fall-through signals.

Reset-to-AI is also fixed at the product boundary: `DELETE /timeline-keyframes/{id}/override`
clears the override only and does not delete the AI value (`API_CONTRACTS.md`). Accordingly, this
leaf may provide a pure helper for resolving values after an override is absent, but it must not
persist a reset, mutate an auto value, generate an auto value, or choose a project/system default.
Those actions remain with their later aggregate services and UI/API commands.

## 3. Contract gap requiring narrow change control

The required ordering is normative, but the generic utility interface is not. In particular, the
specification does not yet define all of the following:

1. a canonical Python/API representation that distinguishes an absent candidate from an explicit
   JSON `null` candidate;
2. whether the resolver returns only the resolved value or a typed provenance/source tag required
   by later render/review evidence;
3. the stable no-candidate outcome when all four candidate layers are absent; and
4. the authoritative mapping from `design_overrides.auto_value_json`/
   `override_value_json`, preset JSON, and any future caller fields to that generic interface.

The existing SQLite schema allows nullable JSON columns but does not define this resolver's
in-memory absence sentinel or output contract. Coding a `None`-means-absent convention would make
an unapproved decision about an explicitly nullable JSON value. Coding a raw-value-only return
would also preclude required provenance without a later breaking interface change.

Therefore a **narrow normative change-control record is required** before code. It should freeze a
generic, no-I/O value envelope (including an explicit absence marker), ordered inputs,
`EffectiveValueSource` vocabulary (`OVERRIDE`, `AUTO`, `PROJECT_DEFAULT`, `SYSTEM_DEFAULT`), the
all-absent error/result, and the rule that reset clears only the override presence/value. It must
state that this utility does not mutate persistence or create a fifth recipe/preset layer.

Recommended specification changes are limited to:

1. `01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md`
2. `09_SHARED_SPEC/AUTHORING_TO_TIMELINE_COMPILATION.md`
3. `09_SHARED_SPEC/API_CONTRACTS.md`
4. `03_CREATION/CCS-05_DESIGN_STUDIO.md`
5. `11_CODEX_TASKS/CCS-02_TASKS.md`
6. `FEATURE_REGISTRY.json`, `TEST_CATALOG.json`, `IMPLEMENTATION_REGISTRY.json`,
   `12_CHANGE_CONTROL/TRACEABILITY_MATRIX.md`, `12_CHANGE_CONTROL/DECISIONS.md`,
   `12_CHANGE_CONTROL/CHANGELOG.md`, and `PACKAGE_INDEX.json`.

No JSON payload schema, SQLite schema, migration, manifest, trigger, backfill, or external
contract change is needed for the proposed pure utility.

## 4. Candidate post-resolution implementation envelope

After the change is accepted, an immutable successor should resolve r17's deliberately empty
envelope while retaining parent IMP-022 and dependency CCS-02-006.

Create only:

1. `src/custom_content_studio/domain/effective_values.py`
2. `tests/unit/test_effective_values.py`
3. `reports/IMP-022_CCS-02-007_IMPLEMENTATION.md`

Modify only:

1. `src/custom_content_studio/domain/__init__.py`

The candidate module is a dependency-free domain value/policy utility. It does not belong in
`application/services`, a repository port, SQLite infrastructure, bootstrap composition, or
configuration loading. It must not construct a `Project` or `Content` model and must not require a
SQLite unit of work.

The unit tests must cover all four winning layers; absent override reset falling back to auto without
changing auto; falsey values winning when explicitly present; all-absent behavior; deterministic
source/provenance; and immutability/no mutation of supplied mappings or values. Existing
Workspace/ContentVersion/state-transition tests are regressions only; no temporary database is
needed for this leaf.

## 5. Traceability and ownership

The resolver is a CCS-02 foundation leaf but its currently registered product capability is
**F-009 Design override/reset** and its catalogued acceptance test is **T-050 Override precedence
and reset**, both assigned to CCS-05. `T-MED-024`, `T-MED-025`, `T-MED-071`, and `T-MED-072` are
later keyframe/reframe callers, not tests CCS-02-007 may claim. No existing invariant specifically
names generic effective-value precedence.

The change control must therefore introduce a narrowly scoped CCS-02 resolver test identity (or
explicitly split T-050 into a shared resolver case plus its CCS-05 integration case), assign it to
CCS-02-007/IMP-022, and add a corresponding resolver invariant if the package requires every leaf
to own an invariant. It must preserve F-009's product/UI/persistence ownership for CCS-05 and must
not claim F-024, recipe behavior, timeline mutation, or render evidence work.

## 6. Migration and prohibited scope

**Migration decision: NONE.** This discovery authorizes no database work and the future utility
does not require database storage. If implementation appears to require a column/table/trigger,
SQL manifest, data backfill, or schema change, stop with `MIGRATION_DECISION_REQUIRED`.

Forbidden now and in the proposed utility attempt: DesignPreset/DesignOverride persistence; recipe
application; Content/ContentVersion mutation; timeline/keyframe/reframe commands; UI/API routes;
render/worker/media/provider/network work; credentials/secrets; runtime or production databases;
dependency/lockfile changes; deployment; publication; and external side effects.

## 7. Resolution decision

**Both artifacts are required before implementation:** (1) the narrow change-control record that
freezes absence, result/provenance, all-absent, and reset semantics, and (2) an immutable successor
registry that replaces r17's discovery-only placeholder with the exact four-path envelope and
correct traceability. Until then, no ACTIVE packet or product-code change is safe.

## Skills used

- readchk
