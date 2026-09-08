# CCS-01-005 Contract Conflict Resolution

Status: `DRAFT / NOT AUTHORIZED`
Date: 2026-09-08

## Outcome

The r5 parent assignment for `CCS-01-005` is corrected from `IMP-010` to `IMP-011` in immutable successor r6. The leaf remains `DISCOVERY_REQUIRED` with no writable paths, no migration permission, and no implementation authority.

| Item | r5 | r6 |
|---|---|---|
| Registry ID | `vc01b-local-20260907-r5` | `vc01b-local-20260907-r6` |
| CCS-01-005 parent | `IMP-010` | `IMP-011` |
| Leaf path status | `DISCOVERY_REQUIRED` | `DISCOVERY_REQUIRED` |
| Registry status | `DRAFT` | `DRAFT` |
| Implementation authorized | `false` | `false` |

## Normative evidence

- `11_CODEX_TASKS/CCS-01_TASKS.md` defines legacy task `01-05` as SQLite bootstrap with durable initialization and restart testing.
- `IMPLEMENTATION_REGISTRY.json` assigns migration manifest, schema bootstrap, `UnitOfWork`, and SQLite foreign-key/WAL/busy-timeout bootstrap to `IMP-011`.
- `IMP-010` owns repository scaffold, composition root, runtime profiles, and entrypoint shells; it does not own persistence.

Evidence bindings:

- r5 SHA-256: `014ede67735ecefda1400b9c880c582438f2a6bb550b387d763bb5a812a27679`
- specification `IMPLEMENTATION_REGISTRY.json` SHA-256: `143a41bab166f50adeb888d6eee74de81aa18ba54559f6e0601a23c77f354d83`
- specification `11_CODEX_TASKS/CCS-01_TASKS.md` SHA-256: `7462e0eca03f1531f56407af2f23729c213d8e29cda0c68b88533e170c1f5509`
- repository baseline commit: `2000486a6ac5dfb42a765fcf998bcd53419a642c`

## Preserved fail-closed state

- Total leaves: 177
- `RESOLVED`: 5
- `DISCOVERY_REQUIRED`: 172
- readiness decision: `NOT_EVALUATED`
- CCS-01-005 allowed/create/modify paths remain empty
- CCS-01-005 forbidden paths remain `**`
- CCS-01-005 migration policy remains `FORBIDDEN` until a later exact discovery revision
- no product code, database, migration, or product test is created or executed by this correction

## Required next design step

Resolve the exact canonical source, migration, test, and interface paths for CCS-01-005 under IMP-011. Bind feature, invariant, and test ownership; define migration safety and rollback evidence; then issue a later immutable registry revision and a separate ACTIVE work packet. r6 itself cannot authorize implementation.

## Reproduction

Run `.codex/ccs/tools/New-R6CCS01005ConflictResolution.ps1` from any PowerShell working directory. The generator binds the exact r5 SHA-256 and refuses to overwrite an existing r6 directory.