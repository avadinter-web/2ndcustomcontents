# CCS-02-007 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-007
Parent: IMP-022
Predecessor: CCS-02-006
Repository branch: master
Repository baseline: 40c584c5a01088ffa9ec4e6067ba79bfebe4e7db
Registry: vc01b-local-20260907-r18
Registry file SHA-256: e438d86a2a0f637722c301b21b7cedc988411a40119468f61461974ee91a773b
Specification package digest: db518462a4b75bee85fcc8c34daf86f9fdd97bd650fb4c85c775f41b486c2753
Change control: CHG-2026-0025
Discovery SHA-256: 6cae41a5886332e5dc889befff7931d7b616b2eec3b560261b8f04b156c95986
Change-control SHA-256: f429a43522268114d38b90779c8676b455a5a999f65109575d98e1d6e461ebb6

## Authority

Understood as: this local packet authorizes one pure, in-process effective-value resolver attempt
against the exact r18 registry and master baseline above. It does not activate r18, transfer
CCS-05 ownership, or authorize persistence or external work.

## Exact allowlist

Create exactly these paths:

1. `reports/IMP-022_CCS-02-007_IMPLEMENTATION.md`
2. `src/custom_content_studio/domain/effective_values.py`
3. `tests/unit/test_effective_values.py`

Modify exactly this path:

4. `src/custom_content_studio/domain/__init__.py`

Any other implementation path is forbidden.

## Exact scope and verification

- Implement `EffectiveValueResolver` as a pure, no-I/O, caller-mapped four-layer resolver with
  precedence `OVERRIDE`, `AUTO`, `PROJECT_DEFAULT`, then `SYSTEM_DEFAULT`.
- Preserve the distinction between an absent candidate and a present JSON `null`; return source
  provenance with each resolved output and an explicit unresolved outcome when all candidates are
  absent.
- Implement reset-to-AI solely by removing `OVERRIDE` presence, without mutating `AUTO` or either
  default and without mutating any caller input.
- Own `F-078` and introduce/run `T-018` under `INV-EFFECTIVE-001`; only synthetic in-memory unit
  values are permitted.
- Run `pytest tests/unit/test_effective_values.py`; then run applicable static and repository
  whitespace/path checks before any commit.

## Absolute prohibitions and stop conditions

- `F-009` and `T-050` remain exclusively CCS-05-owned. Do not add a Design override/reset product,
  UI, API, persistence, recipe, Content, ContentVersion, timeline, keyframe, reframe or render
  mutation.
- Do not modify migration SQL, schema, manifest, trigger, backfill, runtime/production database,
  credentials, secret, network, provider, media, dependency, deployment, publication or external
  operation.
- Stop with the r18 code when the registry/spec/evidence binding drifts, CCS-02-006 acceptance is
  absent, storage or migration is needed, the packet becomes incomplete, or scope needs an
  unlisted path or CCS-05 ownership transfer.
