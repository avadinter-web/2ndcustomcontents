# IMP-010 / CCS-01-002 Implementation Evidence

Status: `CODE_VERIFIED / R3_REGISTRY_RECONCILED / UNCOMMITTED`

Date: `2026-09-08`

understood as: implement only the local-development scope guard for the existing repository foundation, bind it to the shared startup path, and prove root identity, legacy isolation, and mutable-runtime containment without adding persistence, security, providers, or UI features.

## Scope

- Added a side-effect-free runtime scope validator with an explicit absolute repository root.
- Validated the repository identity from `pyproject.toml` and `src/custom_content_studio`.
- Rejected legacy repository paths, loaded legacy modules, and legacy Python imports in application source.
- Rejected mutable runtime roots outside the resolved repository.
- Connected the validator to the existing shared bootstrap used by API, UI, workers, scheduler, and CLI health shells.
- Exposed the same validation as `python -m custom_content_studio.scope_guard` with explicit root arguments.

Database code, migrations, authentication, secret storage, provider integrations, product UI pages, deployment, remote updates, and new dependencies are outside this unit.

## Verification

| Check | Result |
|---|---|
| `run-module.ps1 pytest -p no:cacheprovider` | PASS — 14 tests |
| `run-module.ps1 ruff check --no-cache src tests` | PASS |
| `run-module.ps1 ruff format --check --no-cache src tests` | PASS — 13 files |
| `run-module.ps1 mypy ... src` | PASS — 10 source files |
| scope-guard module CLI | PASS — explicit repository/runtime roots, 10 Python files scanned |
| API, UI, workers, scheduler and health startup smoke | PASS |
| strict specification synchronization | PASS — 76 features, 363 tests, 38 invariants |

The canonical repository runner was used for package imports. A direct `.venv` `python -c`
diagnostic without the runner did not resolve the `src` layout, as expected by the repository
execution contract; it changed no files and is not a product failure.

## r3 registry reconciliation

The immutable r1 and r2 registries remain unchanged. The r2 revision narrowed `CCS-01-001` and
`CCS-01-002`; a separate
`vc01b-local-20260907-r2/task-registry.json` corrects only `CCS-01-001` and `CCS-01-002`:

- both map to `IMP-010`, matching the static work-package definition;
- their source, test, and report paths are exact rather than broad directories;
- their scope is local development only and forbids deployment, remote updates, and external effects.

The new `vc01b-local-20260907-r3/task-registry.json` replaces the future `CCS-01-003` broad
`tests` creator with exact runtime-path source, test and implementation-report paths, and maps the
leaf to the matching `IMP-010` baseline package. The official complete orchestration checker,
embedded CCS-CJSON-1 digest verification and strict package synchronization all pass. The detailed
path audit and preservation hashes are recorded in `reports/VC-01B_R3_PATH_OWNERSHIP.md`.

This unit remains uncommitted and was not pushed because commit/push are separate repository
actions outside this planning reconciliation. All product-code validation results above remain
PASS, and the working changes are preserved for the next integration review.

## Spec impact

No normative specification change is required. This unit implements the existing CCS-01 scope-guard and legacy-isolation contracts.
