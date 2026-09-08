# IMP-012 / CCS-01-006 Implementation Report

Status: `IMPLEMENTED / SOL VERIFIED / ASTRA REVIEW PENDING`
Date: 2026-09-08
Authority: `LD00_DIRECT_USER_AUTHORIZATION` (local development only)
Attempt: `CCS-01-006-attempt-001`
Baseline commit: `98659ed230b0b5e44fd8a362a0a664a77a08961f`

## Outcome

Implemented the bounded security and app-managed session kernel defined by
`reports/CCS-01-006_DISCOVERY_WORK_PACKET.md`. The implementation provides immutable secret
references, recursive diagnostic masking, the closed role/action matrix, trusted
`ActorContext`, a secret-store protocol, a caller-owned session repository protocol, a local
SQLite adapter and issue/authenticate/rotate/revoke session service.

Bearer tokens contain 256 random bits, are returned only in the frozen issue result and are never
persisted. SQLite stores a versioned per-token salted `scrypt` digest. Token verification validates
fixed bounded parameters before hashing and uses `hmac.compare_digest`. A token carries only its
random session identifier plus bearer entropy so lookup does not require raw-token persistence.

Authentication derives the current user state and Workspace role from the database. User scopes
can narrow role permissions, service-account scopes are exact and roles cannot broaden them, and
Workspace mismatch or insufficient permission returns the same metadata-safe
`WORKSPACE_ACCESS_DENIED` code. Rotation inserts a same-family successor and irreversibly revokes
the predecessor in one caller-owned `SQLiteUnitOfWork`.

## Exact changed paths

Attempt authority records created before implementation:

- `.codex/ccs/local_work_packets/CCS-01-006-attempt-001.md`
- `.codex/ccs/local_decisions/LD00-CCS-01-006-attempt-001.md`

Source paths created:

- `src/custom_content_studio/domain/__init__.py`
- `src/custom_content_studio/domain/security/__init__.py`
- `src/custom_content_studio/domain/security/models.py`
- `src/custom_content_studio/domain/security/policy.py`
- `src/custom_content_studio/application/__init__.py`
- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/application/ports/secret_store.py`
- `src/custom_content_studio/application/ports/session_repository.py`
- `src/custom_content_studio/application/services/__init__.py`
- `src/custom_content_studio/application/services/sessions.py`
- `src/custom_content_studio/infrastructure/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/sessions.py`

One existing composition path modified:

- `src/custom_content_studio/bootstrap/composition.py`

Tests and evidence created:

- `tests/unit/test_security_contract.py`
- `tests/contract/test_secret_store_port.py`
- `tests/repository/test_session_repository.py`
- `tests/integration/test_session_service.py`
- `reports/IMP-012_CCS-01-006_IMPLEMENTATION.md`

No schema, migration, manifest, dependency, lockfile, environment profile, API, UI, worker,
scheduler, registry or specification file was changed.

## Verification

Commands ran from `E:\Custom_Contents_APP` with the repository's CPython 3.12 virtual environment:

```powershell
.\.venv\Scripts\python.exe -m pytest tests/unit/test_security_contract.py tests/contract/test_secret_store_port.py tests/repository/test_session_repository.py tests/integration/test_session_service.py
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m ruff check src tests
.\.venv\Scripts\python.exe -m ruff format --check src tests
.\.venv\Scripts\python.exe -m mypy src
git diff --check
```

Results:

- leaf tests: `27 passed`
- full regression: `90 passed`
- Ruff lint: `PASS`
- Ruff format: `PASS`, 54 files checked
- mypy strict: `PASS`, 42 source files checked
- Git whitespace check: `PASS`; only pre-existing CRLF conversion warnings were emitted for
  unrelated modified reports and the permitted composition file
- runtime/application database creation: none outside pytest `tmp_path`

Direct acceptance coverage includes `T-010`, `T-011` and `T-INT-137`. Tests also verify the exact
role/action matrix, scope narrowing, safe denial details, nested masking, closable synthetic
secret leases, hash-only persistence, malformed-token rejection, constant-time digest compare,
immutable session identity, reason-bound one-way revocation, durable rotation linkage, rollback
without caller commit, role changes, membership removal, disabled users, expiry and cross-Workspace
denial.

## Evidence hashes

| Evidence | SHA-256 |
|---|---|
| r7 registry file | `3E9F6DE7301AC9D60E660B5E3BA7802F4A1ABBB07144D7876C7EC00DCC8E51C9` |
| discovery packet | `B19C5DE6E064DB201F8577A759C9841E12015F7B8371EE14F2624AF132169FFF` |
| local work packet | `2DD660B4D5BCA91B07AFC733D71C530D1823F85DCEB2B8645C7A4822DA577F0B` |
| local decision | `13892949531AE03811D2378D9E36675FE8CD0C92529010E01E06EA6D447393C5` |
| security models | `724F422D0E0448C43F506B5321FC96908A520E647EF288B069BEB3DFE41DE59A` |
| security policy | `163A37DD2B9EA68EE5BEBD6C9B99FDFD93FB3E5A6F710CDE500EDA5A8C209A1C` |
| session service | `11E452D052EAEAFED085E0F0EBC82C3C161F8207CA1FC488B099A4FB4CA4F601` |
| SQLite session repository | `943EBBE32FB9AA6206F5A1C6A2E8D186009C5CA85A9D374E8000EF7EF6A3BB7C` |
| unit tests | `EE43CD2EC0FE94BEB18D26DB22E6DDD40882ADB596B91343102CBC4BE37DC858` |
| contract tests | `89A6C284EF9C99C40CC2623EF14B6529819840D7F46C77EBD09092737D4A3C15` |
| repository tests | `EC92DF483F8CBC47B30DE7684721EBAB567730993889CF0308448AD2BA7A947B` |
| integration tests | `2CD27A63BE167B26EC9E77E217E10AB17A35E65A26FEDA9BBBACE0278EFA3E72` |

The implementation report's own digest is intentionally computed by Astra after final review.

## Safety and preserved state

- No real credential, `.env`, OS credential store, provider account, tenant, environment variable
  secret or external identity service was read or changed.
- No listener, provider adapter, reverse-proxy trust, DEV actor injection, OAuth flow, publication,
  deployment, billing or network action was enabled.
- Session scenarios used synthetic identities and SQLite files beneath pytest temporary paths only.
- The pre-existing untracked `migrations/$/0001_initial_v2_2.sql` path was present before this
  attempt. It is outside the allowlist and was neither modified nor deleted.
- Pre-existing modified/untracked reports, operations documents and r4 registry remain untouched.

## Deferred scope

Transport authentication middleware, reverse-proxy trust, DEV actor injection, concrete OS or
provider secret adapters, OAuth exchange/refresh/revoke and downstream content/review/timeline
authorization remain separate leaves. `T-INT-114..117`, `T-120` and `T-OPS-010` are not claimed
complete by this unit.

## Rollback and review decision

Before commit, remove only the two attempt records, fourteen new source files, four new test files
and this report, then restore only the permitted composition diff. Preserve all pre-existing dirty
paths. After commit, use a separately reviewed Git revert; never reset or rewrite the existing
schema/migration history.

Sol implementation verification: `PASS`.

Astra must independently review the exact allowlist, security semantics, test results, final
hashes, r7/discovery immutability and unrelated dirty-state preservation before selective commit
and non-force push.
