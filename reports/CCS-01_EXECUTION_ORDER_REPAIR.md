# CCS-01 Execution Order and Semantic Ownership Repair

Status: `DRAFT / NOT AUTHORIZED`
Date: 2026-09-08

## Outcome

Immutable successor r10 repairs the effective CCS-01 tail order to:

`CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008`

It also corrects `CCS-01-009` and `CCS-01-010` to normative parent `IMP-012`. All four
leaves remain `DISCOVERY_REQUIRED` with empty write allowlists and `forbidden_paths=["**"]`.
r10 is `DRAFT / NOT_EVALUATED` and `implementation_authorized=false`.

## Normative proof

- `CCS-01_TASKS.md#L29` defines app-managed Session token hash, rotation family and one-way revocation.
- `CCS-01_TASKS.md#L30` defines ServiceAccount credential secret reference and rotation audit.
- `IMP-012` is titled "Authentication, secret references and ActorContext" and owns the session service,
  secret-store port, audit-safe request context, hash-only session test and secret masking evidence.
- `CCS-01-008` is the CCS-01 gate and the foundation gate rejects secrets-safety failures, so it must
  follow the two applicable security leaves.

| Evidence | SHA-256 |
|---|---|
| immutable r9 registry | `08335c5b661806777af006a448168204f58109f2c1f9b64135c2eccc7f66c662` |
| `IMPLEMENTATION_REGISTRY.json` | `143a41bab166f50adeb888d6eee74de81aa18ba54559f6e0601a23c77f354d83` |
| `11_CODEX_TASKS/CCS-01_TASKS.md` | `7462e0eca03f1531f56407af2f23729c213d8e29cda0c68b88533e170c1f5509` |
| `01_FOUNDATION/CCS-01_FOUNDATION.md` | `ca16ae21c502634a2d56769fbe830e1e36c3807415733a6a211f75a5e2f7d979` |
| `reports/CCS-01-008_DISCOVERY_WORK_PACKET.md` | `b6a9cf6b24ca7a1da57f31329f2d9350297c32d5b5490fad3ec64ba6b7acb0e9` |
| repository commit at generation | `e61f711754da336d950c841d321758dafbbaecdb` |

## Exact graph delta

| Leaf | r9 parent / dependency | r10 parent / dependency |
|---|---|---|
| `CCS-01-007` | `IMP-013` / `CCS-01-006` | unchanged |
| `CCS-01-009` | `IMP-010` / `CCS-01-008` | `IMP-012` / `CCS-01-007` |
| `CCS-01-010` | `IMP-011` / `CCS-01-009` | `IMP-012` / `CCS-01-009` |
| `CCS-01-008` | `IMP-013` / `CCS-01-007` | `IMP-013` / `CCS-01-010` |

## Preserved constraints and remaining work

- r9 is retained byte-identically; the generator binds and rechecks its exact SHA-256.
- r10 contains 177 tasks: 5 `RESOLVED` and 172 `DISCOVERY_REQUIRED`.
- No product source, tests, migration, runtime data, credential, provider, deployment or publication is changed.
- This repair does not infer that `CCS-01-006` supersedes `CCS-01-009` and assigns no missing catalog test ownership.
- The next safe action is a separate discovery successor for `CCS-01-009` overlap, exact paths and tests.
- No leaf implementation or CCS-01 gate execution is authorized by r10.

## Reproduction

Run `.codex/ccs/tools/New-R10CCS01ExecutionOrderRepair.ps1`. The generator validates all bound
normative hashes and semantic markers and refuses to overwrite r10 or this report.
