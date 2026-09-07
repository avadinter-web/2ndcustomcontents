# ENV-02 / ENV-03 / ENV-04 실행 보고서

Status: ENV-02 COMPLETE / ENV-03 COMPLETE / ENV-04 NOT RUN
Date: 2026-09-07
Target: `E:\Custom_Contents_APP`

understood as: 사용자가 명시적으로 승인한 ENV-02·ENV-03 범위에서 지정 저장소에 CPython 3.12와 FFmpeg/FFprobe의 정확한 배포·실행 identity를 선정하고 설치한 뒤, 프로젝트 전용 `.venv`, 단일 재현 가능 lock/install workflow, DEV/TEST/STAGING 격리 디렉터리와 비밀값 없는 설정 예시를 구성한다. 앱 소스·entrypoint·DB·migration·provider SDK·실제 서비스 실행은 만들거나 실행하지 않으며, ENV-04는 해당 구현물이 없다는 객관적 근거로 smoke를 `NOT RUN` 처리한다. 이 setup은 외부 trusted dispatcher를 증명하거나 VC-00을 승인하지 않는다.

## 착수 계획

- 목표: Python 3.12/FFmpeg toolchain identity, 고정 의존성, 격리 프로필의 재현 가능한 개발환경을 만든다.
- 수정 범위: 시스템 사용자 범위 Python/FFmpeg 설치, `.venv`, `.runtime/DEV|TEST|STAGING`, `.gitignore`, `.env.example`, `pyproject.toml`, exact lock, `README.md`, 이 보고서와 관련 환경 보고서 갱신.
- 변경하지 않을 영역: 제품 소스/entrypoint, DB와 migration, provider/게시 연동, 실제 `.env` 및 비밀값, 서버·worker·scheduler 실행, Git branch/config/add/commit/push, 설계 패키지와 legacy 저장소.
- 검증: 설치 원본과 버전, 절대 실행경로·SHA-256, Python/pip origin, exact lock 재설치, `pip check`, 필수 package import/version, Ruff/mypy/pytest 실행 가능성, ignore 정책과 credential 부재, Git diff/status를 확인한다.
- 주요 위험: winget 배포 경로가 사용자 PATH 갱신 전 현재 세션에서 보이지 않을 수 있고, 외부 index/패키지 가용성에 따라 설치가 실패할 수 있다. 앱이 없으므로 ENV-04 제품 smoke/UIX/복구 테스트는 통과로 바꾸지 않고 `NOT RUN`으로 남긴다. 저장소는 unborn이고 trusted dispatcher 증거가 없어 VC-00은 계속 차단된다.

## 판정

- ENV-02: **COMPLETE** — 제품 전용 CPython 3.12.10과 standalone FFmpeg/FFprobe 8.1.1을 정확한 winget package/version으로 선정·설치하고 실행파일 identity, 필수 Python dependency, Streamlit page API, 단일 exact/hash lock workflow를 고정했다.
- ENV-03: **COMPLETE (승인된 setup 범위)** — `.venv`와 `.runtime\DEV|TEST|STAGING`, ignore 정책, 비밀값 없는 `.env.example`을 구성했으며 lock 설치, import와 dependency 정합성 검사를 통과했다.
- ENV-04: **NOT RUN** — 제품 source package, API/UI/worker/scheduler entrypoint, DB/schema/migration, tests가 없으므로 service smoke, UI viewport/page 동작, migration, 재시작·lease·예약 복구, 제품 단위/계약/통합 테스트를 실행할 대상이 없다. 이를 PASS로 대체하지 않았다.
- VC-00: **BLOCKED / NOT ACCEPTED 유지** — 이 환경 setup은 trusted dispatcher/host enforcement 증거나 base commit을 생성하지 않았다. 이후 별도 승인된 초기 기준선 커밋 결과는 `TRUSTED_DISPATCHER_VC00_VALIDATION.md`와 실행 결과를 따른다.
- 제품 구현: **NOT STARTED, 0/76 (0%)** — 환경 준비는 Feature 구현 완료로 계산하지 않는다.

## 기존 후보 비재사용 결정

Astra 사전점검에서 과거 C 경로 후보 4곳은 모두 없었고, E 드라이브에는 Codex runtime cache 및 다른 project venv의 Python 3.12.14, legacy/project `node_modules` 내부의 FFmpeg/FFprobe 7.1이 발견됐다. 이들은 system-managed cache 또는 다른 프로젝트의 mutable state라 삭제·업데이트·재생성 시 제품 실행이 깨질 수 있고 failure/ownership 경계를 공유한다. 따라서 제품 base/venv/binary로 복사하거나 참조하지 않고 독립 설치를 사용했다.

## 설치 배포와 실행 identity

| 항목 | 선정/관측값 |
|---|---|
| Python winget package | `Python.Python.3.12` version `3.12.10`, source `winget`, publisher Python Software Foundation |
| Python installer | `https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe`, manifest SHA-256 `67B5635E80EA51072B87941312D00EC8927C4DB9BA18938F7AD2D27B328B95FB` |
| 제품 Python | `E:\Custom_Contents_APP\.venv\Scripts\python.exe`, Python `3.12.10` 64-bit, SHA-256 `0B471133E110CFB53A061CAD528CE8E517D7B9AC41A0A396C39AD795A487FC14` |
| FFmpeg winget package | `Gyan.FFmpeg.Essentials` version `8.1.1`, source `winget`, GPL static essentials build |
| FFmpeg archive | `https://github.com/GyanD/codexffmpeg/releases/download/8.1.1/ffmpeg-8.1.1-essentials_build.zip`, manifest SHA-256 `6F58CE889F59C311410F7D2B18895B33C03456463486F3B1EBC93D97A0F54541` |
| FFmpeg executable | `C:\Users\knthr\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe`, SHA-256 `228D7A8556258DE907FDB55F36850078EBC7680B84EC30D84EA02E99BEC1D1EB` |
| FFprobe executable | `C:\Users\knthr\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-essentials_build\bin\ffprobe.exe`, SHA-256 `0FDE260F5ABD35C9CAFD96F594CC76365A780C1B73A90E35B6A3409EA1DB1BF0` |
| Media build probe | 두 도구 모두 `8.1.1-essentials_build-www.gyan.dev`, GCC 15.2.0 static build; 실행 성공 |

winget이 사용자 PATH alias를 추가했지만 governed command는 bare name이나 다른 프로젝트 경로를 쓰지 않고 위 절대 경로와 현재 파일 해시를 다시 결합해야 한다. 설치 archive의 manifest hash와 설치된 executable hash는 서로 다른 대상이며 모두 별도로 기록했다.

## Python dependency 및 lock

`pyproject.toml`은 CPython `==3.12.*`와 FastAPI/Uvicorn/Streamlit/Pydantic v2/pydantic-settings, pytest/Ruff/mypy만 직접 요구한다. provider SDK는 추가하지 않았다. lock compiler는 `pip-tools==7.5.1`, build backend는 `hatchling==1.27.0`으로 고정했다.

| 직접 요구 package | lock version | import/origin 결과 |
|---|---:|---|
| FastAPI | 0.141.1 | `.venv\Lib\site-packages\fastapi\__init__.py` |
| Uvicorn | 0.52.4 | `.venv\Lib\site-packages\uvicorn\__init__.py` |
| Streamlit | 1.63.0 | `.venv\Lib\site-packages\streamlit\__init__.py`; `Page`와 `navigation` API 존재 |
| Pydantic | 2.13.5 | `.venv\Lib\site-packages\pydantic\__init__.py` |
| pydantic-settings | 2.15.0 | `.venv\Lib\site-packages\pydantic_settings\__init__.py` |
| pytest | 9.1.1 | distribution 조회 성공 |
| Ruff | 0.16.6 | distribution 조회 성공 |
| mypy | 1.20.2 | distribution 조회 성공 |

`requirements.lock`은 공개 source `https://pypi.org/simple`, 64개 exact pin, 각 distribution SHA-256을 포함한다. host-derived `--no-index` 표기를 header에서 제거하고 public index 선언을 명시한 최종 lock SHA-256은 `421CB8CBA331C116FAA51E6FB5B86F8C299970968BD5F2F43B6544BD5F73D851`이다. install은 `--require-hashes`로 완료했다. lock 갱신과 설치 명령은 `README.md`에 PowerShell로 고정했다.

## 프로필과 비밀정보 경계

- 실제 디렉터리: `.runtime\DEV`, `.runtime\TEST`, `.runtime\STAGING`; 모두 `.runtime/` 규칙으로 Git 추적 제외.
- `.venv/`, `.env`, `.env.local`, `.env.*.local`은 추적 제외하고 `.env.example`은 추적 가능하다.
- `.env.example`에는 DEV loopback/port의 비밀값 없는 예시만 있으며 raw credential/token/private key는 없다.
- TEST fake-provider 정책은 README에 명시했으나 구현 코드가 없어 동작 검증은 ENV-04까지 `NOT RUN`이다.
- 실제 `.env`, secret-store 값, provider account/token은 만들거나 조회하지 않았다.

## 검증 결과

| 검사 | 결과 |
|---|---|
| exact winget install/list | Python 3.12.10, FFmpeg Essentials 8.1.1 확인 |
| 제품 interpreter version/path/hash | PASS |
| FFmpeg/FFprobe absolute path/version/hash | PASS |
| `pip install --require-hashes -r requirements.lock` | PASS |
| `.venv\Scripts\python.exe -m pip check` | PASS, `No broken requirements found.` |
| 필수 9개 distribution version 및 5개 runtime import origin | PASS; 모두 제품 `.venv` |
| Streamlit independent-page API surface | `Page=True`, `navigation=True`; 실제 UI 페이지/viewport는 NOT RUN |
| profile directories와 Git ignore | PASS |
| `.env.example` 추적 가능 여부 | PASS (`git check-ignore` exit 1) |
| common private-key/API-token signature scan | 일치 없음 (`rg` exit 1) |
| server/provider command | NOT RUN |
| pytest/Ruff/mypy project run | NOT RUN — source/tests 없음; 도구 설치·version/import만 확인 |
| Git status | unborn `master`; 승인된 scaffold/report만 untracked, `.venv`와 `.runtime`은 제외됨 |

## 생성/변경 및 비변경

- 생성/변경: `.gitignore`, `.env.example`, `pyproject.toml`, `requirements.lock`, `README.md`, `.venv`, `.runtime\DEV|TEST|STAGING`, 이 보고서.
- 사용자 범위 설치: CPython 3.12.10과 Gyan FFmpeg Essentials 8.1.1.
- 미생성/미변경: `src`, `tests`, `migrations`, DB, API/UI/worker/scheduler, provider adapter/SDK, `.env`, secret, Git branch/config/index/commit/remote.
- 외부 provider 호출, 미디어 생성, 게시, 결제, migration, 서비스 start, delete는 수행하지 않았다.

## 남은 차단 조건

1. trusted dispatcher/host가 실제 human authorization과 mutation enforcement를 제공한다는 VC-00 증거가 없다.
2. 이 보고서 작성 시점에는 unborn repository였다. 이후 초기 기준선 커밋이 생겨도 trusted dispatcher 검증 전에는 실행 authority가 되지 않는다.
3. 제품 source/config schema/entrypoint/DB/migration/tests가 없어 VC-01/VC-01B/VC-02와 ENV-04 제품 검증은 시작할 수 없다.
4. Streamlit API surface는 확인했지만 UIX 독립 페이지·고정 viewport 설계의 실제 렌더링은 구현 후 검증해야 한다.
