# CCS-01-005 Discovery Work Packet

Status: `DRAFT / DISCOVERY COMPLETE / IMPLEMENTATION NOT AUTHORIZED BY R6`
Date: 2026-09-08
Canonical leaf: `CCS-01-005`
Parent work package: `IMP-011`
Repository: `E:\\Custom_Contents_APP`
Repository baseline inspected: `c14f6c62dc8d8f3890e8444465f91070ebb09d73`
Authority profile: `LD00_DIRECT_USER_AUTHORIZATION` (local development only)

## 1. Decision

This packet resolves the source, migration, test, and interface discovery requested by r6 for
`CCS-01-005`. The implementation is a local-only SQLite bootstrap and transaction kernel. It
must use Python 3.12's standard-library `sqlite3`; no new package or service is introduced.

The packet is deliberately not an `ACTIVE` trusted-dispatcher receipt. Registry r6 remains
`DRAFT`, `NOT_EVALUATED`, `implementation_authorized=false`, and records this leaf as
`DISCOVERY_REQUIRED` with no writable paths. Therefore r6 itself authorizes no mutation. Before
implementation, Astra must issue a separate attempt-scoped local work packet/decision record that
copies this exact allowlist and binds the user's active-conversation decision under
`LD00_DIRECT_USER_AUTHORIZATION`. That local authority permits only the bounded implementation
below and never changes r6 in place.

## 2. Normative evidence bindings

| Evidence | SHA-256 |
|---|---|
| r6 task registry | `75F316ED32E672A1143909AFA96ADD5C88E9A9694D4ED3A6F97CE09736F96CF8` |
| `reports/CCS-01-005_CONFLICT_RESOLUTION.md` | `DF917C0DBBB86BBFB3FAE97D2D358D68B69A2F3EEB78D6B19A95B14984EEEC2F` |
| specification `IMPLEMENTATION_REGISTRY.json` | `143A41BAB166F50ADEB888D6EEE74DE81AA18BA54559F6E0601A23C77F354D83` |
| specification `09_SHARED_SPEC/MIGRATION_PROTOCOL.md` | `043DA35E1E4690D7387894042B66CA3282607E2DDE9FB62DD3950B417260C941` |
| specification `09_SHARED_SPEC/SQLITE_SCHEMA.sql` | `4D261BB1EFB3D5F3B1EBE98905DEC04BA394D9236F3A6C500CAFAA7E84D48A7F` |
| specification `09_SHARED_SPEC/PORT_AND_ADAPTER_INTERFACES.md` | `2240455954FD30C465D21943B7C1FE313E4FD7BAD6D6962D1DA4522043935456` |
| specification `09_SHARED_SPEC/TRANSACTION_AND_CONCURRENCY.md` | `F3AE00F93C3C3BDED6972912F4DC83363BE2F5BB8A23BD042138395CCE38F558` |

Normative interpretation:

- `01-05` requires durable SQLite initialization and restart verification.
- `IMP-011` owns the migration manifest, schema bootstrap, `UnitOfWork`, and connection PRAGMAs.
- Every connection must set and verify `foreign_keys=ON`, WAL mode, and a 5000 ms busy timeout.
- One application transaction uses `BEGIN IMMEDIATE`; commit is explicit and exceptions roll back.
- Applied migration identity is immutable and a checksum mismatch fails closed as
  `MIGRATION_CHECKSUM_MISMATCH`.

## 3. Exact implementation allowlist

The implementation attempt may create exactly these files:

| Path | Sole responsibility |
|---|---|
| `migrations/manifest.json` | Ordered migration index and expected raw-file SHA-256 |
| `migrations/0001_initial_v2_2.sql` | Immutable initial v2.2 domain schema DDL |
| `src/custom_content_studio/persistence/__init__.py` | Public persistence exports only |
| `src/custom_content_studio/persistence/sqlite.py` | Connection factory, PRAGMA verification, database bootstrap facade |
| `src/custom_content_studio/persistence/migrations.py` | Manifest parser, checksum validation, `schema_migrations`, fresh-DB runner |
| `src/custom_content_studio/persistence/unit_of_work.py` | SQLite `UnitOfWork` context and transaction lifecycle |
| `tests/test_sqlite_bootstrap.py` | Fresh bootstrap, manifest, drift, rollback, restart, PRAGMA tests |
| `tests/test_unit_of_work.py` | Commit, explicit rollback, exception rollback, closed-connection tests |
| `reports/IMP-011_CCS-01-005_IMPLEMENTATION.md` | Actual changed paths, commands, results, hashes, known issues, rollback evidence |

No existing source, configuration, README, lockfile, test, report, registry, or specification file
is writable in this attempt. In particular, the existing bootstrap/composition root remains
side-effect-free; wiring persistence into all application entrypoints is a later separately
authorized leaf.

## 4. Canonical artifacts and formats

### 4.1 Migration manifest

`migrations/manifest.json` has this closed shape; additional top-level or migration keys fail
validation:

```json
{
  "_schema": "ccs.sqlite.migration-manifest",
  "_version": 1,
  "application_version": "0.0.0",
  "migrations": [
    {
      "version": 1,
      "name": "initial_v2_2",
      "path": "0001_initial_v2_2.sql",
      "checksum_sha256": "<64 lowercase hex characters computed from the committed raw bytes>"
    }
  ]
}
```

Rules:

- Versions are positive integers, unique, and strictly increasing without gaps.
- Names match `[a-z0-9_]+`; paths are direct child filenames and match
  `<version:04d>_<name>.sql`.
- Absolute paths, parent traversal, symlinks escaping `migrations/`, duplicate entries, unknown
  keys, malformed digests, missing files, and unlisted SQL files fail closed.
- The application version is the current project version from `pyproject.toml`, `0.0.0`.
- The checksum is over the file's raw bytes, not newline-normalized text.

### 4.2 Initial schema

`migrations/0001_initial_v2_2.sql` contains the complete ordered DDL from the bound
`09_SHARED_SPEC/SQLITE_SCHEMA.sql`, except its connection-scoped first statement
`PRAGMA foreign_keys = ON;` is omitted. The connection factory owns and verifies that PRAGMA
before any transaction. No domain table, index, trigger, view, constraint, or ordering may be
invented, omitted, or edited during the copy.

The runner owns the infrastructure table below separately from domain DDL:

```sql
CREATE TABLE schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  checksum_sha256 TEXT NOT NULL,
  started_at TEXT NOT NULL,
  applied_at TEXT,
  status TEXT NOT NULL CHECK(status IN ('APPLYING','APPLIED','FAILED')),
  application_version TEXT NOT NULL
);
```

Fresh-schema equivalence compares all domain objects to the bound canonical schema and excludes
only the runner-owned `schema_migrations` table. Timestamp values are UTC RFC 3339 strings.
Successful migration state is exactly one `APPLIED` row for version 1 with the manifest name,
checksum, and application version.

### 4.3 Python interfaces

The implementation exposes only these leaf-level responsibilities:

- `SQLiteConnectionFactory(database_path: Path, *, busy_timeout_ms: int = 5000)` validates an
  absolute file path and returns a `sqlite3.Connection` configured with explicit transaction
  control. `connect()` executes and verifies `PRAGMA foreign_keys=ON`,
  `PRAGMA journal_mode=WAL`, and `PRAGMA busy_timeout=5000`; a mismatch closes the connection and
  raises a typed persistence error.
- `load_manifest(migrations_root: Path)` parses the closed manifest, validates ordering and safe
  relative paths, reads raw SQL bytes, and validates every SHA-256 before returning immutable
  migration values.
- `MigrationRunner(factory, migrations_root).migrate_fresh()` accepts only a nonexistent or empty
  newly created database selected by the caller. It creates the runner table, applies pending
  migration 0001 in `BEGIN IMMEDIATE`, records `APPLYING` then `APPLIED`, and validates
  `integrity_check`, `foreign_key_check`, and the final manifest state before commit/return.
- Reopening the same test database verifies the recorded version/name/checksum and performs no DDL
  or duplicate insert. Changed applied bytes raise `MIGRATION_CHECKSUM_MISMATCH` before domain
  mutation.
- `SQLiteUnitOfWork(factory)` implements `__enter__`, `commit()`, `rollback()`, and `__exit__`.
  Enter opens one connection and issues `BEGIN IMMEDIATE`; commit must be explicit. Normal exit
  without commit and exceptional exit both roll back. Exit always closes the connection.

The concrete exception hierarchy remains internal to `persistence`; stable public error codes are
`DATABASE_CONFIGURATION_FAILED`, `MIGRATION_MANIFEST_INVALID`,
`MIGRATION_CHECKSUM_MISMATCH`, `MIGRATION_REQUIRED`, and `DATABASE_INTEGRITY_FAILED`. Raw
`sqlite3` exceptions must not cross the package boundary.

## 5. Safety boundary

This attempt may create and mutate SQLite files only beneath pytest's per-test `tmp_path`. Tests
must assert that each target path is inside that fresh temporary directory before opening it.
No test or command may point to `.runtime/DEV`, `.runtime/STAGING`, `.runtime/PROD`, a user-selected
database, a copied customer database, or any pre-existing SQLite file.

Because the authorized scenario is fresh temporary initialization only:

- an existing nonempty database without the exact version-1 record fails closed with
  `EXISTING_DATABASE_NOT_AUTHORIZED`;
- an existing migrated temporary test database may only be reopened for no-op checksum/restart
  verification;
- no backup/restore, table rebuild, data backfill, maintenance lock, production preflight, or
  forward-fix is performed;
- failure injection is limited to an alternate malformed migration fixture under `tmp_path`; it
  must prove transaction rollback and must not modify committed migration assets;
- no external I/O occurs in a migration transaction.

The full existing-database path in `MIGRATION_PROTOCOL.md` requires a later migration packet with
backup evidence and separate authority. This leaf does not waive that protocol.

## 6. Forbidden paths and actions

Forbidden paths include every path not listed in section 3, especially:

- `.runtime/**`, `.env`, `config/**`, `pyproject.toml`, `requirements.lock`, `README.md`;
- `.codex/**`, all r1-r6 registry content, specification package content, and existing reports;
- `src/custom_content_studio/bootstrap/**`, API/UI/CLI/worker/scheduler modules, and domain feature
  modules;
- existing tests and any credential, key, token, media, output, or user data path.

Forbidden actions:

- migrating, opening, copying, backing up, deleting, renaming, or replacing an existing runtime or
  user database;
- deployment, publication, external transmission, provider calls, remote updates, credential/API
  key changes, billing, or production/staging actions;
- dependency installation or lockfile regeneration;
- manual edits to `schema_migrations`, checksum bypass, foreign-key disabling, destructive Git
  operations, force push, or automatic successor activation.

The user's standing commit/push delivery policy applies only after Astra verifies this exact leaf.
A normal non-force push of the verified commit is delivery, not authority for external product
effects.

## 7. Exact owned tests

`tests/test_sqlite_bootstrap.py` must cover:

1. a fresh `tmp_path` database applies manifest version 1 and contains the exact canonical domain
   schema plus runner-owned `schema_migrations`;
2. every opened connection reports `foreign_keys=1`, `journal_mode=wal`, and
   `busy_timeout=5000`;
3. reopening preserves a sentinel row created by the test and leaves one unchanged `APPLIED`
   migration record;
4. changing copied migration bytes in an isolated `tmp_path` fixture raises
   `MIGRATION_CHECKSUM_MISMATCH` before domain mutation;
5. malformed/gapped/duplicate/unsafe manifest entries and unlisted SQL files fail closed;
6. injected failing migration SQL rolls back its schema/data changes and does not record
   `APPLIED`;
7. `PRAGMA integrity_check` returns `ok` and `foreign_key_check` returns no rows;
8. an unrelated pre-existing nonempty database is rejected without schema mutation.

`tests/test_unit_of_work.py` must cover:

1. explicit commit persists after close/reopen;
2. explicit rollback does not persist;
3. exception exit rolls back and preserves the original state;
4. normal exit without commit rolls back;
5. commit/rollback/use after exit fails predictably and the underlying connection is closed;
6. two concurrent writers honor the 5000 ms busy timeout without changing PRAGMA policy.

Owned acceptance mappings are `MIG-001`, `MIG-002`, `MIG-004`, and contract test `T-DB-001`.
`MIG-003` and `MIG-005..008` require backfill, backup/restore, remote-state, rebuild, or concurrent
old-writer scenarios and remain explicitly deferred. This infrastructure leaf completes no user
feature and claims no feature-progress increment.

## 8. Verification commands

Run from `E:\\Custom_Contents_APP` with the repository-local interpreter only:

```powershell
.\\.venv\\Scripts\\python.exe -m pytest tests/test_sqlite_bootstrap.py tests/test_unit_of_work.py
.\\.venv\\Scripts\\python.exe -m pytest
.\\.venv\\Scripts\\python.exe -m ruff check src tests
.\\.venv\\Scripts\\python.exe -m mypy src
git diff --check
git status --short
```

Astra additionally verifies that changed paths equal the section 3 allowlist, no database file is
tracked or left under `.runtime`, the manifest checksum matches raw migration bytes, r6 remains
byte-identical to its bound hash, and unrelated dirty files remain untouched.

## 9. Completion criteria

This leaf is complete only when all of the following are true:

- only the nine allowlisted files changed in the implementation unit;
- the canonical initial schema and runner table are applied to a fresh temporary database;
- restart/no-op, drift rejection, failure rollback, integrity/FK, and UnitOfWork tests pass;
- the full pytest suite, Ruff, strict mypy, and `git diff --check` pass;
- no existing/runtime database, external service, secret, registry, or specification was mutated;
- the implementation report records commands, results, hashes, deferred protocol cases, and an
  Astra gate decision;
- the verified unit is committed and non-force pushed under the user's standing policy, with
  `HEAD == origin/master` recorded.

## 10. Rollback and stop criteria

Before commit, rollback means deleting only newly created allowlisted source/migration/test/report
files after verifying their exact paths; pre-existing user changes are never reverted. After
commit, use a separately reviewed Git revert, never reset/clean or migration-file rewriting.
Temporary test directories are pytest-owned and disposable; no persistent DB rollback is in
scope.

Stop immediately with the stated code when:

- r6/evidence hash or repository baseline differs before dispatch: `SPEC_DIGEST_MISMATCH`;
- the local packet/decision record, allowlist, single writer, or gate evidence is incomplete:
  `TASK_ENVELOPE_INCOMPLETE` or `LOCAL_DEVELOPMENT_GATE_MISMATCH`;
- any pre-existing database would be opened or mutated: `EXISTING_DATABASE_NOT_AUTHORIZED`;
- canonical SQL cannot be copied without semantic change or schema equivalence fails:
  `DATABASE_INTEGRITY_FAILED`;
- an applied migration checksum differs: `MIGRATION_CHECKSUM_MISMATCH`;
- work requires a path/action outside this packet, a new dependency, or an external/production
  effect: stop and issue a new change-controlled packet; do not infer expanded authority.

## 11. Next orchestration action

Astra may use this discovery result to create one immutable successor registry/work-packet
revision for `CCS-01-005` and record the active-conversation local user decision. Only that
attempt-scoped record may dispatch one Sol writer. This document alone is not executable and does
not authorize `CCS-01-006` or any successor leaf.
