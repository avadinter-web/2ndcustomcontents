# IMP-022 / CCS-02-008 Implementation Evidence

## Scope

Understood as: provide only the reusable, in-memory normalized-coordinate value object for
`F-079` / `T-019` under `INV-GEOMETRY-001`, without transferring any CCS-05 editor or rendering
policy ownership.

Implemented immutable `NormalizedRect` with exactly `x`, `y`, `width`, and `height` public data
fields. It validates finite real coordinate inputs at construction: x/y are inclusive `[0, 1]` and
width/height are `(0, 1]`.

## Contract evidence

- Boolean, non-real, NaN, and infinite values use the stable domain `ValueError` validation
  contract rather than leaking storage or API errors.
- Frozen slots prevent in-place mutation after construction.
- `x + width` and `y + height` are deliberately not constrained. Callers own containment,
  clipping, crop, rotation, anchor, aspect-ratio, safe-area, and render/pixel policy.

## Exclusions

No migration, storage, render-plan mutation, Content/ContentVersion mutation, editor/API/UI,
repository/service/bootstrap work, provider/network/media operation, credential, dependency,
deployment, publication, or external side effect is included.
