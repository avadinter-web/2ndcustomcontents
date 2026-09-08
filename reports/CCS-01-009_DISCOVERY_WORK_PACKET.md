# CCS-01-009 Discovery Work Packet — Session Security Evidence Closure

Status: `DISCOVERY COMPLETE / PRODUCT DELTA NOT REQUIRED / IMPLEMENTATION NOT AUTHORIZED`
Date: 2026-09-08
Repository: `E:\Custom_Contents_APP`
Inspected commit: `58c76db8f0a85d35b1a0182079ed36903566c969`
Canonical leaf: `CCS-01-009`
Canonical parent: `IMP-012`
Depends on: `CCS-01-007`
Required outcome: app-managed Session token hash, rotation family, and one-way revocation.

## 1. Decision

`CCS-01-009` requires no new product source, migration, or test implementation. Its complete
normative behavior was already implemented under `CCS-01-006` at commit
`c2b03c6e90ef51d3d1fa9d22cd1a90a1664865ad`. The historical `CCS-01-006` work packet included
the later-added session requirement before the immutable task registry gave that requirement its
own canonical leaf.

The correct repair is not to duplicate the session service or create parallel tests. A future
immutable successor must re-scope `CCS-01-009` as a non-executable evidence-closure leaf:

- canonical requirement ownership: `CCS-01-009`;
- implementation provenance: completed `CCS-01-006` commit and exact artifact hashes;
- semantic parent: `IMP-012`;
- feature: `F-059`;
- invariant: `INV-AUTH-001`;
- introducing and required test: `T-INT-137`;
- product write paths: none.

This packet does not change r10, does not mark the leaf accepted, and does not authorize any
repository write other than this discovery report. Acceptance requires an immutable successor
that binds this decision and the exact evidence below.

## 2. Normative evidence bindings

| Evidence | SHA-256 |
|---|---|
| r10 task registry | `D4E3E20F3EA00D24748B9BA8738EB23BEE354F71EF592DF1625847E83DBE30BE` |
| `IMPLEMENTATION_REGISTRY.json` | `143A41BAB166F50ADEB888D6EEE74DE81AA18BA54559F6E0601A23C77F354D83` |
| `11_CODEX_TASKS/CCS-01_TASKS.md` | `7462E0ECA03F1531F56407AF2F23729C213D8E29CDA0C68B88533E170C1F5509` |
| `09_SHARED_SPEC/AUTH_SESSION_CONTRACT.md` | `4585BEDFB91C34745CF26241684A15FA17C0B69FBCF8414BDBCDB8101282A1DC` |
| `FEATURE_REGISTRY.json` | `7951745EDD3CB77D9DCE94560FBD3DC16727356EFFD02B1685E8A5E922ACCBB7` |
| `INVARIANT_REGISTRY.json` | `45E944A07FF5AA0AD1BF2E61007414201EB17DFF76EB84DC4DCE2A16D8CCF0AC` |
| `TEST_CATALOG.json` | `DDF6D2960B546F7643011953E03F1917FA87A434B0872B50CFD7E60B0D1FEDD9` |
| `12_CHANGE_CONTROL/TRACEABILITY_MATRIX.md` | `6FF9E6BA252650866C49029EF384BB41D83FC154FF5E7ECED3776E10FAA01868` |
| `reports/IMP-012_CCS-01-006_IMPLEMENTATION.md` | `454866FE515A7E29A10CAF795D7AD039A83845A1157859ADFE6187D2736D720C` |

Normative interpretation:

- the task catalog defines `CCS-01-009` as app-managed Session token hash, rotation family, and
  one-way revocation;
- `IMP-012` owns authentication, secret references, `ActorContext`, the session service, and
  hash-only session evidence;
- `F-059` is exactly "Hash-only app sessions and one-way revocation";
- `INV-AUTH-001` requires hash-only session identity and one-way revocation through schema,
  database trigger, and authentication boundary enforcement;
- `T-INT-137` requires immutable Session token identity and one-way revocation.

## 3. Verified overlap with completed CCS-01-006

| CCS-01-009 requirement | Existing CCS-01-006 evidence | Decision |
|---|---|---|
| raw bearer token returned once and never persisted | `IssuedSession.raw_token_once`; repository stores salted `scrypt` digest only | complete |
| versioned bounded token hashing | `scrypt$n=16384,r=8,p=1,l=32$...`; bounded parser and constant-time compare | complete |
| stable rotation family | successor retains `session_family_id` | complete |
| predecessor linkage | successor stores `rotated_from_session_id` | complete |
| atomic rotation | successor insert and predecessor revoke share one caller-owned UoW | complete |
| old token rejected after rotation and restart | integration and repository reopen tests | complete |
| immutable session identity | SQLite trigger rejects identity/hash/family/predecessor/time mutation | complete |
| one-way reason-bound revocation | repository and SQLite trigger reject un-revoke or reason change | complete |
| trusted request actor | authentication derives current user, Workspace membership, role, and session ID into `ActorContext` | complete for local application boundary |
| secret-safe representation | raw token and token hash fields are excluded from dataclass representations | complete |

Exact implementation artifacts:

| Artifact | SHA-256 |
|---|---|
| `src/custom_content_studio/application/services/sessions.py` | `11E452D052EAEAFED085E0F0EBC82C3C161F8207CA1FC488B099A4FB4CA4F601` |
| `src/custom_content_studio/domain/security/models.py` | `724F422D0E0448C43F506B5321FC96908A520E647EF288B069BEB3DFE41DE59A` |
| `src/custom_content_studio/application/ports/session_repository.py` | `0CAE1BE5C7BB57103DC7DBBF9500C5340D43A58FE403B09D4FEB1C665E93E354` |
| `src/custom_content_studio/infrastructure/sqlite/repositories/sessions.py` | `943EBBE32FB9AA6206F5A1C6A2E8D186009C5CA85A9D374E8000EF7EF6A3BB7C` |
| `migrations/0001_initial_v2_2.sql` | `2B532C6FBE5B45241F2CD815B6DE4947D0A056B32754165FD06C1E9C12A2980F` |
| `tests/repository/test_session_repository.py` | `EC92DF483F8CBC47B30DE7684721EBAB567730993889CF0308448AD2BA7A947B` |
| `tests/integration/test_session_service.py` | `2CD27A63BE167B26EC9E77E217E10AB17A35E65A26FEDA9BBBACE0278EFA3E72` |

## 4. Exact re-scope boundary

A future successor registry may close `CCS-01-009` without an implementation attempt only when it
binds all of the following:

1. `parent_work_package_id=IMP-012` and `depends_on=[CCS-01-007]` remain unchanged from r10;
2. `feature_ids=[F-059]`;
3. `invariant_ids=[INV-AUTH-001]`;
4. `tests.introduces=[T-INT-137]` and `tests.must_pass=[T-INT-137]`;
5. implementation provenance points to commit `c2b03c6e90ef51d3d1fa9d22cd1a90a1664865ad`
   and the exact artifact hashes in section 3;
6. the stable test-node locators in section 5 are recorded as acceptance evidence;
7. allowed/create/modify paths and execution commands remain empty, `directly_executable=false`,
   and external effects remain forbidden.

`CCS-01-006` keeps provenance for the broad security implementation. It must not also receive
canonical ownership of `F-059`, `INV-AUTH-001`, or `T-INT-137`; that would create duplicate
ownership. The later canonical leaf owns the requirement, while the earlier completed leaf owns
the historical implementation event.

The following are outside `CCS-01-009`:

- generic `SecretReference`, masking, role/action policy, and `SecretStorePort` foundations remain
  historical `CCS-01-006` responsibilities;
- ServiceAccount credential-secret reference and rotation audit belong exclusively to
  `CCS-01-010`;
- HTTP header/cookie parsing, reverse-proxy trust, OAuth, external identity providers, and live
  credential stores require separate transport/provider contracts;
- Workspace/project CRUD and human approval flows remain later `CCS-02` and `CCS-07` work;
- no schema or migration rewrite is permitted because the accepted migration already contains
  the required columns, indexes, and immutability/revocation triggers.

If review finds a requirement beyond the exact task text and normative `F-059` contract, it must
stop and be assigned to its real owner. It must not be smuggled into this evidence-only leaf.

## 5. Exact acceptance evidence

The successor must bind these existing stable node IDs without changing the files:

- `tests/repository/test_session_repository.py::test_fresh_database_persists_hash_only`
- `tests/repository/test_session_repository.py::test_database_trigger_rejects_identity_mutation`
- `tests/repository/test_session_repository.py::test_revocation_is_one_way_and_reason_bound`
- `tests/repository/test_session_repository.py::test_rotation_linkage_is_durable_and_old_token_is_rejected`
- `tests/integration/test_session_service.py::test_rotation_is_atomic_and_old_session_stays_revoked_after_reopen`
- `tests/integration/test_session_service.py::test_issue_and_authenticate_derive_current_workspace_role`

Discovery verification command:

```powershell
$env:PYTHONDONTWRITEBYTECODE = "1"
.\.venv\Scripts\python.exe -m pytest -p no:cacheprovider `
  tests/repository/test_session_repository.py::test_fresh_database_persists_hash_only `
  tests/repository/test_session_repository.py::test_database_trigger_rejects_identity_mutation `
  tests/repository/test_session_repository.py::test_revocation_is_one_way_and_reason_bound `
  tests/repository/test_session_repository.py::test_rotation_linkage_is_durable_and_old_token_is_rejected `
  tests/integration/test_session_service.py::test_rotation_is_atomic_and_old_session_stays_revoked_after_reopen `
  tests/integration/test_session_service.py::test_issue_and_authenticate_derive_current_workspace_role
```

Observed result at the inspected commit: `6 passed in 2.59s` on CPython 3.12.10. The command used
pytest temporary directories only and did not create a repository cache or runtime database.

## 6. Binary completion criteria for the future successor

The evidence-only leaf may close only if:

- every normative and implementation hash in this packet still matches;
- all six existing node IDs pass with no skip or xfail;
- `F-059`, `INV-AUTH-001`, and `T-INT-137` have exactly one canonical leaf owner;
- no source, migration, dependency, lockfile, profile, existing test, runtime database, or
  credential changes are present;
- the successor preserves the r10 execution order
  `CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008`;
- final review records `SATISFIED_BY_CCS-01-006_EVIDENCE`, not a second implementation claim.

A hash or behavior mismatch returns `EVIDENCE_STALE`. Missing or duplicate traceability ownership
returns `TASK_ENVELOPE_INCOMPLETE`. Any proposed product change returns
`REDUNDANT_IMPLEMENTATION_ATTEMPT`. Credential, external-provider, runtime-database, deployment,
or publication access returns `SCOPE_VIOLATION` and requires separately scoped authority.

## 7. Current readiness and next controlled action

Decision: `READY FOR IMMUTABLE EVIDENCE-CLOSURE SUCCESSOR; NOT READY FOR CODE DISPATCH`.

Create an immutable successor to r10 that records the re-scope in section 4 and preserves all
r10 bytes. Do not create an ACTIVE implementation packet for `CCS-01-009`. After evidence closure,
continue to `CCS-01-010`; the CCS-01 gate remains blocked until that distinct ServiceAccount
credential-rotation requirement and the remaining gate test ownership are resolved.
