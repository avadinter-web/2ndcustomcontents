# IMP-010 / CCS-01-011 Canonical Package Layout Migration

Status: `VERIFIED`
Date: 2026-09-08

## Scope

This supplemental foundation leaf mechanically replaces seven conflicting flat modules with the
approved canonical directory packages. Existing public imports and executable module names remain
stable. `scope_guard.py`, `runtime_paths.py`, and the singular `worker.py` compatibility alias remain
root-level.

No database, migration, persistence, provider SDK, secret, external I/O, network listener, UI page,
job dispatch, or user-facing feature was added.

## Canonical mapping

| Removed flat module | Canonical implementation |
|---|---|
| `bootstrap.py` | `bootstrap/__init__.py`, `composition.py`, `startup.py` |
| `config.py` | `config/__init__.py`, `models.py`, `loader.py` |
| `api.py` | `api/__init__.py`, `api/__main__.py` |
| `ui.py` | `ui/__init__.py`, `ui/__main__.py` |
| `workers.py` | `workers/__init__.py`, `workers/__main__.py`, `runner.py` |
| `scheduler.py` | `scheduler/__init__.py`, `scheduler/__main__.py`, `runner.py` |
| `cli.py` | `cli/__init__.py`, `cli/__main__.py` |

`bootstrap/__main__.py` and `config/__main__.py` are also present because a Python package requires
that entrypoint to preserve its former `python -m custom_content_studio.<module>` execution contract.
They contain no product behavior.

## Compatibility proof

- Existing imports continue through package-level re-exports.
- `config/loader.py` adjusts the repository-root parent depth for its new nested location.
- `tests/test_package_layout.py` proves all required packages, entrypoints, internal modules, and the
  absence of conflicting flat files.
- The original process shells remain composition validation only.

## Verification

All commands were run from `E:\Custom_Contents_APP` through the repository runner where applicable.

| Check | Result |
|---|---|
| `pytest -q` | PASS, 32 tests |
| `ruff check src tests` | PASS |
| `ruff format --check src tests` | PASS, 29 files formatted |
| `mypy src` with strict project settings | PASS, 24 source files |
| `git diff --check` | PASS |

The executable-module smoke set passed for `bootstrap`, `config`, `api`, `ui`, `workers`, the
singular `worker` compatibility alias, `scheduler`, and `cli health`. The explicit scope-guard smoke
also passed and scanned all 24 Python source files in the nested canonical package tree.

No commit, push, or stage operation is part of this implementation handoff.
