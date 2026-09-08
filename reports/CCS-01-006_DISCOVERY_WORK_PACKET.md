# CCS-01-006 Discovery Work Packet

Status: `DRAFT / DISCOVERY COMPLETE / IMPLEMENTATION NOT AUTHORIZED BY R6`
Date: 2026-09-08
Canonical leaf: `CCS-01-006`
Canonical parent work package: `IMP-012`
Repository: `E:\\Custom_Contents_APP`
Repository baseline inspected: `74848c7`
Authority profile: `LD00_DIRECT_USER_AUTHORIZATION` (local development only)

## 1. Decision and ownership correction

This packet resolves the exact local implementation boundary for secret references, app-managed
sessions, role authorization and `ActorContext`. The normative `IMPLEMENTATION_REGISTRY.json`
assigns these responsibilities to `IMP-012`, whose title is "Authentication, secret references
and ActorContext" and whose dependency is `IMP-011`.

Registry r6 still labels `CCS-01-006` as `IMP-011`. That entry is a non-executable discovery
placeholder: it has `path_resolution_status=DISCOVERY_REQUIRED`, no allowed paths, and
`implementation_authorized=false`. It conflicts with the normative implementation registry and
must not be treated as implementation authority. A successor immutable registry/work-packet
revision must bind this leaf to `IMP-012` before code dispatch. r6 remains byte-identical and is
not edited by this discovery task.

The implementation is local-only. It may use synthetic identities and synthetic secret material
inside tests, with SQLite files limited to pytest `tmp_path`. It must not create, read, rotate,
revoke or otherwise change any real credential, user account, provider account, operating-system
credential entry, `.env` value or runtime database.

## 2. Normative evidence bindings

| Evidence | SHA-256 |
|---|---|
| r6 task registry | `75F316ED32E672A1143909AFA96ADD5C88E9A9694D4ED3A6F97CE09736F96CF8` |
| specification `IMPLEMENTATION_REGISTRY.json` | `143A41BAB166F50ADEB888D6EEE74DE81AA18BA54559F6E0601A23C77F354D83` |
| specification `09_SHARED_SPEC/AUTH_SESSION_CONTRACT.md` | `4585BEDFB91C34745CF26241684A15FA17C0B69FBCF8414BDBCDB8101282A1DC` |
| specification `09_SHARED_SPEC/SECURITY.md` | `A153DEF266F36A0FED673970040294950DE51FCE7DE65A522ED29DFB9F30FF68` |
| specification `09_SHARED_SPEC/PORT_AND_ADAPTER_INTERFACES.md` | `2240455954FD30C465D21943B7C1FE313E4FD7BAD6D6962D1DA4522043935456` |
| specification `09_SHARED_SPEC/APPLICATION_SERVICE_CONTRACTS.md` | `D12FBE2DC2A8AD14BA11CA716B3356C769B5FBF512E88D2CD0F3714CEFD2D9BD` |
| specification `09_SHARED_SPEC/SQLITE_SCHEMA.sql` | `4D261BB1EFB3D5F3B1EBE98905DEC04BA394D9236F3A6C500CAFAA7E84D48A7F` |

Normative interpretation:

- `CCS-01-006` owns secret references, basic roles and masking.
- `IMP-012` owns the session service, secret-store port, workspace authorization middleware and
  audit-safe request context.
- the database stores only session token hashes and secret references;
- request identity comes from authenticated context, never trusted JSON fields;
- every authorization check validates active identity, current Workspace scope and action;
- cross-Workspace denial reveals no protected resource metadata;
- session rotation creates a new session and revokes the old one; revocation is one-way.

## 3. Exact implementation allowlist

A future implementation attempt may create exactly these source and test files:

| Path | Sole responsibility |
|---|---|
| `src/custom_content_studio/domain/security/__init__.py` | Curated public security-domain exports |
| `src/custom_content_studio/domain/security/models.py` | `ActorType`, `Role`, `Action`, `SecretReference`, `ActorContext`, session value models |
| `src/custom_content_studio/domain/security/policy.py` | Closed role/action matrix and pure Workspace authorization checks |
| `src/custom_content_studio/application/ports/__init__.py` | Curated application-port exports |
| `src/custom_content_studio/application/ports/secret_store.py` | `SecretStorePort` and lease protocol only; no adapter or value |
| `src/custom_content_studio/application/ports/session_repository.py` | Session repository protocol used by the service |
| `src/custom_content_studio/application/services/__init__.py` | Curated service exports |
| `src/custom_content_studio/application/services/sessions.py` | Issue, authenticate, rotate and revoke app sessions |
| `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py` | Curated repository exports |
| `src/custom_content_studio/infrastructure/sqlite/repositories/sessions.py` | SQLite session repository over caller-owned UoW connection |
| `tests/unit/test_security_contract.py` | ActorContext, role/action and masking tests |
| `tests/repository/test_session_repository.py` | Hash-only persistence and one-way session lifecycle tests on `tmp_path` |
| `tests/contract/test_secret_store_port.py` | Deterministic fake contract and redaction tests using synthetic values |
| `tests/integration/test_session_service.py` | Local service/UoW authentication, rotation, revocation and cross-Workspace tests |
| `reports/IMP-012_CCS-01-006_IMPLEMENTATION.md` | Commands, exact changed paths, results, hashes and Astra decision |

The implementation attempt may modify exactly one existing file:

| Path | Permitted change |
|---|---|
| `src/custom_content_studio/bootstrap/composition.py` | Bind only the local session repository and security services; do not enable a listener or provider |

Parent package `__init__.py` files for `domain`, `application`, `infrastructure` and
`infrastructure/sqlite` may be created only if absent and must remain empty except for a module
docstring. No other path is writable. In particular, the schema, migration manifest,
`pyproject.toml`, lockfile, environment profiles, API/UI/worker/scheduler, r1-r6 registries and
specification package are outside this leaf.

## 4. Closed public contract

### 4.1 Secret references and masking

`SecretReference` is an immutable opaque locator. It accepts a non-empty trimmed string, rejects
ASCII control characters and line breaks, and stores it in a field excluded from dataclass
`repr`. Its `str()` and `repr()` return the fixed marker `[SECRET_REF]`, never the locator.
Equality and hashing may compare the locator without exposing it.

`SecretStorePort` is the only application boundary allowed to resolve a locator:

```python
class SecretStorePort(Protocol):
    def resolve(self, secret_ref: SecretReference) -> SecretLease: ...

class SecretLease(Protocol):
    def reveal(self) -> str: ...
    def close(self) -> None: ...
    def __enter__(self) -> SecretLease: ...
    def __exit__(self, ...) -> None: ...
```

This leaf provides no concrete production, OS, file or external SecretStore adapter. Tests use a
deterministic in-test fake with an unmistakably synthetic value. The fake lease must be closed by
context management and its `repr`, exceptions and assertion diagnostics must never include the
synthetic raw value.

The masking helper accepts structured mappings/sequences and strings used for safe errors/log
fields. Keys containing `authorization`, `cookie`, `token`, `secret`, `password`, `credential`,
`api_key`, `access_key`, `refresh` or `pkce` are replaced with `[REDACTED]`; matching is
case-insensitive after replacing `-` with `_`. It recursively returns a new value and never
mutates input. This is defense in depth, not permission to log a secret.

### 4.2 ActorContext and role/action policy

The closed enums are:

```text
ActorType = USER | SERVICE_ACCOUNT
Role      = ADMIN | EDITOR | REVIEWER | VIEWER
Action    = WORKSPACE_READ | WORKSPACE_ADMIN | INTEGRATION_MANAGE |
            SECRET_REFERENCE_MANAGE | WORKER_MANAGE | KILL_SWITCH_MANAGE |
            CONTENT_EDIT | BENCHMARK_EDIT | GENERATION_REQUEST |
            DESIGN_EDIT | RENDER_REQUEST | REVIEW_DECIDE |
            RENDER_READ | PUBLICATION_READ | ANALYTICS_READ
```

`ActorContext` is immutable and contains exactly:

```text
actor_type: ActorType
actor_id: str
authentication_id: str          # session ID or service-account ID, never bearer material
workspace_id: str
roles: frozenset[Role]
scopes: frozenset[str]
authenticated_at_utc: timezone-aware datetime
```

All identifiers are non-empty. `authenticated_at_utc` must be UTC and timezone-aware. The object
contains no token, token hash, email, cookie, secret reference or raw authorization header.
Callers cannot override its identity fields from request payloads.

The role/action matrix is closed:

| Role | Allowed actions |
|---|---|
| `ADMIN` | all actions in this packet |
| `EDITOR` | `WORKSPACE_READ`, `CONTENT_EDIT`, `BENCHMARK_EDIT`, `GENERATION_REQUEST`, `DESIGN_EDIT`, `RENDER_REQUEST`, `RENDER_READ`, `PUBLICATION_READ`, `ANALYTICS_READ` |
| `REVIEWER` | `WORKSPACE_READ`, `REVIEW_DECIDE`, `RENDER_READ`, `PUBLICATION_READ`, `ANALYTICS_READ` |
| `VIEWER` | `WORKSPACE_READ`, `RENDER_READ`, `PUBLICATION_READ`, `ANALYTICS_READ` |

`require_action(actor, workspace_id, action)` first compares the trusted ActorContext Workspace,
then evaluates role/action membership. Workspace mismatch always raises
`WORKSPACE_ACCESS_DENIED`; insufficient action permission raises the same stable code. Safe error
details may contain only the requested action code. They must not contain the target Workspace,
actor ID, resource ID or existence information.

Service accounts use explicit `scopes`; an action is allowed only when its exact lowercase action
code is present. Their optional role set cannot broaden scopes. User actors use the role matrix;
scopes may narrow but never broaden role permissions when non-empty.

### 4.3 App-managed session service

The service uses Python 3.12 standard-library `secrets`, `hashlib` and `hmac`; no new dependency
is allowed. A newly issued bearer token contains at least 256 random bits and is returned exactly
once by an immutable issue result. It is never persisted or logged.

The stored `session_token_hash` has a versioned, self-describing format containing algorithm,
cost parameters, per-token random salt and derived digest. The implementation uses
`hashlib.scrypt` and constant-time `hmac.compare_digest`. Authentication parses and validates
bounded parameters before hashing. Malformed or unsupported encodings fail as
`AUTHENTICATION_REQUIRED` without echoing input.

The session service exposes:

```text
issue(user_id, now_utc, expires_at, client_fingerprint_hash?, user_agent_hash?)
  -> IssuedSession(session_id, session_family_id, raw_token_once, expires_at)
authenticate(raw_token, workspace_id, now_utc)
  -> ActorContext
rotate(raw_token, now_utc, expires_at)
  -> IssuedSession
revoke(session_id, reason, now_utc)
  -> None
```

Rules:

- `issue` inserts exactly one session with only the encoded hash and metadata.
- `authenticate` rejects absent/malformed tokens as `AUTHENTICATION_REQUIRED`; expired, revoked,
  disabled-user or inactive-membership cases use `SESSION_EXPIRED` or
  `WORKSPACE_ACCESS_DENIED` per the domain error catalog.
- it derives role and Workspace from current DB membership; input `workspace_id` grants nothing.
- `rotate` authenticates first, inserts a new row in the same family linked through
  `rotated_from_session_id`, then revokes the old row in one UoW.
- `revoke` is idempotent only for the same non-empty reason. Clearing/changing `revoked_at` or
  changing the reason is rejected; no un-revoke method exists.
- session identity, token hash, family, predecessor, creation and expiry are immutable after
  insert. `last_seen_at` may only move forward.
- session repository methods receive the caller-owned SQLite connection and never commit.

DEV actor injection and reverse-proxy authentication are not implemented here. They require
separate transport trust contracts. OAuth exchange/refresh/revoke and provider credentials are
also excluded.

## 5. Exact owned tests and traceability

`tests/unit/test_security_contract.py` must prove:

1. every role/action pair matches the closed matrix;
2. Workspace mismatch and disallowed actions return `WORKSPACE_ACCESS_DENIED` with safe details;
3. user scopes only narrow permissions and service-account scopes never broaden;
4. ActorContext rejects invalid IDs/non-UTC timestamps and has a secret-free representation;
5. secret-reference and nested masking never expose locator or synthetic raw secret.

`tests/repository/test_session_repository.py` must prove:

1. a fresh migrated `tmp_path` DB stores no raw token and exactly one versioned token hash;
2. lookup verifies correct token, rejects incorrect/malformed token and uses constant-time compare;
3. immutable session identity fields cannot change;
4. revocation is one-way and reason-bound;
5. rotation linkage/family is durable across reopen and the old token no longer authenticates;
6. repository methods do not commit outside the caller's `SQLiteUnitOfWork`.

`tests/contract/test_secret_store_port.py` must prove the in-test fake returns a closable lease,
unknown references fail with a stable non-secret error, and raw synthetic values are absent from
`repr`, logs and exceptions. No test accesses OS credentials, files outside `tmp_path`, network or
process environment secrets.

`tests/integration/test_session_service.py` must prove issue/authenticate/rotate/revoke, inactive
user rejection, expired/revoked rejection, current-role changes, membership removal and
cross-Workspace denial against a migrated temporary database.

Feature ownership is `F-003`, `F-051` and `F-059`. This leaf directly owns `T-010`, `T-011` and
`T-INT-137`. `T-INT-114..117` depend on later review/timeline/content application services and are
regression/deferred integration tests, not falsely claimed complete here. `T-120` and
`T-OPS-010` remain CCS-12 end-to-end masking/operations checks; this leaf supplies the reusable
masking primitive only.

## 6. Safety and approval boundary

Discovery and a bounded local implementation using only synthetic test data require no separate
credential or provider-account approval. The user's standing local-development direction is
sufficient after the registry/work-packet ownership correction and exact attempt binding.

The following remain prohibited and are not pre-approved: adding/changing/deleting real API keys,
OAuth tokens, passwords, service-account credentials, Windows Credential Manager entries,
provider accounts, tenant membership or account permissions; reading existing `.env`/credential
stores; connecting to an external identity/provider service; and using an existing/runtime DB.
Any such action is a new scope and requires a separate explicit approval with exact target and
effect. No implementation should pause merely to request credentials, because this packet
