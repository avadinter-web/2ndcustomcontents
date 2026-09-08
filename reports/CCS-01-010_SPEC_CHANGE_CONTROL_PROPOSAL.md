# CCS-01-010 Specification Change-Control Proposal

Status: `PROPOSAL / SPECIFICATION NOT MUTATED / PRODUCT IMPLEMENTATION NOT AUTHORIZED`
Date: 2026-09-08
Product repository: `E:\Custom_Contents_APP`
Inspected product commit: `8660c30dd28ee69ae4ed0a86b00b9b6f6b02ab9a`
Canonical leaf: `CCS-01-010`
Current work package: `IMP-012`
Proposed change record: `CHG-2026-0022`

## 1. Change decision

Approve one specification change set before any `CCS-01-010` implementation. Keep the leaf under
`IMP-012` and keep its dependency on `CCS-01-009`. Do not add a new prerequisite leaf or a new
`IMP-*` work package.

The change assigns `CCS-01-010` two inseparable responsibilities:

1. own the ServiceAccount credential-reference rotation contract and its dedicated traceability;
2. introduce the first local runtime audit-append kernel needed to commit that rotation and its
   audit event atomically.

`IMP-023` and `IMP-120` remain valid downstream consumers of `F-043`. Their existing feature
references are not removed. They must reuse the kernel introduced by `CCS-01-010`; they do not
become competing owners of its first runtime implementation or tests.

This is the smallest closed repair. A separate audit leaf would add ordering and transaction
handoff without adding independently useful behavior, while mapping rotation only to `F-043` or
`F-003` would conceal a distinct ADMIN-only, reference-only, audit-atomic requirement.

## 2. Required canonical IDs and ownership

| ID | Canonical meaning | Specification owner | First runtime leaf owner | Required test binding |
|---|---|---|---|---|
| `F-043` | Ordered append-only audit stream | existing `CCS-00` contract; add `IMP-012` traceability | `CCS-01-010` | existing `T-INT-092`, `T-INT-093` |
| `INV-AUD-001` | Audit stream sequence and predecessor are enforced | existing audit contract | `CCS-01-010` | existing `T-INT-092`, `T-INT-093` |
| `F-077` | ServiceAccount secret-reference rotation with atomic audit | new `CCS-01` feature under `IMP-012` | `CCS-01-010` | new `T-INT-138` |
| `INV-AUTH-002` | ServiceAccount credential rotation is ADMIN-authorized, reference-only and audit-atomic | new auth invariant | `CCS-01-010` | new `T-INT-138` |
| `T-INT-138` | ServiceAccount credential reference rotates atomically with secret-safe audit | new `CCS-01` integrity test | `CCS-01-010` | `F-077`, `INV-AUTH-002` |

The existing canonical meanings of `F-043`, `INV-AUD-001`, `T-INT-092`, and `T-INT-093` do not
change. `F-077`, `INV-AUTH-002`, and `T-INT-138` are the next unused IDs in their registries at
the inspected specification state. The expected catalog totals after this change are 77 features,
39 invariants, 364 tests, and 364 linked tests.

### 2.1 `F-077` exact proposal

- phase: `CCS-01`;
- name: `ServiceAccount secret-reference rotation with atomic audit`;
- specs:
  - `09_SHARED_SPEC/AUTH_SESSION_CONTRACT.md`;
  - `09_SHARED_SPEC/SECURITY.md`;
  - `09_SHARED_SPEC/AUDIT_CHAIN.md`;
  - `09_SHARED_SPEC/TRANSACTION_AND_CONCURRENCY.md`;
  - `09_SHARED_SPEC/PORT_AND_ADAPTER_INTERFACES.md`;
  - `09_SHARED_SPEC/APPLICATION_SERVICE_CONTRACTS.md`;
  - `09_SHARED_SPEC/SQLITE_SCHEMA.sql`;
- tests: only `T-INT-138` as its dedicated acceptance test;
- code paths: remain empty and status remains `PLANNED` until implementation is accepted.

### 2.2 `INV-AUTH-002` exact proposal

- name: `ServiceAccount credential rotation is ADMIN-authorized, reference-only and audit-atomic`;
- enforcement:
  - `AUTHORIZATION`;
  - `SECRET_REFERENCE_ONLY`;
  - `OPTIMISTIC_CONCURRENCY`;
  - `TRANSACTION`;
  - `AUDIT_CHAIN`;
- tests: `T-INT-138`.

### 2.3 `T-INT-138` exact proposal

- name: `ServiceAccount credential reference rotates atomically with secret-safe audit`;
- phase: `CCS-01`.

`T-INT-138` proves the rotation-specific authorization, compare-and-swap, rollback and secret
redaction behavior. It does not duplicate the generic sequence, predecessor and Workspace stream
checks in `T-INT-092` and `T-INT-093`; those two tests run as required regressions for the same
leaf.

## 3. Normative behavior to freeze

The changed specification must state all of the following without leaving adapter discretion:

1. Only a USER actor with ADMIN role, matching Workspace and `SECRET_REFERENCE_MANAGE` may rotate
   the reference. A ServiceAccount cannot rotate itself.
2. The command accepts an opaque `SecretReference`, never a raw credential, and never resolves the
   secret value.
3. The target is resolved by account ID inside the authorized Workspace. Missing and cross-Workspace
   targets produce the same `WORKSPACE_ACCESS_DENIED` result.
4. Rotation requires an existing non-null reference, a different new reference, UTC timestamps,
   monotonic `rotated_at_utc`, and exact compare-and-swap against `expected_updated_at_utc`.
5. ACTIVE and DISABLED accounts may be rotated. Status and permissions are unchanged.
6. Only `credential_secret_ref`, `credential_rotated_at`, and `updated_at` are updated.
7. The account update and exactly one audit append occur through one caller-owned SQLite transaction
   and one commit. Any update, append, hash, or commit failure rolls back both writes.
8. The audit repository never commits independently and serializes competing appends on the
   `workspace:<workspace_id>` stream head.
9. The event action is `SERVICE_ACCOUNT_CREDENTIAL_ROTATED`; actor type is `USER`; entity type is
   `SERVICE_ACCOUNT`; `occurred_at` equals the command rotation time.
10. Audit JSON contains only schema/version and lowercase SHA-256 hashes of the old and new secret
    locators. It contains no locator, credential value, token, authentication ID, email, request
    payload, exception text, or resolved secret.
11. The event hash is lowercase SHA-256 over UTF-8 package-canonical JSON with sorted keys and no
    insignificant whitespace, covering every stored event field except `event_hash`.

The local leaf may use synthetic secret locators only. Actual credential creation, rotation,
revocation, deletion, account mutation outside the local test database, OS secret-store changes,
provider calls and runtime database access remain forbidden.

## 4. Exact specification files to change

Every file below belongs to one atomic `CHG-2026-0022` specification-only change. No product source
file is part of this change.

| File | Required change |
|---|---|
| `FEATURE_REGISTRY.json` | Append `F-077` exactly as section 2.1; leave all existing feature rows unchanged. |
| `INVARIANT_REGISTRY.json` | Append `INV-AUTH-002` exactly as section 2.2; leave `INV-AUD-001` unchanged. |
| `TEST_CATALOG.json` | Append `T-INT-138` exactly as section 2.3. |
| `10_TESTS/V2_2_INTEGRITY_TESTS.md` | Add the normative `T-INT-138` scenario and its ADMIN, Workspace, reference-only, CAS, atomic rollback, locator-hash and no-commit assertions. Preserve the existing `T-INT-092`/`093` cases. |
| `12_CHANGE_CONTROL/TRACEABILITY_MATRIX.md` | Add the `F-077` row with the listed specs and `T-INT-138`; retain the existing `F-043` row and tests. Do not claim code paths or implemented status. |
| `IMPLEMENTATION_REGISTRY.json` | Add `F-043` and `F-077` to `IMP-012.feature_ids`; add `ServiceAccount credential rotation service` and `ordered audit append port/repository` to deliverables; add ADMIN-only atomic rotation, secret-safe audit chain and rollback evidence to acceptance. Keep `depends_on`, stage, task file and `PLANNED` status unchanged. |
| `11_CODEX_TASKS/CCS-01_TASKS.md` | Expand `CCS-01-10` with `F-043`, `F-077`, `INV-AUD-001`, `INV-AUTH-002`, `T-INT-092`, `T-INT-093`, `T-INT-138`; state that it is the first runtime owner of the local audit append kernel. Keep `CCS-01-09` as predecessor. |
| `09_SHARED_SPEC/AUTH_SESSION_CONTRACT.md` | Freeze the command/result fields, ADMIN-only USER authorization, Workspace denial equivalence, existing/different reference rule, ACTIVE/DISABLED behavior, UTC monotonic time and stale-CAS outcome. |
| `09_SHARED_SPEC/SECURITY.md` | Freeze reference-only input/storage, forbidden raw credential resolution/exposure, locator hashing and the ban on ServiceAccount self-rotation. |
| `09_SHARED_SPEC/AUDIT_CHAIN.md` | Freeze action/entity/stream fields, audit JSON schema, locator-hash-only payload, exact event-hash envelope/canonicalization, stream-head serialization and append-without-commit rule. |
| `09_SHARED_SPEC/TRANSACTION_AND_CONCURRENCY.md` | Freeze one caller-owned transaction, exact CAS predicate, one commit and rollback-together semantics for account update plus audit append. |
| `09_SHARED_SPEC/PORT_AND_ADAPTER_INTERFACES.md` | Add closed ServiceAccount repository and audit-event append port signatures; both receive caller-owned transaction context and expose no raw credential. |
| `09_SHARED_SPEC/APPLICATION_SERVICE_CONTRACTS.md` | Add the rotation command/result/service contract and exact domain errors/atomicity postconditions. |
| `12_CHANGE_CONTROL/CHANGELOG.md` | Add `CHG-2026-0022` describing the ownership repair, three new IDs, unchanged schema, no product implementation and no credential/external effect. |
| `PACKAGE_INDEX.json` | Regenerate last, after all normative files are final, using the package tool. |

### 4.1 Files explicitly not changed

- `09_SHARED_SPEC/SQLITE_SCHEMA.sql`: existing ServiceAccount reference/rotation columns and
  append-only audit tables/triggers are sufficient;
- product migrations: no schema delta exists;
- `spec_manifest.json`: package version and required-file set do not change;
- `14_CODEX_ORCHESTRATION/WORK_BREAKDOWN_AND_GATES.md`: it has no leaf-specific ownership map to
  synchronize;
- orchestration schemas/templates/prompts: no control-schema or authority rule changes;
- product source, tests, configuration, credentials and runtime data: not authorized by this
  proposal.

If a reviewer concludes that a schema or orchestration-control change is necessary, that is a
scope change and must return to change-control review rather than being folded into
`CHG-2026-0022` silently.

## 5. Successor runtime-registry propagation

After the specification change passes, create immutable successor `r12` from `r11`; never edit
`r11`. The successor must:

- update its bound specification digests and package digest;
- keep `CCS-01-010.parent_slice_id = IMP-012` and dependency `CCS-01-009`;
- bind `F-043`, `F-077`, `INV-AUD-001`, `INV-AUTH-002`;
- introduce/must-pass `T-INT-092`, `T-INT-093`, `T-INT-138`;
- reuse the exact conditional path allowlist and local-only prohibitions from
  `reports/CCS-01-010_DISCOVERY_WORK_PACKET.md`;
- remain `DRAFT` and grant no write authority until an attempt-scoped work packet and valid ACTIVE
  authorization exist.

No successor may mark the leaf `RESOLVED` merely because the specification repair passes.

## 6. Risks and required mitigations

| Risk | Failure mode | Required mitigation |
|---|---|---|
| Catalog denominator change | Progress remains calculated as 76 features | Atomically update all registries/traceability and verify 77/39/364/364 totals. |
| Competing audit ownership | `IMP-023` or `IMP-120` reimplements a different append/hash kernel | Declare `CCS-01-010` first runtime owner and those packages downstream consumers. |
| Hash ambiguity | Different adapters hash different envelopes or timestamps | Freeze the exact stored-field envelope, canonical JSON and lowercase SHA-256 encoding. |
| Locator leakage | Opaque locator appears in audit, logs, exceptions or return models | Store locator only in the ServiceAccount column; audit only old/new locator digests; add negative scans/assertions. |
| Transaction split | Account reference changes without audit, or audit exists without change | Require caller-owned UoW, repository no-commit behavior and injected rollback tests. |
| Lost update | Two rotations both succeed on stale state | Exact `updated_at` compare-and-swap; one success and one `CONCURRENT_MODIFICATION`. |
| Authorization bypass | scoped ServiceAccount or cross-Workspace ADMIN rotates the target | USER ADMIN plus matching Workspace and action check; denial-equivalence test. |
| Disabled-account ambiguity | adapters reject or implicitly enable disabled accounts | Explicitly allow rotation while preserving DISABLED status and permissions. |
| Unnecessary migration | schema drift is introduced despite sufficient columns/triggers | Keep schema/migrations out; treat any proposed DDL as a separate reviewed change. |
| Premature authority | repaired spec or r12 is mistaken for implementation permission | Keep proposal and r12 DRAFT; require the normal dispatcher/work-packet/authorization gates. |

## 7. Acceptance criteria for `CHG-2026-0022`

The specification change is accepted only if all conditions hold:

1. Exactly one new feature, invariant and test exist with IDs `F-077`, `INV-AUTH-002`, and
   `T-INT-138`; no existing ID meaning changes.
2. `IMP-012` and `CCS-01-010` carry the ownership bindings in section 2, with no new work package
   or prerequisite leaf.
3. Every normative behavior in section 3 appears in the listed canonical contracts and no
   contract permits raw credential handling or an independent audit commit.
4. Feature/test/invariant/traceability counts are exactly 77/364/39/364-linked and all references
   resolve.
5. Strict specification sync and exact package-index verification pass.
6. Orchestration validation and its self-tests pass after the package digest changes.
7. `r11/task-registry.json` is byte-for-byte unchanged; only an immutable `r12` successor may bind
   the new package.
8. The current change-control task delta adds only this proposal; pre-existing unrelated dirty
   paths remain untouched. The later specification change is performed in the specification
   package, not smuggled into product code.
9. No application code, test implementation, DB/migration, real secret, account, OS credential,
   provider, deployment, publication or runtime data is changed.

## 8. Required verification sequence

Run the following from the specification root using the approved CPython 3.12 executable:

```powershell
& "E:\Custom_Contents_APP\.venv\Scripts\python.exe" -I -B `
  ".\tools\update_package_index.py"

& "E:\Custom_Contents_APP\.venv\Scripts\python.exe" -I -B `
  ".\tools\spec_sync_check.py" --strict --verify-package-index

& "E:\Custom_Contents_APP\.venv\Scripts\python.exe" -I -B `
  ".\tools\orchestration_check.py" --self-test
```

After creating `r12`, run the package orchestration checker against its exact registry path and
verify immutable predecessor preservation:

```powershell
& "E:\Custom_Contents_APP\.venv\Scripts\python.exe" -I -B `
  ".\tools\orchestration_check.py" `
  --spec-root "." `
  --task-registry "E:\Custom_Contents_APP\.codex\ccs\task_registries\local-dev-20260907\vc01b-local-20260907-r12\task-registry.json"

Get-FileHash `
  "E:\Custom_Contents_APP\.codex\ccs\task_registries\local-dev-20260907\vc01b-local-20260907-r11\task-registry.json" `
  -Algorithm SHA256
```

Record the strict counts, checker summaries, new package digest, r11 before/after digest, r12
digest and changed-path inventory in the change-control evidence. A generated index without a
passing strict check is not acceptance.

## 9. Current disposition

Decision: `READY FOR SPECIFICATION CHANGE-CONTROL REVIEW`.

This proposal resolves what must change but changes no canonical specification. Until
`CHG-2026-0022` is approved, applied, independently validated and propagated into a DRAFT immutable
successor, `CCS-01-010` remains blocked with `TASK_ENVELOPE_INCOMPLETE`.

## Skills used

- none
