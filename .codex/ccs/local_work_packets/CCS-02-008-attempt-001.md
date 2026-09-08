# CCS-02-008 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-008
Parent: IMP-022
Predecessor: CCS-02-007
Repository branch: master
Repository baseline: b678267dd9a3d4f2955078116b6feca8f5be4e6e
Registry: vc01b-local-20260907-r19
Registry file SHA-256: b5465b862477985ee574b08b38c5e9967dc2e9b50e8d4986bdf2e7b66f6cdee8
Registry digest: d6580809fa1604051336c93c454f760a5808030ab553750e016fc41f1e81508a
Specification package digest: 737ba0a9971026c44570edbe6e46c4e20b96b53ce88a3475b0538aaccf673435
Change control: CHG-2026-0026
Discovery SHA-256: aa837c306a0f0a9a2c23dd2c5cb3997c6962eeaa261d2721b4eba31298db1809
Change-control SHA-256: 0ca716fa2a3dd67109b4ff1e78211354606e8cdd5635906299b46b3aaf9d030e

## Authority

This packet authorizes one pure, in-process immutable `NormalizedRect` value-object attempt
against the exact r19 registry and master baseline above. It does not activate r19, alter the
render-plan schema, transfer CCS-05 ownership, or authorize persistence or external work.

## Exact allowlist

Create exactly these paths:

1. `reports/IMP-022_CCS-02-008_IMPLEMENTATION.md`
2. `src/custom_content_studio/domain/normalized_rect.py`
3. `tests/unit/test_normalized_rect.py`

Modify exactly this path:

4. `src/custom_content_studio/domain/__init__.py`

Any other implementation path is forbidden.

## Exact scope and verification

- Implement the immutable, dependency-free `NormalizedRect` with exactly `x`, `y`, `width`, and
  `height` numeric fields.
- Accept x/y inclusive `[0, 1]` and width/height `(0, 1]`; reject booleans, non-real values, NaN,
  and infinities through the stable domain validation error contract.
- Deliberately do not impose `x + width <= 1` or `y + height <= 1`; containment, clipping, crop,
  rotation, anchor, aspect ratio, safe-area and pixel/render policy are caller concerns.
- Own `F-079` and introduce/run `T-019` under `INV-GEOMETRY-001`; only synthetic in-memory unit
  values are permitted.
- Run `pytest tests/unit/test_normalized_rect.py`; then run applicable static and repository
  whitespace/path checks before any commit.

## Absolute prohibitions and stop conditions

- `F-009` and `T-051` remain exclusively CCS-05-owned. Do not implement an editor, override/reset
  feature, containment policy, render-plan mutation, or API/UI/persistence integration.
- Do not modify migration SQL, schema, manifest, trigger, backfill, runtime/production database,
  credentials, secrets, network, provider, media, dependency, deployment, publication or external
  operation.
- Stop with the r19 code when the registry/spec/evidence binding drifts, CCS-02-007 acceptance is
  absent, storage or migration is needed, the packet becomes incomplete, or scope needs an
  unlisted path or CCS-05 ownership transfer.
