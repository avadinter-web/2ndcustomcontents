# CCS-02-009 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-009
Parent: IMP-022
Predecessor: CCS-02-008
Repository branch: master
Repository baseline: 1c623fbd89a2bde71d8b745250c665a821c4cc08
Registry: vc01b-local-20260907-r20
Registry file SHA-256: 4464a89837c7969694eb07777a135c9771b825bcbf4976af5b4e059e7a103c4d
Registry digest: 23fb0bd64445ef7e93f1656a75ff0f47631dd017362902973efd5e3505ff789a
Specification package digest: bc94e6ef58920ea575e7e2d8e7cfac9b8c4289b96bdc447bd6a851da59957197
Change control: CHG-2026-0027
Discovery SHA-256: 4fe7108d235537eb5b43dada69ba24ac633f67a611e9c885f37c1c64d21abe7a
Change-control SHA-256: cb289af891d9acc6684ce60404790635f39da3d88df3bde413c37d10bb40973e

## Authority

This packet authorizes one pure, in-process, lossless editable-text safety-policy attempt against
the exact r20 registry and master baseline above. The r20 registry remains DRAFT; this packet and
the paired LD00 record are the sole ACTIVE local authority. It does not activate r20, create a
CCS-07 consumer, or authorize persistence, migration, rendering, sanitization, serialization,
external work, or any aggregate change.

## Exact allowlist

Create exactly these paths:

1. `reports/IMP-022_CCS-02-009_IMPLEMENTATION.md`
2. `src/custom_content_studio/domain/editable_text.py`
3. `tests/unit/test_editable_text.py`

Modify exactly this path:

4. `src/custom_content_studio/domain/__init__.py`

Any other implementation path is forbidden.

## Exact scope and verification

- Implement only `normalize_editable_text(value: str | None) -> str | None` as a pure,
  dependency-free domain policy under `custom_content_studio.domain.editable_text`.
- Preserve `None` and the empty string as distinct values. Accepted strings must retain the exact
  Python-code-point sequence, including valid Unicode and every existing LF, CR, and CRLF sequence.
- Do not apply Unicode normalization, trimming, case conversion, whitespace collapse, escaping,
  sanitization, or line-ending conversion.
- Permit at most 10,000 Python code points as measured by `len(value)`; reject non-string
  non-None values, lone surrogates, all Cc controls except LF/CR, and lengths above the limit
  through the stable `DOMAIN_VALIDATION_FAILED` contract.
- Own `F-080` and introduce/run `T-020` under `INV-TEXT-001`; only synthetic in-memory unit
  values are permitted. `T-020` must cover None/empty distinction, Unicode and CR/LF/CRLF identity,
  absent normalization-form conversion, 10,000/10,001 boundaries, rejected control/surrogate/type
  values, and no I/O.
- Run `pytest tests/unit/test_editable_text.py`; then run applicable static and repository
  whitespace/path checks before any commit.

## Absolute prohibitions and stop conditions

- CCS-07 remains an unchanged future consumer. Do not modify ReviewSession, review-note
  persistence, review decisions, approval lineage, Content/ContentVersion, API/UI, repositories,
  application services, bootstrap, text rendering, HTML sanitization, serialization, or storage.
- Do not modify migration SQL, schema, manifest, trigger, backfill, runtime/production database,
  credentials, secrets, network, provider, media, dependency, deployment, publication, or external
  operation.
- Stop with the r20 code when the registry/spec/evidence binding drifts, CCS-02-008 acceptance is
  absent, storage or migration is needed, the packet becomes incomplete, or scope needs an
  unlisted path or CCS-07 ownership transfer.
