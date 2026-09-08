# CCS-01-008 Discovery Work Packet — Local Foundation Gate

Status: `DISCOVERY COMPLETE / EXECUTION NOT AUTHORIZED`
Date: `2026-09-08`
Repository: `E:\Custom_Contents_APP`
Inspected commit: `e61f711754da336d950c841d321758dafbbaecdb`
Canonical leaf: `CCS-01-008`
Canonical parent: `IMP-013`
Required outcome: run isolation, restart, and security regression for the completed CCS-01
foundation without external side effects.

## 1. Decision

`CCS-01-008` is an evidence-producing local gate leaf. It does not add product behavior and it
does not authorize source, migration, profile, dependency, or existing-test changes. Its only
permitted implementation outputs are an attempt-scoped gate test, the local authorization records,
and a redacted evidence report.

The r9 `IMP-013` parent is not a formal parent mismatch. `IMP-013` is the terminal CCS-01 work
package in `IMPLEMENTATION_REGISTRY.json`; its dependency closure includes `IMP-010`, `IMP-011`,
and `IMP-012`. There is no approved `IMP-014`. Creating one would be an architecture expansion.

There is, however, a blocking dependency-order defect. r9 currently records:

```text
CCS-01-007 -> CCS-01-008 -> CCS-01-009 -> CCS-01-010
```

The source task catalog calls `CCS-01-008` the CCS-01 gate and requires a security regression,
while `CCS-01-009` and `CCS-01-010` are later-added CCS-01 session and service-account security
requirements. The gate cannot close before those required security leaves. A successor immutable
registry must establish this effective order before a gate attempt:

```text
CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008
```

The successor must also resolve the semantic parents of `CCS-01-009` and `CCS-01-010` against
`IMP-012`, which owns authentication, secret references, and ActorContext. Their current generated
`IMP-010` and `IMP-011` assignments are not sufficient authority. Whether already implemented
`CCS-01-006` evidence supersedes part of `CCS-01-009` must be decided explicitly; it must not be
inferred from code overlap.

## 2. Normative evidence inspected

| Artifact | SHA-256 |
|---|---|
| r9 task registry | `08335C5B661806777AF006A448168204F58109F2C1F9B64135C2ECCC7F66C662` |
| `IMPLEMENTATION_REGISTRY.json` | `143A41BAB166F50ADEB888D6EEE74DE81AA18BA54559F6E0601A23C77F354D83` |
| `11_CODEX_TASKS/CCS-01_TASKS.md` | `7462E0ECA03F1531F56407AF2F23729C213D8E29CDA0C68B88533E170C1F5509` |
| `01_FOUNDATION/CCS-01_FOUNDATION.md` | `CA16AE21C502634A2D56769FBE830E1E36C3807415733A6A211F75A5E2F7D979` |
| `TEST_CATALOG.json` | `DDF6D2960B546F7643011953E03F1917FA87A434B0872B50CFD7E60B0D1FEDD9` |

The foundation contract requires isolated paths, independent profiles, durable SQLite state,
secret safety, scope-guard enforcement, clean boot, and restart survival. This local gate must not
be reported as formal `VC-03`, production readiness, deployment readiness, or completion of later
UI, provider, worker-fencing, scheduler-recovery, or publishing contracts.

## 3. Exact future write allowlist

A later, separately authorized gate attempt may write only these paths:

- `.codex/ccs/local_work_packets/CCS-01-008-attempt-001.md`
- `.codex/ccs/local_decisions/LD00-CCS-01-008-attempt-001.md`
- `tests/gates/test_ccs01_gate.py`
- `reports/IMP-013_CCS-01-008_GATE_EVIDENCE.md`

The gate test is allowed only to compose and recheck already implemented public contracts. A
failure requiring product behavior to change stops this leaf; the correction must be assigned to
the owning earlier leaf in a separate attempt. Existing tests are read-only inputs. The gate may
create disposable files only under pytest's unique `tmp_path` or a unique ignored
`.runtime/TEST/<run-id>` directory named in its work packet.

Forbidden writes include:

- `src/**`, `migrations/**`, `config/**`, `pyproject.toml`, `requirements.lock`, and `.env*`;
- every existing test file;
- r1 through r9 registry bytes;
- `.runtime/DEV/**`, `.runtime/STAGING/**`, and every database not created by this gate attempt;
- provider credentials, external accounts, network services, media uploads, publication, deploy,
  remote update, or production data.

## 4. Exact test evidence paths

The gate must collect all of the following existing paths without modifying them:

| Concern | Existing executable evidence |
|---|---|
| canonical package and legacy-module absence | `tests/test_package_layout.py`, `tests/test_scope_guard.py` |
| repository/runtime-root isolation | `tests/test_runtime_paths.py`, `tests/test_config.py`, `tests/test_environment_profiles.py` |
| SQLite bootstrap, restart durability, drift rejection, rollback | `tests/test_sqlite_bootstrap.py`, `tests/test_unit_of_work.py` |
| hash-only session persistence and one-way revocation | `tests/repository/test_session_repository.py`, `tests/integration/test_session_service.py` |
| secret references, masking, RBAC, workspace denial | `tests/contract/test_secret_store_port.py`, `tests/unit/test_security_contract.py` |
| safe health, correlation, entrypoint boot | `tests/unit/test_observability.py`, `tests/integration/test_startup_health.py`, `tests/test_bootstrap.py` |
| gate-only cross-contract checks | `tests/gates/test_ccs01_gate.py` (created by the authorized gate attempt) |

The gate-only test file must expose stable node IDs for exactly these missing aggregate checks:

- `test_toolchain_identity_matches_recorded_local_contract`
- `test_all_process_shells_start_and_stop_twice_without_provider_or_runtime_writes`
- `test_optional_provider_absence_does_not_break_foundation_boot`
- `test_ui_import_graph_has_no_database_or_secret_store_dependency`
- `test_dev_test_staging_roots_are_disjoint_and_test_effects_stay_in_test_root`
- `test_security_outputs_database_logs_and_health_contain_no_raw_secret`

Tests must use synthetic identifiers and secrets, loopback-only configuration, temporary SQLite
files, and fake adapters. No listener, provider SDK, credential lookup, real upload, scheduler
activation, or external request is part of this gate.

## 5. Test-catalog reconciliation required before execution

r9 already records introducing ownership for `T-001`, `T-002`, `T-ENV-001`, and `T-ENV-003`.
It has no introducing owner for `T-003`, `T-004`, `T-INT-137`, `T-ENV-002`, `T-ENV-004`,
`T-ENV-005`, or `T-ENV-006`. A successor registry must resolve each missing owner without
double-owning tests:

- bind `T-INT-137` to the approved session-security leaf after deciding the
  `CCS-01-006`/`CCS-01-009` overlap;
- preserve `T-003` media-tool identity evidence as the accepted VC-02 prerequisite and bind its
  runtime recheck locator to the gate packet;
- bind the first executable `T-004`, `T-ENV-002`, `T-ENV-004`, and applicable local portion of
  `T-ENV-006` checks to exact node IDs in `tests/gates/test_ccs01_gate.py`;
- retain `T-ENV-005` as deferred UI capability evidence unless its full independent-page and
  viewport contract is implemented under the approved UI package. Installed Streamlit API
  presence alone is not a PASS;
- retain worker lease and `REMOTE_UNKNOWN` portions of `T-ENV-006` as NOT RUN until their owning
  later packages exist. A CCS-01 local gate must not fabricate that evidence.

Because those ownership and dependency bindings are absent, r9 remains discovery-only and cannot
authorize this gate.

## 6. Exact verification command set

Run from `E:\Custom_Contents_APP` with the repository interpreter and an attempt-specific TEST
runtime. Absolute FFmpeg and FFprobe paths and hashes must be rechecked against
`reports/ENV-02_03_04_EXECUTION_REPORT.md` and `reports/VC-02_MEDIA_TOOLCHAIN_SMOKE.md` before
using their prior evidence.

```powershell
$env:CCS_ENV = "DEV"
$env:PYTHONDONTWRITEBYTECODE = "1"
.\.venv\Scripts\python.exe -m pytest -p no:cacheprovider tests/gates/test_ccs01_gate.py tests/test_package_layout.py tests/test_scope_guard.py tests/test_runtime_paths.py tests/test_config.py tests/test_environment_profiles.py tests/test_sqlite_bootstrap.py tests/test_unit_of_work.py tests/repository/test_session_repository.py tests/integration/test_session_service.py tests/contract/test_secret_store_port.py tests/unit/test_security_contract.py tests/unit/test_observability.py tests/integration/test_startup_health.py tests/test_bootstrap.py
.\.venv\Scripts\python.exe -m pytest -p no:cacheprovider
.\.venv\Scripts\python.exe -m ruff check --no-cache src tests
.\.venv\Scripts\python.exe -m ruff format --check --no-cache src tests
.\.venv\Scripts\python.exe -m mypy --cache-dir .runtime/TEST/ccs-01-008-attempt-001/mypy src
.\.venv\Scripts\python.exe -m pip check
.\scripts\run-module.ps1 custom_content_studio.cli --environment DEV health
.\scripts\run-module.ps1 custom_content_studio.bootstrap
.\scripts\run-module.ps1 custom_content_studio.api
.\scripts\run-module.ps1 custom_content_studio.ui
.\scripts\run-module.ps1 custom_content_studio.workers
.\scripts\run-module.ps1 custom_content_studio.scheduler
git diff --check
git status --short
```

Every process-shell command must be run a second time in the same attempt and exit cleanly. The
evidence report must record command, exit code, collected/passed counts, executable identity,
relevant artifact SHA-256 values, preexisting dirty-state manifest, and the exact post-run delta.
It must not contain absolute runtime data paths returned by health, secret material, environment
values, or exception tracebacks.

## 7. Binary completion criteria

The local gate may report `PASS / LOCAL DEVELOPMENT ONLY` only when all conditions below are true:

1. a successor immutable registry fixes the security-leaf ordering and owns every applicable
   named test with exact path and node ID;
2. `CCS-01-009` and `CCS-01-010` are accepted, or an explicit immutable supersession record proves
   their requirements are fully covered by accepted earlier leaves;
3. every focused and full regression command exits zero with no skip or xfail hiding a required
   capability;
4. a fresh temporary database is durable across close/reopen and migration restart is a no-op;
5. raw session tokens and synthetic secret values are absent from DB rows, logs, health payloads,
   reports, and the Git delta;
6. all process shells boot and stop twice without external provider access or writes outside the
   attempt's TEST root;
7. exact Python, lock, FFmpeg, and FFprobe identities match the accepted local evidence;
8. only the four authorized output paths and the ignored disposable TEST path changed;
9. final review explicitly states that this is not VC-03, production, deployment, UI-completeness,
   worker-recovery, or provider-readiness evidence.

Any failure produces `FAIL` with the owning prerequisite leaf and evidence locator. Missing or
ambiguous dependency/test ownership produces `TASK_ENVELOPE_INCOMPLETE`. An unaccepted security
leaf produces `PREREQUISITE_NOT_ACCEPTED`. Any external effect or write outside the allowlist
produces `SCOPE_VIOLATION` and stops the attempt.

## 8. Current readiness

Decision: `BLOCKED BEFORE EXECUTION`.

The exact local gate surface is now discoverable, but the current r9 dependency order places the
gate before two required security leaves and omits introducing ownership for seven CCS-01 catalog
tests. The next safe action is an immutable successor registry that resolves those bindings. No
source, migration, profile, existing test, runtime database, or external system was changed by
this discovery.
