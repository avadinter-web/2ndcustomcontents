# CCS-02-008 NormalizedRect Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR AND NARROW CHANGE CONTROL REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository baseline: `b678267dd9a3d4f2955078116b6feca8f5be4e6e` (CCS-02-007 accepted local implementation)
Registry inspected: `vc01b-local-20260907-r18`
Canonical task: CCS-02-008 — NormalizedRect value object

## 1. Read confirmation and dependency resolution

Understood as: discover the smallest pure, immutable normalized-coordinate value object for a
later renderer/editor caller; do not implement it, change a registry, or assign it storage/API/UI
responsibilities.

The immediate serial predecessor is **CCS-02-007**, accepted at the inspected baseline. The r18
placeholder maps this leaf to **IMP-023**, but that package is the CCS-09 fenced-worker kernel and
typed dispatch/journal work. It is not a CCS-02 data-model package. The correct parent is
**IMP-022 — Content, ContentVersion and independent state services**, which already owns the
shared Content-side foundations completed by CCS-02-004 through CCS-02-007. The registry successor
must correct only this parent mapping and retain `depends_on=[CCS-02-007]`.

NormalizedRect has no persistence, transaction, actor, state-transition, service-account,
provider, network, runtime, or media-tool dependency. It is a reusable domain value object; later
CCS-05 design/timeline and CCS-06 render-plan code are callers, not part of this leaf.

## 2. Normative validation semantics

`01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md` requires `x`, `y`, `width`, and `height` in the
normalized 0..1 coordinate space. The more exact schema authority,
`13_IMPLEMENTATION_CONTRACTS/schemas/render-plan.v1.schema.json#/$defs/NormalizedRect`, resolves
the endpoint semantics:

| Field | Required range |
| --- | --- |
| `x`, `y` | `0 <= value <= 1` |
| `width`, `height` | `0 < value <= 1` |

The schema intentionally does **not** require `x + width <= 1` or `y + height <= 1`. This leaf
must not add containment, clipping, aspect-ratio, pixel conversion, rotation, anchor, crop, or
safe-area policy. Such rules belong to the concrete schema caller or later editor/render
validation. A `NormalizedRect(1, 1, 1, 1)` is therefore valid at this shared-value-object boundary.

The Python contract must reject non-real values, booleans, NaN, and infinities so it cannot emit an
object that the JSON `number` contract cannot represent. It must use a stable
`DOMAIN_VALIDATION_FAILED`-style domain error mapping, rather than leaking a database/API error.

## 3. Immutability and interface boundary

The candidate object should be a dependency-free frozen dataclass (with slots where compatible)
whose four public fields are `x`, `y`, `width`, and `height`. Construction performs all validation;
after construction no field can change. It must not retain a mutable caller mapping, serialize
through a database, or depend on Pydantic/FastAPI.

Its only candidate in-process interface is a domain value object:

`custom_content_studio.domain.normalized_rect.NormalizedRect`

Its exact JSON-shape projection, if needed by a future caller, must use the four schema field names
and must not introduce a versioned envelope in this leaf. The render-plan schema remains the
authoritative external shape; this leaf does not edit it.

## 4. Traceability gap and required narrow change control

No current feature, invariant, or CCS-02 test identity owns this shared primitive. `F-009` / `T-051`
own the later CCS-05 Design override/reset product behavior, and cannot be transferred merely
because their callers eventually use normalized geometry. `F-004` is a supporting CCS-02 data-core
feature but its catalogued tests (`T-012..T-014`) do not describe coordinate validation.

Before an implementation packet is issued, narrow change control must create a CCS-02-specific
traceability binding. The recommended new identities are `F-079` (NormalizedRect domain value),
`T-019` (NormalizedRect endpoint/non-finite/immutability validation), and
`INV-GEOMETRY-001` (only schema-representable normalized rectangle coordinates may be constructed).
The change must preserve `F-009` / `T-051` as CCS-05 integration ownership and bind the primitive
to the existing render-plan schema without changing that schema.

Recommended changed specification files are limited to:

1. `01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md`
2. `13_IMPLEMENTATION_CONTRACTS/schemas/render-plan.v1.schema.json` only if a prose cross-reference
   is needed; no schema-field change is proposed
3. `11_CODEX_TASKS/CCS-02_TASKS.md`
4. `FEATURE_REGISTRY.json`, `INVARIANT_REGISTRY.json`, `TEST_CATALOG.json`, and
   `IMPLEMENTATION_REGISTRY.json`
5. `12_CHANGE_CONTROL/TRACEABILITY_MATRIX.md`, `12_CHANGE_CONTROL/DECISIONS.md`,
   `12_CHANGE_CONTROL/CHANGELOG.md`, and `PACKAGE_INDEX.json`

## 5. Candidate post-resolution implementation envelope

After the change control is accepted, immutable r19 (or the next immutable successor) should
resolve the discovery placeholder, correct the parent to IMP-022, retain CCS-02-007 as the sole
dependency, and permit only this envelope.

Create:

1. `reports/IMP-022_CCS-02-008_IMPLEMENTATION.md`
2. `src/custom_content_studio/domain/normalized_rect.py`
3. `tests/unit/test_normalized_rect.py`

Modify:

1. `src/custom_content_studio/domain/__init__.py`

The test module must prove inclusive x/y boundaries; positive width/height boundaries; rejection
of negative, over-one, zero-size, boolean, NaN, and infinite inputs; immutable replacement-only
behavior; and no containment rule beyond the schema. No temporary database or fixture is needed.
`tests/unit/test_effective_values.py` is a regression-only neighbor and must not be modified.

## 6. Migration, external restrictions, and stop conditions

**Migration decision: NONE.** No table, column, trigger, manifest, backfill, or database use is
needed. If implementation appears to require any of those, stop with
`MIGRATION_DECISION_REQUIRED`.

Forbidden paths and effects include `migrations/**`, `.runtime/**`, credentials/secrets, API/UI,
repositories, application services, bootstrap composition, provider/network/media work,
dependencies/lockfiles, deployment, publication, and all external side effects. The object must not
change render plans, content versions, assets, timelines, or any persisted record.

## 7. Resolution decision

**Both a narrow change-control record and an immutable successor are required before code.** The
former supplies missing CCS-02 traceability and confirms schema endpoint precedence; the latter
replaces the r18 discovery-only placeholder with the exact four-path envelope and correct IMP-022
parent. Until both validate, no ACTIVE attempt packet, source/test edit, registry edit, commit, or
push is authorized for CCS-02-008.

## Skills used

- readchk
