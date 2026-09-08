# CCS-01-004 Local Work Packet — Attempt 001

Status: `LOCAL DEVELOPMENT AUTHORIZED / SINGLE ATTEMPT`

## Authority

- Protocol: `docs/operations/LOCAL_DIRECT_AUTHORIZATION_PROTOCOL.md`
- User decision: active Codex conversation, 2026-09-08, “다음 구현 실행 승인”
- Canonical leaf: `CCS-01-004`
- Parent: `IMP-010`
- Baseline: `ec86ead0c3c45d7451f9416d5e6a5bbeeff05ec4`
- Registry reference: r5 `da364e1ffc968600c77cb83db6b586376154ba01c55ac5266f200d9a4622b3d7` (DRAFT; local-direct protocol substitutes only for this bounded local attempt)

## Allowed product paths

- `.env.example`
- `README.md`
- `config/`
- `config/dev.toml`
- `config/staging.toml`
- `config/prod.toml`
- `src/custom_content_studio/config/models.py`
- `src/custom_content_studio/config/loader.py`
- `src/custom_content_studio/config/__init__.py`
- `src/custom_content_studio/bootstrap/composition.py`
- `src/custom_content_studio/bootstrap/startup.py`
- `src/custom_content_studio/cli/__init__.py`
- `tests/test_bootstrap.py`
- `tests/test_config.py`
- `tests/test_environment_profiles.py`
- `tests/test_scope_guard.py`
- `reports/IMP-010_CCS-01-004_IMPLEMENTATION.md`

## Required behavior

Implement only the contract in `reports/CCS-01-004_DISCOVERY_WORK_PACKET.md`: explicit CLI environment overrides process `CCS_ENV`; neither selector may be absent; profile values are fail-closed, typed, local-only and side-effect free. Keep profile loading inside the repository’s fixed `config/<name>.toml` paths. Do not add dependencies.

## Prohibited actions

No `.env`, secrets, credentials, provider/network calls, listener startup, database/migrations, FFmpeg, worker/scheduler activation, publishing, deployment, remote update, CI/CD or paths outside the allowlist.

## Verification

Run the packet commands in the discovery report plus exact-path diff review. Record results in the implementation report. Commit and push only after Astra review.

## Verification environment repair

The existing repository `.venv` launcher references an unusable base interpreter and the fallback CPython lacks locked test dependencies. The previously approved local environment-preparation authority permits recreation of this repository-local `.venv` only with the unchanged `requirements.lock`; no lockfile, project dependency, credential, external provider or deployment change is allowed.
