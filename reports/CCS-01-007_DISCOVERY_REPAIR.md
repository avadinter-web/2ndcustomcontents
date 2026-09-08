# CCS-01-007 Discovery Truncation Repair

Status: `DRAFT / NOT AUTHORIZED`
Date: 2026-09-08

## Outcome

The original `reports/CCS-01-007_DISCOVERY_WORK_PACKET.md` is retained byte-identically as
historical evidence. It ends immediately after the heading that introduces unit-test obligations,
so its test list, traceability decision, verification commands, completion criteria, stop
conditions and authorization boundary are absent.

The complete successor is `reports/CCS-01-007_DISCOVERY_WORK_PACKET_V2.md`. Immutable successor
r9 binds its exact digest while preserving the corrected `IMP-013` ownership from r8. r9 remains
`DRAFT / NOT_EVALUATED` and `implementation_authorized=false`.

| Item | Preserved source | Corrected successor |
|---|---|---|
| Registry | `vc01b-local-20260907-r8` | `vc01b-local-20260907-r9` |
| Discovery packet | truncated original | complete V2 at a new path |
| Parent | `IMP-013` | `IMP-013` |
| Leaf status | `DISCOVERY_REQUIRED` | `DISCOVERY_REQUIRED` |
| Path authority | deny all | deny all |

## Evidence bindings

| Evidence | SHA-256 |
|---|---|
| immutable r8 registry file | `506186fb89cf36fbda3acac280a1632a5c76cd0c911894da0285e9bf969abbe6` |
| original truncated discovery packet | `dbc4b9f3f1b441223aafdbab58761d5fc3c0de0e9b8f40af90ad50c7d1396601` |
| complete discovery packet V2 | `94ef53c1a9e683c04007f194e6b24f6e7120a42a5791558fc1b91ad37f8b6908` |
| repository commit at generation | `36b01e0d1a55f9bb9a66bb12220426d27d0ce0bc` |

## Restored sections

- exact unit, integration and bootstrap test obligations;
- explicit non-invention decision for absent feature/invariant/canonical-test IDs;
- required leaf/full test, lint, format, strict type and whitespace verification commands;
- completion criteria for bounded local observability only;
- fail-closed stop conditions and separate ACTIVE authorization boundary.

## Preserved constraints

- r8 and the original truncated packet are never overwritten;
- r9 contains 177 tasks: 5 `RESOLVED` and 172 `DISCOVERY_REQUIRED`;
- `CCS-01-007` keeps empty allowed/create/modify paths and `forbidden_paths=["**"]`;
- no product source, product test, dependency, database, migration, credential, listener, provider,
  external log sink, telemetry, deployment or publication action is changed or activated by this repair;
- r9 cannot authorize implementation.

## Reproduction

Run `.codex/ccs/tools/New-R9CCS01007DiscoveryRepair.ps1` from any PowerShell working directory.
The generator binds the exact r8 and original discovery SHA-256 values and refuses to overwrite any
V2/r9/repair-report output.
