# CCS-02-011 Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-011
Parent: IMP-022
Predecessors: CCS-02-010; semantic predecessors CCS-02-003/004/005/006
Repository branch: master
Repository baseline: 43fdada076d1af4b7e36296a35571298a66ba051
Registry: vc01b-local-20260907-r24
Registry file SHA-256: 218d23f6304f988d788a185af4815b9935bd70dfe9941ff20b5a3dc82c9f3fc0
Registry digest: 21335f0440ded952ad0a8b5e538908eda599146dace7485eb47e7dbed233568a
Specification package digest: 000ae438fdb6dfd15e0ac302e36196d5e4322ef5f8cd18ad015aec79b1cefa0a
Change control: CHG-2026-0031
Discovery SHA-256: 4237c2bd3c0a83b90b5aa9e0fa23a26e48739cf66e7960e1fdc7357d3690c118
Change-control SHA-256: edd8a3172e8a5b95ac201ad858e7bbd59461a2f351b0221249f91602d84a16e5

## Authority

This packet authorizes one local, fresh-temporary-SQLite core persistence/restart gate attempt
against the exact r24 registry and master baseline above. The r24 registry remains DRAFT; this
packet and the paired LD00 record are the sole ACTIVE local authority. It does not authorize any
product source, schema, migration, configuration, dependency, runtime database, API/UI, provider,
credential, deployment, publication, external operation, or any aggregate change.

## Exact allowlist

Create exactly these paths:

1. `reports/IMP-022_CCS-02-011_IMPLEMENTATION.md`
2. `tests/gates/test_ccs02_gate.py`

Any other implementation path is forbidden.

## Exact scope and verification

- The gate must create a fresh temporary SQLite database, run the already-present migration path,
  seed a legal two-Workspace fixture, commit, construct a new `SQLiteConnectionFactory`, and reopen
  the same database.
- It must prove Workspace, Project, Asset, Content, ContentVersion, authoring head, status and
  row-version persistence across that restart boundary; database FK and unique integrity; exact
  stale-CAS rejection with no partial or orphan rows; Content limited to IDEA/ACTIVE/ARCHIVED with
  only activate, archive and submit-review edges; blocked ContentVersion deletion; and concealed or
  denied cross-Workspace access.
- Own `F-003`, `F-004`, `F-005` and `F-006`; introduce and run `T-011`, `T-013`, `T-014`, `T-015`,
  `T-016`, `T-017`, `T-INT-031` and `T-INT-050` under `INV-WS-001` and `INV-IMM-001`.
- Run `pytest tests/gates/test_ccs02_gate.py`, then the listed repository and integration regression
  tests, applicable static checks, and repository whitespace/path checks before any commit.

## Absolute prohibitions and stop conditions

- Do not modify source, schema, migration, configuration, dependency, runtime database, API/UI,
  helper F-079/F-080 ownership, provider/network, credentials, deployment, publication, or any
  unlisted path.
- Do not use a non-temporary database or retain a gate database or connection after the test.
- Do not modify `.env`, `.runtime/**`, `credentials/**`, `migrations/**`, `requirements.lock`,
  `src/**`, `config/**`, `tests/repository/**`, `tests/integration/**`, or `tests/contract/**`.
- Stop with the r24 code when the registry/spec/evidence binding drifts, CCS-02-010 or semantic
  predecessor acceptance is absent, a product edit or non-temporary database is needed, the packet
  becomes incomplete, or scope needs an unlisted path.
