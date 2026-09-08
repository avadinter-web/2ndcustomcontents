# CCS-01-006 Local Work Packet — Attempt 001

Status: `ACTIVE / BOUNDED LOCAL IMPLEMENTATION`
Authority profile `LD00_DIRECT_USER_AUTHORIZATION`
Baseline commit: `98659ed549a1426d428916d5461c72c088392b6e`
Canonical parent: `IMP-012`
Discovery source: `reports/CCS-01-006_DISCOVERY_WORK_PACKET.md`
Registry source: r7, retained as immutable DRAFT discovery evidence only

Understood as: implement the exact local security/session boundary already discovered for
`CCS-01-006`, using synthetic identities and pytest temporary databases only; do not access
credentials, providers, runtime databases, deployment or publication systems.

## Exact mutation allowlist

- `.codex/ccs/local_work_packets/CCS-01-006-attempt-001.md`
- `.codex/ccs/local_decisions/LD00-CCS-01-006-attempt-001.md`
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
- `src/custom_content_studio/bootstrap/composition.py`
- `tests/unit/test_security_contract.py`
- `tests/repository/test_session_repository.py`
- `tests/contract/test_secret_store_port.py`
- `tests/integration/test_session_service.py`
- `reports/IMP-012_CCS-01-006_IMPLEMENTATION.md`

All other paths are read-only. The existing schema and migration manifest are consumed as
