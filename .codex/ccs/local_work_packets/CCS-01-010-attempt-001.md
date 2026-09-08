# CCS-01-010 Local Work Packet — Attempt 001

Status: `ACTIVE / BOUNDED LOCAL IMPLEMENTATION`
Authority profile: `LD00_DIRECT_USER_AUTHORIZATION`
Baseline commit: `a29d08f589ca12933949a0099e31166eab9c8844`
Canonical parent: `IMP-012`
Registry source: `vc01b-local-20260907-r12`
Registry file SHA-256: `241a827f8d36ffea43cb297f257ec59c00285ba73dc9533129ffe077373c10e3`
Registry digest: `708573fd62546a5eb284e7a9aba5c6112d086fabf8f5ab85be85a167dfe52184`

Implement only the local ServiceAccount credential-reference rotation and reusable ordered audit
append kernel defined by CHG-2026-0022. Use synthetic secret locators and pytest temporary SQLite
databases only.

## Exact mutation allowlist

Control records:

- `.codex/ccs/local_work_packets/CCS-01-010-attempt-001.md`
- `.codex/ccs/local_decisions/LD00-CCS-01-010-attempt-001.md`

Create:

- `reports/IMP-012_CCS-01-010_IMPLEMENTATION.md`
- `src/custom_content_studio/application/ports/audit_event_repository.py`
- `src/custom_content_studio/application/ports/service_account_repository.py`
- `src/custom_content_studio/application/services/service_account_credentials.py`
- `src/custom_content_studio/domain/security/service_accounts.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/audit_events.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/service_accounts.py`
- `tests/integration/test_service_account_credential_rotation.py`
- `tests/repository/test_audit_event_repository.py`
- `tests/repository/test_service_account_repository.py`
- `tests/unit/test_service_account_credentials.py`

Modify:

- `src/custom_content_studio/application/ports/__init__.py`
- `src/custom_content_studio/application/services/__init__.py`
- `src/custom_content_studio/bootstrap/composition.py`
- `src/custom_content_studio/domain/security/__init__.py`
- `src/custom_content_studio/domain/security/models.py`
- `src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py`
- `tests/unit/test_security_contract.py`

All other paths are read-only.

## Required behavior

- same-Workspace USER ADMIN plus `SECRET_REFERENCE_MANAGE`;
- ServiceAccount actor and cross-Workspace access denied without target disclosure;
- opaque reference only; no secret resolution;
- exact `updated_at` compare-and-swap;
- one caller-owned `BEGIN IMMEDIATE` transaction;
- account update and one ordered audit append commit or roll back together;
- event payload contains only old/new locator SHA-256 values;
- audit sequence, predecessor, Workspace stream, hash and append-only triggers verified;
- ACTIVE and DISABLED status and permissions preserved.

## Forbidden

- real credential or account operations;
- OS/environment secret access;
- network/provider/external calls;
- runtime or production database access;
- schema or migration changes;
- API, UI, worker, scheduler, deployment or publication changes;
- dependency or lockfile changes.

## Verification

- leaf unit/repository/integration tests;
- full pytest;
- Ruff check and format check;
- mypy strict;
- Git whitespace and exact path-scope checks.

Stop on scope expansion, spec/r12 drift, credential need, runtime DB access, migration need or
unlisted path.
