# CCS-01-006 Contract Conflict Resolution

Status: `DRAFT / NOT AUTHORIZED`
Date: 2026-09-08

## Outcome

The r6 parent assignment for `CCS-01-006` is corrected from `IMP-011` to normative `IMP-012` in immutable successor r7. The leaf remains `DISCOVERY_REQUIRED` with no writable paths, no credential permission and no implementation authority.

| Item | r6 | r7 |
|---|---|---|
| Registry ID | `vc01b-local-20260907-r6` | `vc01b-local-20260907-r7` |
| CCS-01-006 parent | `IMP-011` | `IMP-012` |
| Leaf path status | `DISCOVERY_REQUIRED` | `DISCOVERY_REQUIRED` |
| Registry status | `DRAFT` | `DRAFT` |
| Implementation authorized | `false` | `false` |

## Normative evidence

- `IMPLEMENTATION_REGISTRY.json` assigns the session service, SecretStore port, Workspace authorization middleware and audit-safe ActorContext to `IMP-012`.
- `IMP-012` depends on `IMP-011`; authentication/session ownership is not transferred to the SQLite kernel.
- `11_CODEX_TASKS/CCS-01_TASKS.md` defines legacy task `01-06` as secret references, basic roles and masking.
- `reports/CCS-01-006_DISCOVERY_WORK_PACKET.md` closes the exact local-only source, interface, test, safety and approval contract without granting execution authority.

Evidence bindings:

- r6 SHA-256: `75f316ed32e672a1143909afa96add5c88e9a9694d4ed3a6f97ce09736f96cf8`
- discovery packet SHA-256: `b19c5de6e064db201f8577a759c9841e12015f7b8371ee14f2624af132169fff`
- specification `IMPLEMENTATION_REGISTRY.json` SHA-256: `143a41bab166f50adeb888d6eee74de81aa18ba54559f6e0601a23c77f354d83`
- specification `11_CODEX_TASKS/CCS-01_TASKS.md` SHA-256: `7462e0eca03f1531f56407af2f23729c213d8e29cda0c68b88533e170c1f5509`
- repository baseline commit: `fa281a38c8e8d8010b05573fe5c224c0b16ce359`

## Preserved fail-closed state

- total leaves: 177
- `RESOLVED`: 5
- `DISCOVERY_REQUIRED`: 172
- readiness decision: `NOT_EVALUATED`
- CCS-01-006 allowed/create/modify paths remain empty
- CCS-01-006 forbidden paths remain `**`
- external side effects and migrations remain forbidden
- no product code, tests, credentials, accounts, runtime database or existing registry is changed by this correction

## Approval boundary and next action

No credential or provider-account approval is required for this registry-only correction. Actual credential/account/OS secret changes remain prohibited and would require a separate explicit approval. The next orchestration action is a separate attempt-scoped ACTIVE local work packet that copies the exact allowlist and contract from the bound discovery packet. r7 itself cannot authorize implementation or activate a successor leaf.

## Reproduction

Run `.codex/ccs/tools/New-R7CCS01006ConflictResolution.ps1` from any PowerShell working directory. The generator binds exact r6 and discovery-packet SHA-256 values and refuses to overwrite an existing r7 directory or report.