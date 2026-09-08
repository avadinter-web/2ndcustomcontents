# CCS-01-010 Discovery Work Packet — ServiceAccount Credential Rotation

Status: `DISCOVERY COMPLETE / CONTRACT CONFLICT / IMPLEMENTATION NOT AUTHORIZED`
Date: 2026-09-08
Repository: `E:\Custom_Contents_APP`
Inspected commit: `64c8377185dd83e013954f6ba327e889ccbd31af`
Canonical leaf: `CCS-01-010`
Current parent: `IMP-012`
Depends on: `CCS-01-009`

## 1. Decision

The r11 parent assignment is correct. `IMP-012` owns authentication, secret references and
`ActorContext`. No parent correction or new `IMP-*` package is justified.

Implementation is blocked by two task-envelope defects:

1. The task catalog adds ServiceAccount credential-reference rotation, but
   `FEATURE_REGISTRY.json`, `INVARIANT_REGISTRY.json`, `TEST_CATALOG.json` and the traceability
   matrix contain no dedicated feature, invariant, or test for it.
2. Rotation must append an audit event atomically. The schema and audit-chain contract exist, but
   r11 assigns no runtime leaf to the audit append service or to `F-043` / `INV-AUD-001` /
   `T-INT-092` / `T-INT-093`.

Those existing IDs describe the generic ordered audit stream, not credential rotation. They may
be prerequisites or regression coverage, but cannot replace the missing rotation acceptance test.
This discovery does not invent IDs, claim ownership, or authorize code.

Decision: `BLOCKED BEFORE IMPLEMENTATION — TRACEABILITY_AND_AUDIT_OWNER_REQUIRED`.

## 2. Normative evidence bindings

| Evidence | SHA-256 |
|---|---|
| r11 task registry | `EE27301ABCE28F6665CA341CE7112B1689E96D6FE6E2E2A8EBE792EC0B51ACBB` |
| `IMPLEMENTATION_REGISTRY.json` | `143A41BAB166F50ADEB888D6EEE74DE81AA18BA54559F6E0601A23C77F354D83` |
| `FEATURE_REGISTRY.json` | `7951745EDD3CB77D9DCE94560FBD3DC16727356EFFD02B1685E8A5E922ACCBB7` |
| `INVARIANT_REGISTRY.json` | `45E944A07FF5AA0AD1BF2E61007414201EB17DFF76EB84DC4DCE2A16D8CCF0AC` |
| `TEST_CATALOG.json` | `DDF6D2960B546F7643011953E03F1917FA87A434B0872B50CFD7E60B0D1FEDD9` |
| `11_CODEX_TASKS/CCS-01_TASKS.md` | `7462E0ECA03F1531F56407AF2F23729C213D8E29CDA0C68B88533E170C1F5509` |
| `09_SHARED_SPEC/AUTH_SESSION_CONTRACT.md` | `4585BEDFB91C34745CF26241684A15FA17C0B69FBCF8414BDBCDB8101282A1DC` |
| `09_SHARED_SPEC/SECURITY.md` | `A153DEF266F36A0FED673970040294950DE51FCE7DE65A522ED29DFB9F30FF68` |
| `09_SHARED_SPEC/AUDIT_CHAIN.md` | `706A2DC9A33BEB76AC3CAFEE9701573CC29EFA117A7175DDC32C64DDAF53CD29` |
| `09_SHARED_SPEC/AUDIT_RETENTION.md` | `2F3460984BE58EADCD98F0CE14361201AB890751AD9E151DE6696E67B64B2C4D` |
| `09_SHARED_SPEC/SQLITE_SCHEMA.sql` | `4D261BB1EFB3D5F3B1EBE98905DEC04BA394D9236F3A6C500CAFAA7E84D48A7F` |
| repository migration | `2B532C6FBE5B45241F2CD815B6DE4947D0A056B32754165FD06C1E9C12A2980F` |

Normative conclusions:

- `service_accounts` stores `credential_secret_ref` and `credential_rotated_at`, never a raw
  credential;
- rotation updates reference and rotation metadata under ADMIN authority and audit;
- audit events are append-only, ordered per `workspace:<workspace_id>` stream, and chained by
  predecessor hash;
- the account update and audit append share one SQLite transaction;
- `CCS-01-010` remains distinct from app-session `CCS-01-009`.

## 3. Existing implementation and exact gap

Reusable foundations exist in `domain/security/models.py`, `domain/security/policy.py`,
`application/ports/secret_store.py`, `persistence/unit_of_work.py` and
`migrations/0001_initial_v2_2.sql`. They provide masked `SecretReference`, trusted
`ActorContext`, the ADMIN-only user-role action, a caller-owned transaction, ServiceAccount
columns and audit tables/triggers.

Missing behavior is:

- ServiceAccount repository and credential-rotation service;
- audit-event append port/service/repository;
- atomic ServiceAccount update plus audit append;
- a dedicated rotation test and traceability row;
- local composition binding.

`SecretReference` also needs one explicitly named internal storage accessor. It returns only the
locator, not the secret value, and must remain excluded from representations, errors, logs, audit
payloads and public return models.

## 4. Closed local-only interface

After traceability and audit ownership are resolved:

```python
@dataclass(frozen=True)
class RotateServiceAccountCredential:
    workspace_id: str
    service_account_id: str
    new_secret_ref: SecretReference
    expected_updated_at_utc: datetime
    rotated_at_utc: datetime

@dataclass(frozen=True)
class ServiceAccountCredentialRotationResult:
    service_account_id: str
    credential_rotated_at_utc: datetime
    updated_at_utc: datetime
    audit_event_id: str

class ServiceAccountCredentialService:
    def rotate(
        self,
        actor: ActorContext,
        command: RotateServiceAccountCredential,
    ) -> ServiceAccountCredentialRotationResult: ...
```

Closed behavior:

1. validate bounded identifiers and timezone-aware UTC timestamps;
2. require a USER `ActorContext` with `Role.ADMIN`, matching Workspace and
   `SECRET_REFERENCE_MANAGE`; a scoped ServiceAccount cannot rotate itself;
3. resolve the target only by account ID plus authorized Workspace; absent and cross-Workspace
   targets both return `WORKSPACE_ACCESS_DENIED`;
4. require an existing non-null reference; initial provisioning is not rotation;
5. require a different reference and monotonically later rotation time;
6. allow ACTIVE or DISABLED account rotation without changing status or permissions;
7. compare-and-swap on exact prior `updated_at`; stale requests return
   `CONCURRENT_MODIFICATION`;
8. update only `credential_secret_ref`, `credential_rotated_at` and `updated_at`;
9. append one audit event in the same UoW and commit once;
10. roll back both writes on update, audit, or commit failure.

The service receives only `SecretReference` and never calls `SecretStorePort.resolve`. Creating,
rotating, revoking or deleting an actual credential is an external operation outside this leaf.

## 5. Closed audit event

- `stream_key = workspace:<workspace_id>`;
- `actor_type = USER` and `actor_id = ActorContext.actor_id`;
- `action = SERVICE_ACCOUNT_CREDENTIAL_ROTATED`;
- `entity_type = SERVICE_ACCOUNT` and `entity_id = service_account_id`;
- `occurred_at = rotated_at_utc`;
- `sequence_no` and `previous_event_hash` use the locked stream head;
- `event_hash` is lowercase SHA-256 over UTF-8 package canonical JSON with sorted keys and no
  insignificant whitespace, containing every stored field except `event_hash`.

`event_json` is exactly:

```json
{
  "_schema": "ccs.service-account-credential-rotation",
  "_version": 1,
  "new_secret_ref_sha256": "<lowercase sha256 of locator>",
  "old_secret_ref_sha256": "<lowercase sha256 of locator>"
}
```

It contains no locator, raw credential, authentication ID, token, email, exception text or request
payload. The generic append primitive accepts the caller-owned SQLite connection and never
commits.

## 6. Conditional exact path allowlist

Nothing below is authorized by this discovery. After contract repair, one ACTIVE packet may
create exactly:

- `src/custom_content_studio/domain/security/service_accounts.py`
- `src/custom_content_studio/application/ports/service_account_repository.py`
- `src/custom_content_studio/application/ports/audit_event_repository.py`
- `src/custom_content_studio/application/services/service_account_credentials.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/service_accounts.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/audit_events.py`
- `tests/unit/test_service_account_credentials.py`
- `tests/repository/test_service_account_repository.py`
- `tests/repository/test_audit_event_repository.py`
- `tests/integration/test_service_account_credential_rotation.py`
- `reports/IMP-012_CCS-01-010_IMPLEMENTATION.md`

It may modify exactly:

- `src/custom_content_studio/domain/security/models.py`, only for the internal locator accessor;
- the security, ports, services and SQLite-repository `__init__.py` export files;
- `src/custom_content_studio/bootstrap/composition.py`;
- `tests/unit/test_security_contract.py`, only for storage-accessor masking.

Schema, migrations, dependencies, profiles, API, UI, workers, scheduler, registries and the
specification package are excluded from the product implementation attempt.

## 7. Required local test behavior

Future tests use synthetic locators and a migrated SQLite DB under pytest `tmp_path`. They prove:

- same-Workspace USER ADMIN succeeds; other user roles, ServiceAccount actors and cross-Workspace
  actors are denied identically;
- raw synthetic credential values are never accepted and are absent from DB bytes, repr, errors,
  audit JSON and output;
- only the opaque reference is stored; only locator hashes appear in audit;
- missing/same reference, stale CAS, non-UTC and non-monotonic requests fail safely;
- status and permissions remain unchanged for ACTIVE and DISABLED accounts;
- update and audit append commit atomically and roll back together on injected failure;
- two stale rotations yield one success and one `CONCURRENT_MODIFICATION`;
- audit sequence, predecessor, stream/workspace, event hash, append-only triggers, reopen
  durability and repository no-commit behavior hold;
- no environment secret, OS credential store, network, provider, listener or runtime DB is used.

`T-INT-092` and `T-INT-093` may be regressions after their runtime owner is resolved. They do not
replace the missing dedicated rotation test ID.

## 8. Discovery verification

```powershell
$env:PYTHONDONTWRITEBYTECODE = "1"
.\.venv\Scripts\python.exe -m pytest -p no:cacheprovider `
  tests/test_sqlite_bootstrap.py `
  tests/unit/test_security_contract.py `
  tests/contract/test_secret_store_port.py
```

Observed: `25 passed in 0.57s` on CPython 3.12.10. This verifies reusable schema, policy and
secret-reference foundations only, not rotation or audit append.

## 9. Preconditions for implementation

Change control must first:

1. add or explicitly map one canonical feature for credential-reference rotation;
2. add a dedicated test ID for ADMIN-authorized atomic rotation and secret-safe audit;
3. add an invariant if rotation atomicity/reference secrecy is not represented;
4. assign one runtime owner for the generic audit append primitive and bind
   `F-043` / `INV-AUD-001` / `T-INT-092` / `T-INT-093` without duplication;
5. add that prerequisite to `CCS-01-010` or explicitly assign the narrow append implementation
   to this leaf;
6. preserve `IMP-012` and predecessor `CCS-01-009`;
7. issue an immutable successor binding exact IDs, paths, interfaces, tests and stop conditions.

Missing traceability or audit ownership returns `TASK_ENVELOPE_INCOMPLETE`. Raw credential access
returns `CREDENTIAL_SCOPE_VIOLATION`. Actual account/credential/OS-secret mutation, external
provider calls, runtime DB access, deployment and publication remain prohibited.

## 10. Current readiness

Decision: `BLOCKED BEFORE IMPLEMENTATION`.

The next safe action is specification change control plus an immutable successor resolving
rotation traceability and audit runtime ownership. No actual credential, account, OS secret,
provider, runtime database, deployment or publication state was read or changed.
