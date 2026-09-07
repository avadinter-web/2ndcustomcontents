# IMP-010 / CCS-01-003 Implementation Evidence

Status: `PASS / UNCOMMITTED`

Date: `2026-09-08`

## Scope

- Added a typed, immutable runtime-path value object for one environment profile.
- Normalized independent `config`, `data`, `db`, `assets`, `cache`, `temp`, `output`, `logs`, and `credentials` locations as unique direct children of the supplied runtime root.
- Rejected relative runtime roots and any normalized location that escapes or aliases the runtime root.
- Kept normalization side-effect free: no directory, database, secret, or credential data is created, opened, or read.

Changes to existing configuration/bootstrap modules, database schemas, migrations, authentication,
secret values, provider integrations, UI, deployment, and external effects are outside this unit.

## Design and impact

`normalize_runtime_paths()` accepts the absolute profile root already produced by the existing
settings loader. It returns a frozen `RuntimePaths` object, so later slices can consume stable path
locations without coupling this leaf to persistence or startup mutation. Directory creation remains
the responsibility of a separately authorized lifecycle slice.

## Verification

All commands were run from `E:\Custom_Contents_APP` through the repository-local execution
contract where applicable.

| Check | Result |
|---|---|
| `.\scripts\run-module.ps1 pytest -p no:cacheprovider` | PASS — 17 tests |
| `.\scripts\run-module.ps1 ruff check --no-cache src tests` | PASS |
| `.\scripts\run-module.ps1 ruff format --check --no-cache src tests` | PASS — 15 files |
| `.\scripts\run-module.ps1 mypy --cache-dir .runtime\mypy-cache src` | PASS — 11 source files |
| CLI health and API/bootstrap/UI/workers/scheduler startup smoke | PASS — all exited 0 |
| strict specification synchronization and package-index verification | PASS — 76 features, 363 tests, 38 invariants |
| `git diff --check` | PASS |

The tests prove all nine locations are unique direct children, normalization rejects a relative
root, and normalization does not create the runtime root or any child directory.

## Known risks

- This slice defines locations only; it intentionally does not verify writability or create them.
- The credentials path is a location boundary, not authorization to store raw secrets there.

## Next recommendation

After this leaf is accepted, execute only the next frozen registry leaf. Do not begin database or
secret-storage work from this task.
