# VC-00 / ENV-01 Baseline Audit

Status: ENV-01 COMPLETE / VC-00 BLOCKED
Date: 2026-09-07
Target: `E:\Custom_Contents_APP`

understood as: 사용자가 지정하고 이번 턴에 명시적으로 승인한 `E:\Custom_Contents_APP`를 빈 실제 구현 루트로 기준선화한다. 이 단계는 Git 저장소 초기화와 읽기 전용 환경·경로·도구 실사 및 보고서 작성까지만 포함하며, 앱 소스·의존성·가상환경·데이터베이스·비밀값·provider 호출·서비스 실행·커밋·푸시·다음 VC는 포함하지 않는다.

## 착수 계획

- 목표: 실제 구현 루트의 Git·경로·도구·모듈·통합 capability 기준선을 증거 기반으로 기록한다.
- 수정 범위: `.git/` 초기화와 `reports/VC-00_BASELINE_AUDIT.md`, `reports/MODULE_INVENTORY.md`, `reports/CAPABILITY_MATRIX.md`, `reports/RISK_REGISTER.md`만 생성한다.
- 변경하지 않을 영역: 설계 패키지, legacy 저장소, 앱 코드, 의존성/lock, venv, DB/migration, `.env`/비밀값, 외부 서비스 및 운영 설정.
- 검증: literal/resolve path와 reparse 여부, volume 상태, Git 최초 상태, 제품 전용 Python/lock/dependency 존재 여부, host Python과 FFmpeg/FFprobe의 경로·버전·해시, legacy 분리, 최종 `git status`를 확인한다.
- 주요 위험: trusted dispatcher가 검증되지 않아 VC-00 기술 PASS/사용자 ACCEPTED를 선언할 수 없고, host Python 3.14가 설계 기준 CPython 3.12와 다르며 FFmpeg/FFprobe 또는 제품 전용 환경이 없을 수 있다. 발견된 문제는 설치하거나 수정하지 않고 blocker/risk로 기록한다.

## 판정

- ENV-01: **COMPLETE** — 지정 루트를 실제 Git 저장소로 초기화하고 기존 파일·Git·dirty state·디스크·경로 분리를 조사했다.
- VC-00: **BLOCKED / NOT ACCEPTED** — 실제 trusted dispatcher/host enforcement가 검증되지 않았고, unborn repository에는 권한 패킷이 결합할 base commit이 없다. stop code는 `USER_AUTHORIZATION_REQUIRED`이며 제품 구현 권한을 뜻하지 않는다.
- 제품 구현: **NOT STARTED** — 등록된 제품 Feature 76개 중 구현·검증 완료 0개다.

## 루트 및 경로 기준선

| 항목 | 관측값 | 판정 |
|---|---|---|
| CCS_REPO_ROOT | `E:\Custom_Contents_APP` | literal/resolve 일치 |
| CCS_SPEC_ROOT | `E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2` | repo와 별도, 상호 비중첩 |
| legacy root | `E:\AI_Automation\projects\friends_shadowing_ai_starter` | repo와 별도, 상호 비중첩 |
| reparse/link | 세 경로 모두 reparse point 아님, `LinkType=null` | PASS |
| volume | `E:` / NTFS / Fixed / Healthy | 로컬 고정 볼륨 |
| free space | 71,787,335,680 bytes (66.86 GiB) | 관측 시점 값 |
| failure domain | repo/spec/legacy 모두 `E:` | 논리 경로는 분리됐으나 물리 볼륨 장애영역은 공유 |
| package index SHA-256 | `30b0dea75a84948afc9e3d5006ccd6fdd5d8413cf9d33a3a86c4b6cd5787e01e` | 식별용; 전체 package 검증을 대신하지 않음 |

제품 설정·소스·import 파일이 없으므로 legacy import/call/shared mutable state 의존성은 발견되지 않았다. 이는 현재 빈 저장소에 대한 결론이며 향후 코드에 대한 보증은 아니다.

## Git 기준선

| 항목 | 관측값 |
|---|---|
| 초기화 명령 | `git init` (exit 0) |
| work tree | `E:/Custom_Contents_APP` |
| git dir | `E:/Custom_Contents_APP/.git` |
| bare | `false` |
| branch | `master` (Git이 생성한 기본 unborn branch; 변경하지 않음) |
| HEAD/base commit | 이 ENV-01 관측 시점에는 `UNBORN`; 이후 승인된 초기 기준선 커밋 작업은 `TRUSTED_DISPATCHER_VC00_VALIDATION.md`와 실행 결과가 정본 |
| remotes | 없음 |
| 기존 사용자 파일 | 초기화 전 0개 |
| 현재 의도된 변경 | 이 감사용 `reports/` 4개 파일만 untracked |

이 ENV-01 단계에서는 브랜치 생성/변경, Git config 변경, add/commit/push를 수행하지 않았다. 이후 별도 승인된 초기 기준선 커밋의 결과는 `TRUSTED_DISPATCHER_VC00_VALIDATION.md`와 실행 결과가 정본이며, 그 커밋도 trusted dispatcher를 증명하지 않는다.

## 실행환경 관측

| Capability | 절대 경로/관측 | 상태 |
|---|---|---|
| 제품 전용 Python | `.venv\Scripts\python.exe` 없음 | NOT INSTALLED |
| host `python` | `C:\Python314\python.exe`, Python 3.14.7, SHA-256 `4942b86a6597e5aee0128daa00050ed79bc21f6e709a78eb19cbfeb0c2f39ac9` | FOUND, 제품용 미선정; 설계 3.12.x와 불일치 |
| Python launcher | `C:\Windows\py.exe`, SHA-256 `a6b32b0ddcc53fa2e1a92905321ecfae80c2fb77abf2e313efc6238daad0f1ca` | FOUND; 3.14/3.11 등록, 제품용 미선정 |
| dependency manifest/lock | `pyproject.toml`, lock, requirements 없음 | NOT INSTALLED / NOT SELECTED |
| FastAPI/Uvicorn/Streamlit/Pydantic/settings/pytest/Ruff/mypy | host Python 3.14 `pip show` 전부 미발견 | NOT INSTALLED; 제품 환경 증거 아님 |
| FFmpeg | PATH에서 명령 해석 실패 | NOT INSTALLED / NOT FOUND |
| FFprobe | PATH에서 명령 해석 실패 | NOT INSTALLED / NOT FOUND |
| SQLite/product DB | DB 파일·migration·schema 없음 | NOT IMPLEMENTED; smoke NOT RUN |
| app/API/UI/worker/scheduler | entrypoint 없음 | NOT IMPLEMENTED; start NOT RUN |

환경변수 전체, 자격증명, token, cookie는 열람하거나 기록하지 않았다. PATH 이름만으로 도구 identity를 승인하지 않았으며, 발견된 host Python도 제품 interpreter로 채택하지 않았다.

## 명령 및 검증 기록

| 명령/검사 | 결과 |
|---|---|
| literal path / `Resolve-Path` / attributes / volume 검사 | PASS |
| 제한된 projects/related/archive/backups legacy 검색 | legacy root 1개 확인 |
| 최초 전체 `E:\AI_Automation` 재귀 검색 | 30초 내 결과 없음; 결론 근거에서 제외 |
| `git init` | exit 0 |
| `git rev-parse --show-toplevel` / `--absolute-git-dir` | exit 0 |
| `git rev-parse --verify HEAD` | exit 128, unborn repository의 예상 결과 |
| `python --version`, `py -0p` | exit 0 |
| `Get-Command ffmpeg`, `Get-Command ffprobe` | 미발견 |
| host Python `-m pip show` 8종 | 각 exit 1, 미설치 |
| 외부 provider/서비스 실행 | NOT RUN |
| 테스트/build/lint | 앱 및 테스트 없음; NOT RUN |

## 변경 및 비변경 확인

- 생성: `.git/`과 감사 보고서 4개.
- 앱 소스, `pyproject.toml`, lock, venv, `.env`, DB/migration, runtime data는 생성하지 않았다.
- 패키지 설치, service start, provider 호출, 외부 전송, Git add/commit/push는 수행하지 않았다.
- 설계 패키지와 legacy 저장소는 수정하지 않았다.

## 다음 단계 추천(미승인)

ENV-02에서 CPython 3.12 patch, 단일 lock/install workflow, FFmpeg/FFprobe 배치와 Streamlit UIX 호환성을 설계·확정하는 작업을 권장한다. 실행·설치·최초 커밋 및 다음 VC는 별도 범위다.
