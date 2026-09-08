# IMP-013 / CCS-01-008 Local Foundation Gate Evidence

Status: PASS / LOCAL FOUNDATION ONLY
Date: 2026-09-08
Attempt: CCS-01-008-attempt-001
Registry digest: 906fdbe838f1733013581afa2e0bf4e1143116a686bc51b949fb71d5403f0eb4
Repository baseline: 44df95d8be33a277c7a689cf9acd56e66904b5d6

## Decision

The exact r13 local gate passed. All six new gate nodes and the complete repository pytest suite
passed without changing product source, existing tests, registries, configuration, dependencies,
credentials, providers, external systems or repository runtime databases.

This is not a deployment, publication, provider, UI-completeness or staging receipt. T-ENV-005
and the complete T-ENV-006 remain downstream and are explicitly not claimed.

## Exact outputs and identity

| Output | SHA-256 |
|---|---|
| `.codex/ccs/local_work_packets/CCS-01-008-attempt-001.md` | `5c610fadf0f70711dce30d62e987408daacf85cdb54762dde2d8d96921825a43` |
| `.codex/ccs/local_decisions/LD00-CCS-01-008-attempt-001.md` | `79e22652eb483ddc70ecd0a68b5380f3aaa487ffe9c1d26f349f3d1ced5a26ea` |
| `tests/gates/test_ccs01_gate.py` | `757f50e81cee5c53f233c08242196c6dfa51b541b3c74e25e27cde1674258174` |

This report is the fourth exact output; its final digest is recorded outside itself to avoid a
recursive hash.

## Fresh local identity checks

| Artifact | SHA-256 | Result |
|---|---|---|
| `.venv/Scripts/python.exe` | `0b471133e110cfb53a061cad528ce8e517d7b9ac41a0a396c39ad795a487fc14` | PASS |
| `requirements.lock` | `421cb8cba331c116faa51e6fb5b86f8c299970968bd5f2f43b6544bd5f73d851` | PASS |
| FFmpeg 8.1.1 executable | `228d7a8556258de907fdb55f36850078ebc7680b84ec30d84ea02e99bec1d1eb` | PASS |
| FFprobe 8.1.1 executable | `0fde260f5abd35c9cafd96f594cc76365a780c1b73a90e35b6a3409ea1db1bf0` | PASS |

The binaries were read and hashed only. FFmpeg/FFprobe were not invoked, and no media input or
output was used.

## Gate nodes

| New aggregate node | Ownership/result |
|---|---|
| `test_toolchain_identity_matches_recorded_local_contract` | T-003 and local T-ENV-002 recheck — PASS |
| `test_optional_provider_absence_does_not_break_foundation_boot` | T-004 — PASS |
| `test_loopback_bindings_and_ui_import_boundary` | T-ENV-004 — PASS |
| `test_process_shells_start_stop_twice_without_provider_or_runtime_writes` | local T-ENV-006 subclaim only — PASS |
| `test_dev_test_staging_roots_are_disjoint_and_test_effects_stay_in_test_root` | T-002/T-ENV-001 regression — PASS |
| `test_security_outputs_database_logs_and_health_contain_no_raw_secret` | INV-AUTH-001/002 and INV-AUD-001 regression — PASS |

The final node created its SQLite file only below pytest `tmp_path`. No `.runtime/DEV`,
`.runtime/STAGING`, external or production database was opened or changed.

## Required ownership evidence

| Test IDs | Evidence | Result |
|---|---|---|
| T-001 | `tests/test_package_layout.py` | PASS |
| T-002, T-ENV-001 | scope guard, runtime-path and configuration tests | PASS |
| T-003, T-004, T-ENV-004 | `tests/gates/test_ccs01_gate.py` | PASS |
| T-ENV-002 | exact local identity node plus committed environment report | PASS |
| T-ENV-003 | `tests/test_environment_profiles.py` | PASS |
| T-INT-137 | session repository and service tests | PASS |
| T-INT-092, T-INT-093 | audit-event repository tests | PASS |
| T-INT-138 | ServiceAccount credential-reference rotation integration tests | PASS |

## Commands and results

| Verification | Result |
|---|---|
| `python -m pytest -q tests/gates/test_ccs01_gate.py` | PASS — 6 passed in 4.50s |
| `python -m pytest -q` | PASS — 134 passed in 28.84s |
| `python -m ruff check .` | PASS |
| `python -m ruff format --check tests/gates/test_ccs01_gate.py` | PASS — 1 file already formatted |
| `python -m mypy src` | PASS |

The repository-wide Ruff format check separately identified a pre-existing formatting difference
inside `reports/CCS-01-010_DISCOVERY_WORK_PACKET.md`. That tracked report existed at the bound
baseline, is outside r13's four paths and was not modified. The new gate file passes format check.

## Boundary confirmation

- Product source, existing tests, configuration, dependencies, lock and registries: unchanged.
- Provider imports/calls, credentials, OS secret store, network listeners and external services:
  not used.
- Runtime/production databases, media processing, deployment and publication: not used.
- Pre-existing unrelated dirty worktree state: preserved.
- Git stage, commit and push: not performed by this attempt.

## Skills used

- none
