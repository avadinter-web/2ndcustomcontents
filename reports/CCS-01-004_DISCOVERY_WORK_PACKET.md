# CCS-01-004 실행환경 프로필 Discovery 작업 패킷

상태: `DISCOVERY COMPLETE / NON-EXECUTABLE / ACTIVE 승인 필요`

작성일: 2026-09-08

대상 leaf: `CCS-01-004`

상위 작업 패키지: `IMP-010`

선행 leaf: `CCS-01-011`

## 1. 목적과 권한 경계

이 문서는 DEV/STAGING/PROD 실행환경 프로필 구현 범위를 확정하기 위한 읽기 전용 discovery 산출물이다. 코드 변경, 설정 파일 생성, 테스트 추가, 서버 실행, 외부 서비스 연결을 승인하지 않는다.

현재 r5 task registry는 `DRAFT`, `readiness.decision=NOT_EVALUATED`, `implementation_authorized=false`이며 `CCS-01-004.leaf_definition_digest`도 zero digest다. 따라서 이 문서는 규범 orchestration의 `READY/ACTIVE work packet`이 아니고 구현자가 실행할 수 없다. 실제 구현 전에 다음이 모두 별도로 필요하다.

1. r5 이후 불변 registry revision에서 leaf digest와 경로·추적성 검증을 완료한다.
2. `VC-02` 선행 수용 영수증을 정확히 바인딩한다.
3. 사용자가 이 leaf의 정확한 작업 패킷에 별도 ACTIVE 승인을 부여한다.
4. 구현자 envelope와 scope guard가 같은 digest·경로·명령을 가리키는지 검증한다.

이 조건이 없으면 `TASK_ENVELOPE_INCOMPLETE`, `PREREQUISITE_NOT_ACCEPTED` 또는 `NEXT_TASK_NOT_AUTHORIZED`로 중단해야 한다.

## 2. 확인된 현재 상태

- canonical package layout 전환은 커밋 `652e065b69652312efc1ee9eb9556bc054508056`에서 완료됐다.
- `Environment`는 `DEV`, `STAGING`, `PROD` 세 값만 허용한다.
- `Settings`는 frozen Pydantic model이며 현재 `environment`, `repository_root`, `runtime_root`만 보유한다.
- `load_settings()`는 `<repo>/.runtime/<ENV>`를 계산하지만 TOML·process environment·명시적 override 우선순위를 아직 처리하지 않는다.
- `bootstrap()`은 설정 로드 후 scope guard를 실행한다.
- CLI는 `--environment` 기본값을 `DEV`로 지정한다.
- `.env.example`은 `CCS_PROFILE`, `CCS_HOST`를 사용하지만 규범 키는 `CCS_ENV`, `CCS_API_HOST`다.
- profile TOML과 전용 환경 프로필 테스트는 아직 없다.
- 현재 구성 로드는 파일·디렉터리를 생성하지 않으며 이 무부작용 특성을 유지해야 한다.

## 3. 정확한 파일 범위

### 3.1 기존 파일 수정

| 파일 | 필요한 최소 변경 |
|---|---|
| `.env.example` | `CCS_PROFILE`을 `CCS_ENV`로, `CCS_HOST`를 `CCS_API_HOST`로 정정한다. 실제 비밀값과 `.env` 생성 지시는 추가하지 않는다. |
| `README.md` | DEV/STAGING/PROD 선택 방법, 우선순위, 실패 조건, PowerShell 실행 예시를 기록한다. |
| `src/custom_content_studio/config/models.py` | CCS-01-004가 소유하는 비밀 없는 공통 profile 필드와 환경별 안전 검증을 typed frozen model로 정의한다. |
| `src/custom_content_studio/config/loader.py` | 명시적 override, process environment, 선택된 TOML, safe default 순으로 합성하고 unknown key·잘못된 profile을 거부한다. |
| `src/custom_content_studio/config/__init__.py` | 구현된 공개 타입과 loader만 재수출한다. |
| `src/custom_content_studio/bootstrap/composition.py` | 하나의 loader 결과를 사용하고 scope guard를 먼저 통과시킨다. provider·DB·migration은 구성하지 않는다. |
| `src/custom_content_studio/bootstrap/startup.py` | 환경 누락·불일치가 정상 시작으로 표시되지 않도록 loader 오류를 그대로 실패시킨다. |
| `src/custom_content_studio/cli/__init__.py` | `--environment`를 실제 명시적 override로 전달한다. 환경 누락을 묵시적 DEV로 바꾸지 않는다. |
| `tests/test_bootstrap.py` | 명시적 profile로 모든 process shell의 무부작용 startup과 CLI health 출력을 회귀 검증한다. |

### 3.2 새 파일 생성

| 파일 | 내용 |
|---|---|
| `config/` | 같은 leaf가 생성하는 정확한 새 직속 부모 디렉터리다. 다른 파일을 암묵적으로 허용하지 않는다. |
| `config/dev.toml` | DEV용 비밀 없는 값과 안전 스위치. |
| `config/staging.toml` | STAGING용 비밀 없는 값, debug 비활성, 외부 부작용 차단. |
| `config/prod.toml` | PROD용 비밀 없는 값, JSON log, debug 비활성, publish/scheduler kill switch 유지. |
| `tests/test_environment_profiles.py` | T-ENV-003과 관련 회귀 테스트. |
| `reports/IMP-010_CCS-01-004_IMPLEMENTATION.md` | 실제 구현·검증 결과와 알려진 문제. 구현 완료 전 생성하지 않는다. |

`config/`와 세 직속 TOML 파일은 CHG-2026-0020의 동일-leaf 부모/자식 생성 규칙을 따른다. 위 목록 밖의 파일은 수정하거나 생성하지 않는다. 특히 `pyproject.toml`, lockfile, `runtime_paths.py`, DB/migration, secrets, provider, API route, UI page는 이 leaf 범위가 아니다.

## 4. 최소 구성 계약

### 4.1 환경 선택

- canonical selector는 `CCS_ENV`와 CLI `--environment`다.
- 허용 값은 대소문자 변환 없이 정확히 `DEV`, `STAGING`, `PROD`다.
- 환경 선택 우선순위는 `명시적 CLI override > process environment`로 고정한다. 둘 다 없으면 시작 실패이며 profile file이나 safe default가 환경을 선택해서는 안 된다.
- 선택된 profile의 비선택자 값은 `승인된 process override > profile file > 문서화된 safe default` 순으로 합성한다. 이 우선순위는 환경 이름 자체에는 적용하지 않는다.
- 환경 이름 자체는 실행 전에 명시돼야 한다. 누락·오타·알 수 없는 값·profile 파일의 환경 불일치는 시작 실패다.
- STAGING/PROD 실패를 DEV로 fallback하지 않는다.
- profile 경로는 repository root 아래 `config/<dev|staging|prod>.toml`로 고정하고, 사용자 입력 경로를 직접 결합하지 않는다.

### 4.2 모델

기존 frozen `Settings`와 `Environment`를 유지한다. CCS-01-004에서는 다음 비밀 없는 최소 필드만 소유한다.

- identity: `environment`, `app_name=custom_content_studio`, `spec_version=2.2`
- roots: resolved `repository_root`, `<repository_root>/.runtime/<ENV>`인 `runtime_root`
- diagnostics: `log_level`, `log_format`, `debug`
- local endpoints: `api_host`, `api_port`, `ui_api_url`
- safety: `kill_publish=true`, `kill_scheduler=true`

DB, 인증, session, SecretStore, FFmpeg, worker lease, provider credential/account 설정은 이후 소유 leaf가 모델을 확장한다. CCS-01-004가 이 필드를 미리 구현하지 않는다.

모델은 다음을 검증해야 한다.

- unknown TOML key와 지원하지 않는 `CCS_*` override를 오류로 보고한다.
- `app_name`과 `spec_version` 변경을 거부한다.
- API port는 1..65535이고 이 로컬 leaf에서는 host가 loopback이어야 한다.
- STAGING/PROD에서 `debug=false`다.
- PROD에서 `log_format=json`이다.
- 모든 profile에서 publish/scheduler kill switch는 true다. 이를 해제하는 운영 기능은 이 leaf에 없다.
- runtime root는 scope guard를 통과한 repository 내부 profile 경로이며 loader가 디렉터리를 생성하지 않는다.

### 4.3 loader와 profile 파일

- TOML 파싱은 Python 3.12 표준 `tomllib`를 사용하고 새 의존성을 추가하지 않는다.
- 입력 원본별 값을 먼저 분리해 읽은 다음, 고정된 우선순위로 합성하고 마지막에 typed model을 한 번 검증한다.
- process environment 전체를 model에 전달하지 않는다. 승인된 비밀 없는 키 allowlist만 읽는다.
- 각 TOML은 해당 profile의 비밀 없는 값만 포함한다. `token`, `secret`, `password`, bearer material, credential path/value는 거부한다.
- `.env` 파일을 읽거나 생성하지 않는다. `.env.example`은 이름과 안전 예시만 제공한다.
- 오류에는 setting 이름과 규칙만 포함하고 입력 원문이나 비밀 후보 값을 출력하지 않는다.
- redacted view, deterministic config digest, 외부 config directory는 이 leaf에서 구현하지 않고 후속 정확 leaf로 남긴다.

### 4.4 bootstrap과 CLI

- 모든 process shell은 동일한 `load_settings()`와 `bootstrap()` 경로를 사용한다.
- profile 검증과 scope guard가 성공하기 전 DB, migration, job claim, listener, provider call을 실행하지 않는다.
- CLI `--environment`가 없으면 process `CCS_ENV`를 사용하며 둘 다 없으면 실패한다.
- `health` 출력은 environment, runtime root, status만 유지하고 비밀·전체 config를 출력하지 않는다.
- bootstrap과 profile load는 파일시스템 생성·네트워크·subprocess·외부 서비스 부작용이 없어야 한다.

## 5. 테스트 계약

새 `tests/test_environment_profiles.py`와 기존 회귀 테스트는 최소 다음을 증명한다.

1. DEV/STAGING/PROD가 각각 정확한 TOML을 읽고 서로 다른 `.runtime/<ENV>` 경로를 반환한다.
2. 환경 선택의 `CLI > process environment > 실패` 규칙과, 비선택자 profile 값의 `승인된 process override > profile file > safe default` 우선순위를 각각 충돌 사례로 검증한다.
3. 환경 누락, 알 수 없는 환경, 파일 누락, 선택 환경과 TOML 환경 불일치를 모두 거부하며 DEV fallback이 없다.
4. unknown key와 secret-like key/value 위치를 거부하고 오류 메시지에 입력값이 노출되지 않는다.
5. STAGING/PROD debug, PROD console log, 비-loopback host, 범위 밖 port, false publish/scheduler kill switch를 거부한다.
6. loader와 bootstrap이 config/runtime 디렉터리 또는 파일을 생성하지 않는다.
7. runtime root 이탈·상대 경로·legacy root를 기존 scope guard가 계속 거부한다.
8. CLI 명시 override와 process `CCS_ENV` 선택이 health JSON에 정확히 반영된다.
9. API/UI/worker/scheduler/bootstrap process shell이 명시된 profile로 side-effect-free startup을 유지한다.
10. 기존 `T-ENV-001`, `T-ENV-002`, package-layout, scope-guard 테스트가 회귀 없이 통과한다.

추적성은 `T-ENV-003`을 신규 중심 테스트로, `T-ENV-001`과 `T-ENV-002`를 회귀 테스트로 사용한다. `T-ENV-004~006` 전체를 이 leaf가 완료했다고 주장하지 않는다.

## 6. 검증 명령

실제 ACTIVE 패킷은 아래 논리 명령을 절대 interpreter·cwd·process contract와 함께 고정해야 한다. discovery 문서는 실행 권한을 부여하지 않는다.

```powershell
Set-Location -LiteralPath 'E:\Custom_Contents_APP'
.\scripts\run-module.ps1 pytest -p no:cacheprovider
.\scripts\run-module.ps1 ruff check --no-cache src tests
.\scripts\run-module.ps1 ruff format --check --no-cache src tests
.\scripts\run-module.ps1 mypy --cache-dir .runtime\mypy-cache src

$env:CCS_ENV = 'DEV'
.\scripts\run-module.ps1 custom_content_studio.cli health
$env:CCS_ENV = 'STAGING'
.\scripts\run-module.ps1 custom_content_studio.cli health
$env:CCS_ENV = 'PROD'
.\scripts\run-module.ps1 custom_content_studio.cli health
Remove-Item Env:CCS_ENV -ErrorAction SilentlyContinue

git diff --check
```

추가 검증은 profile 파일과 `.env.example`에 secret-like key가 없고, loader 실행 전후 repository snapshot에서 허용되지 않은 생성 파일이 없는지 확인해야 한다. 실제 API listener, UI server, worker loop, scheduler, provider, publish는 실행하지 않는다.

## 7. 명시적 제외 범위

- `.env` 생성·수정·commit
- 원시 API key, token, client secret, password, OAuth material 저장 또는 출력
- SecretStore 구현, 자격 증명 경로 생성, OS credential 변경
- DB 파일·schema·migration·repository·transaction 구현
- FFmpeg/FFprobe 실행 또는 media 처리
- API/Streamlit listener 실행, 방화벽·포트·서비스 등록 변경
- provider SDK/adapter, Google Flow, Higgsfield, YouTube, TikTok 등 외부 연결
- 실제 생성, 업로드, 게시, 예약 게시, scheduler/worker 활성화
- STAGING/PROD 외부 전송, 배포, 원격 업데이트, CI/CD 변경
- 새로운 의존성, feature flag, route, UI page, 범용 config framework 추가

## 8. 위험과 완화

| 위험 | 완화/차단 기준 |
|---|---|
| CLI 기본 DEV가 환경 누락을 숨김 | argparse 기본값을 명시 override와 분리하고 누락 시 실패 테스트를 둔다. |
| `.env.example`의 비규범 키가 계속 사용됨 | `CCS_PROFILE→CCS_ENV`, `CCS_HOST→CCS_API_HOST`를 수정하고 이전 키를 unknown으로 거부한다. |
| profile 파일이 비밀 저장소로 오용됨 | secret-like key를 거부하고 세 TOML과 예제 파일을 정적 검사한다. |
| PROD 안전 설정이 DEV 값으로 덮임 | 환경별 validator로 debug/log/kill switch를 강제하고 fallback을 금지한다. |
| loader가 모든 규범 설정을 한 번에 흡수해 범위가 커짐 | 이 leaf 소유 최소 필드만 구현하고 DB/auth/provider/resource 설정은 후속 leaf에 남긴다. |
| 테스트가 runtime 디렉터리를 생성함 | `tmp_path` 입력과 before/after 존재 검증으로 loader 무부작용을 증명한다. |
| r5 DRAFT가 실행 승인으로 오인됨 | 별도 ACTIVE 승인·VC-02 receipt·nonzero leaf digest 없이는 구현을 중단한다. |

## 9. 완료 기준

실제 구현은 다음 조건을 모두 만족해야 완료다.

- 정확한 기존/신규 파일 목록 밖 변경이 없다.
- 세 profile이 동일 typed model/loader를 사용하고 환경 누락·오타·불일치가 fail closed다.
- 우선순위가 테스트로 고정되고 PROD가 DEV로 fallback하지 않는다.
- TOML과 `.env.example`에 원시 비밀이 없으며 오류·health 출력도 redacted다.
- loader/bootstrap이 파일 생성, DB, network, subprocess, provider 부작용을 일으키지 않는다.
- `T-ENV-003` 및 `T-ENV-001/002` 회귀, 전체 pytest, Ruff, format, mypy, CLI profile smoke가 통과한다.
- 구현 보고서가 실제 실행 명령·결과·알려진 문제를 기록한다.
- Astra 최종 리뷰에서 설계·r5 경로·완료 기준과 일치함을 확인한다.
- 검증 후에만 사용자 정책에 따라 단일 leaf commit/push를 진행한다.

## 10. 구현 전 최종 판정

설계와 파일 경계는 구현 가능한 수준으로 발견됐다. 그러나 현재 판정은 `NOT AUTHORIZED`다. 별도 ACTIVE 승인이 발행되기 전에는 이 문서를 근거로 코드·config·테스트를 수정해서는 안 된다.
