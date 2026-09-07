# VC-01B r3 Path Ownership Reconciliation

Status: `PASS / FROZEN / PLANNING ONLY`

Date: `2026-09-08`

## Scope and boundary

This reconciliation corrects the runtime-registry path ownership defect that blocked the
`CCS-01-002` implementation unit. It creates a new immutable r3 registry and does not modify r1,
r2, product source, product tests, database files, migrations, dependencies or external services.
It does not activate any leaf or authorize implementation.

Authoritative r3 path:

`.codex/ccs/task_registries/local-dev-20260907/vc01b-local-20260907-r3/task-registry.json`

## Change ledger

| Leaf | Field | r2 | r3 | Basis |
|---|---|---|---|---|
| `CCS-01-003` | `allowed_paths` | broad shared root `tests` | implementation report, `runtime_paths.py`, `test_runtime_paths.py` | Historical `01-03` requires normalized config/data/db/assets/cache/temp/output/logs/credentials paths; the actual repository already has the top-level source and test parents. |
| `CCS-01-003` | `create_paths` | broad shared root `tests` | the same three exact files | Removes prefix ownership of prior tests and avoids claiming the already-existing `tests` directory. |
| `CCS-01-003` | `parent_work_package_id` | `IMP-012` | `IMP-010` | `IMP-010` owns the source package layout and runtime configuration baseline; `IMP-012` owns security/session concerns. |
| `CCS-01-003` | scope prose | generic legacy normalization text | exact runtime-path responsibility and explicit exclusions | Keeps the future work packet within the historical row and implementation-package deliverables. |
| registry | identity/digests | r2 values | r3 values | New immutable revision; r2 is not edited in place. |

No other leaf definition changed.

## Full path audit

- Runtime leaves: `176`
- Declared create/modify records: `363`
- Unique exact path strings: `362`
- Broad shared write roots (`src`, `tests`, `src/custom_content_studio`): `0`
- Globbed write paths: `0` (validated by the official checker)
- Unordered ownership conflicts: `0` (validated by the official checker)
- Existing-target create conflicts: `0` (validated by the official checker)

One exact path has two modifiers: `src/custom_content_studio/bootstrap.py`, first by
`CCS-01-001` and then by dependent leaf `CCS-01-002`. This is an intentional ordered modification:
the latter binds the scope guard into the bootstrap path created by the former. The graph proves
the ordering and the official ownership checker accepts it.

Twenty-four remaining extensionless create paths are stage-specific package roots such as
`src/custom_content_studio/ccs02` and `tests/ccs02`. They are not shared top-level grants: each has
one creator, and all nested creators are dependency-ordered after that owner. They cannot be
replaced with not-yet-existing nested files while remaining `RESOLVED`, because the official
actual-repository checker requires a nested create's parent to exist or to have been created by an
ancestor leaf. Pre-creating product directories would violate this planning-only task. Therefore
these narrow package bootstrap paths are preserved rather than converted into guessed flat module
names or fabricated product files.

## Preservation evidence

Exact file SHA-256 values after r3 creation:

- r1 bytes: `2306B3F2CC792415C55C0FE761ADAA160E177895CFF913C77FCE9CA2AE55DD2F`
- r2 bytes: `96456DF1E0946E0F11618CE3E844CB3752D16F3FF00F63E5B213136611C06DEA`
- r3 bytes: `F926727ABDAE6B954B18088399EF6C79BB4FEB17C62BEC1FFDB4C16D12762023`
- unchanged readiness report bytes: `DCAE8F32502963DE7E49A2399575871040F88472A5D0A5E62CC5FEDDF5840C11`

The r3 embedded CCS-CJSON-1 registry digest is
`11311bfb794bb6a93f38db53e505aeeccffa99e8db8b662786b570d529993704`.
The changed `CCS-01-003` leaf definition digest is
`2170557520837b15ec078f9e409eca4cc07f06dfb66091111f9c21ecbf816068`.

## Verification

| Check | Result |
|---|---|
| Official `orchestration_check.py --task-registry <r3>` | PASS — zero ownership or resolved-path errors |
| `artifact_digest.py <r3> --profile task-registry --verify` | PASS — embedded digest matches |
| `spec_sync_check.py --strict --verify-package-index` | PASS — 76 features, 363 tests, 38 invariants, 363 linked tests |

## Decision

r3 is FROZEN and suitable as the planning registry for subsequent exact work-packet preparation.
It resolves the r2 blocker without altering the already implemented `CCS-01-002` source or tests.
Commit, push, product implementation and successor activation remain separate actions.
