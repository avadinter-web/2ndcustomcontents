# IMP-012 / CCS-01-010 Implementation Report

Status: IMPLEMENTED / SOL VERIFIED / ASTRA REVIEW PENDING
Date: 2026-09-08
Authority: LD00_DIRECT_USER_AUTHORIZATION (bounded local development only)
Attempt: CCS-01-010-attempt-001
Baseline commit: a29d08f589ca12933949a0099e31166eab9c8844
Registry: vc01b-local-20260907-r12
Registry file SHA-256: 241A827F8D36FFEA43CB297F257EC59C00285BA73DC9533129FFE077373C10E3
Registry digest: 708573fd62546a5eb284e7a9aba5c6112d086fabf8f5ab85be85a167dfe52184
Specification binding: CHG-2026-0022

## Outcome

Implemented the bounded local ServiceAccount credential-reference rotation contract owned by
IMP-012. The application service permits only a same-Workspace USER actor with the ADMIN role and
SECRET_REFERENCE_MANAGE. ServiceAccount actors, narrowed scopes, other Workspaces, absent targets
and non-admin actors cannot rotate a reference.

The service reads the target through a Workspace-scoped query, requires an initialized opaque
reference, a different replacement locator, advancing UTC time and an exact
expected_updated_at_utc match. The compare-and-swap updates only credential_secret_ref,
credential_rotated_at and updated_at; name, status and permissions are preserved for both ACTIVE
and DISABLED accounts.

The reference CAS and exactly one SERVICE_ACCOUNT_CREDENTIAL_ROTATED append execute in one
caller-owned BEGIN IMMEDIATE unit of work and one commit. Audit insertion failure rolls back the
reference update. The Workspace audit stream assigns the next sequence and predecessor hash,
hashes the exact stored envelope as canonical UTF-8 JSON with lowercase SHA-256, and remains
append-only under the existing SQLite triggers. The event payload stores only the old/new opaque
locator digests; neither locator nor credential material enters the audit payload.

## Exact changed paths

Authority records:

- .codex/ccs/local_work_packets/CCS-01-010-attempt-001.md
- .codex/ccs/local_decisions/LD00-CCS-01-010-attempt-001.md

Created source:

- src/custom_content_studio/application/ports/audit_event_repository.py
- src/custom_content_studio/application/ports/service_account_repository.py
- src/custom_content_studio/application/services/service_account_credentials.py
- src/custom_content_studio/domain/security/service_accounts.py
- src/custom_content_studio/infrastructure/sqlite/repositories/audit_events.py
- src/custom_content_studio/infrastructure/sqlite/repositories/service_accounts.py

Modified source:

- src/custom_content_studio/application/ports/__init__.py
- src/custom_content_studio/application/services/__init__.py
- src/custom_content_studio/bootstrap/composition.py
- src/custom_content_studio/domain/security/__init__.py
- src/custom_content_studio/domain/security/models.py
- src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py

Tests and evidence:

- tests/unit/test_security_contract.py
- tests/unit/test_service_account_credentials.py
- tests/repository/test_service_account_repository.py
- tests/repository/test_audit_event_repository.py
- tests/integration/test_service_account_credential_rotation.py
- reports/IMP-012_CCS-01-010_IMPLEMENTATION.md

No schema, migration, manifest, dependency, lockfile, runtime database, API, UI, worker,
scheduler, registry or specification file was changed.

## Verification

Commands ran from E:/Custom_Contents_APP with the repository CPython 3.12 virtual environment:

- python -m pytest for the five leaf test files
- python -m pytest
- python -m ruff check src tests
- python -m ruff format --check src tests
- python -m mypy src
- git diff --check

Results:

- leaf tests: 35 passed
- full regression: 128 passed
- Ruff lint: PASS
- Ruff format: PASS, 69 files checked
- mypy strict: PASS, 51 source files checked
- Git whitespace check: PASS; only existing LF-to-CRLF conversion warnings were emitted
- runtime/application database access: none outside pytest tmp_path
- network, provider, OS secret store, external account and publication operations: none

Direct acceptance coverage includes T-INT-092, T-INT-093 and T-INT-138. Tests verify safe
authorization denial, Workspace target non-disclosure, exact CAS conflict behavior, status and
permission preservation, canonical event JSON and hash chaining, append-only triggers, repository
no-commit behavior, locator-hash-only payloads and update/audit atomic rollback.

## Evidence hashes

| Evidence | SHA-256 |
|---|---|
| immutable r12 registry file | 241A827F8D36FFEA43CB297F257EC59C00285BA73DC9533129FFE077373C10E3 |
| local work packet | DB7A394ECA43816790D82B5846A1A4CA0D24CF29CCF0F3DEEF0DE67D862FAB14 |
| local decision | 11CFAAEE3D245C4C8CFC50D0E0C8ACDBE4DFB1C69CE35C418919FBB1FBACF260 |
| credential service | E73E037AB1A6041A7948DB897BFC68848333CF7187A408A6ED26938FAFB97CC6 |
| audit repository | 1A7226CB49C3FE3E3CCA87F89B878FDDDAEF20A0D25D937675665591F2E77EF1 |
| integration tests | 939598C986A13E26CB2377960FA0FC279D1D67D46613B6607F1879329F6244C7 |

The report's own digest is intentionally bound by Astra after final review.

## Safety and preserved state

- Only synthetic locators and pytest temporary SQLite databases were used.
- No real credential, account, environment secret, OS credential store or provider was accessed.
- No schema, migration, runtime database, external service, deployment, publication or network
  action occurred.
- Pre-existing modified and untracked paths outside the exact allowlist were preserved unchanged.

## Review handoff

Astra should review only the exact paths listed above, rerun the verification suite, confirm the
r12/specification binding and unrelated dirty-state preservation, and request only bounded
corrections. This attempt has not been staged, committed or pushed.
