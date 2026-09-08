# CCS-01-007 Contract Conflict Resolution

Status: `DRAFT / NOT AUTHORIZED`
Date: 2026-09-08

## Outcome

The r7 parent assignment for `CCS-01-007` is corrected from `IMP-012` to normative `IMP-013` in immutable successor r8. The leaf remains `DISCOVERY_REQUIRED` with no writable paths, no external observability permission and no implementation authority.

| Item | r7 | r8 |
|---|---|---|
| Registry ID | `vc01b-local-20260907-r7` | `vc01b-local-20260907-r8` |
| CCS-01-007 parent | `IMP-012` | `IMP-013` |
| Leaf path status | `DISCOVERY_REQUIRED` | `DISCOVERY_REQUIRED` |
| Registry status | `DRAFT` | `DRAFT` |
| Implementation authorized | `false` | `false` |

## Normative basis

- `IMPLEMENTATION_REGISTRY.json` assigns API/UI process shells, health/readiness endpoints, structured logging and visible request correlation to `IMP-013`.
- `IMP-013` depends on `IMP-010` and `IMP-012`; process observability ownership is not transferred to the authentication/session package.
- `11_CODEX_TASKS/CCS-01_TASKS.md` names `CCS-01-007` as "Logging and health".
- `reports/CCS-01-007_DISCOVERY_WORK_PACKET.md` binds the exact local-only allowlist and closed observability contract, but does not grant implementation authority.

## Evidence bindings

| Evidence | SHA-256 |
|---|---|
| immutable r7 registry | `3e9f6de7301ac9d60e660b5e3ba7802f4a1abbb07144d7876c7ec00dcc8e51c9` |
| CCS-01-007 discovery packet | `dbc4b9f3f1b441223aafdbab58761d5fc3c0de0e9b8f40af90ad50c7d1396601` |
| specification implementation registry | `143a41bab166f50adeb888d6eee74de81aa18ba54559f6e0601a23c77f354d83` |
| specification CCS-01 task breakdown | `7462e0eca03f1531f56407af2f23729c213d8e29cda0c68b88533e170c1f5509` |
| repository commit at generation | `3e7cdb7659db5ecbbf4161210a9610949dea2dae` |

## Preserved constraints

- Tasks: 177 total, 5 `RESOLVED`, 172 `DISCOVERY_REQUIRED`.
- r8 remains `DRAFT / NOT_EVALUATED` and `implementation_authorized=false`.
- `CCS-01-007` keeps empty path allowlists and `forbidden_paths=["**"]`.
- No product code, test, dependency, database, credential, listener, provider, external log sink or telemetry service is changed or activated.
- r7 is an immutable input and is never overwritten.

## Next controlled action

Issue a separate attempt-scoped ACTIVE local work packet that copies the discovery packet's exact allowlist and contract under `IMP-013`. r8 itself does not authorize implementation.

## Reproduction

Run `.codex/ccs/tools/New-R8CCS01007ConflictResolution.ps1` from any PowerShell working directory. The generator binds exact r7 and discovery-packet SHA-256 values and refuses to overwrite an existing r8 directory or report.
