# Capability Matrix — VC-00 / ENV-01

Date: 2026-09-07
Scope: 현재 host와 빈 제품 repository의 비파괴 관측

| Capability | Host/tool surface | Product repository | 검증 수준/결론 |
|---|---|---|---|
| Git | 2.55.0.windows.2 | initialized, unborn | 로컬 저장소만 준비됨; commit/remote 없음 |
| CPython 3.12.x | 미발견/미선정 | venv 없음 | REQUIRED, NOT INSTALLED |
| host Python | 3.14.7 | 미결합 | 관측만; 제품용 사용 금지 |
| FastAPI | host 3.14 미설치 | manifest/code 없음 | NOT INSTALLED |
| Uvicorn | host 3.14 미설치 | manifest/code 없음 | NOT INSTALLED |
| Streamlit | host 3.14 미설치 | manifest/code 없음 | NOT INSTALLED; UIX smoke NOT RUN |
| Pydantic/settings | host 3.14 미설치 | manifest/code 없음 | NOT INSTALLED |
| pytest/Ruff/mypy | host 3.14 미설치 | tests/config 없음 | NOT INSTALLED |
| SQLite | OS/Python 일반 capability는 제품 증거로 채택 안 함 | schema/DB/migration 없음 | PRODUCT NOT IMPLEMENTED |
| FFmpeg | PATH 미발견 | adapter/config 없음 | REQUIRED, NOT FOUND |
| FFprobe | PATH 미발견 | adapter/config 없음 | REQUIRED, NOT FOUND |
| local storage | `E:` NTFS Fixed, 66.86 GiB free | runtime layout 없음 | 디스크 존재만 확인; isolation NOT IMPLEMENTED |
| Canva host connector | 현재 Codex session에 callable tool surface 있음 | adapter/config 없음 | HOST SURFACE ONLY; auth/connectivity NOT RUN |
| Google Drive host connector | 현재 Codex session에 callable tool surface 있음 | adapter/config 없음 | HOST SURFACE ONLY; auth/connectivity NOT RUN |
| Higgsfield | callable tool surface 미발견 | adapter/config 없음 | UNAVAILABLE / NOT RUN |
| Google Flow | callable connector 미발견 | manual handoff 구현 없음 | UNAVAILABLE / NOT RUN |
| YouTube/Meta/TikTok publishing | callable 제품 connector/adapter 없음 | adapter/config 없음 | UNAVAILABLE / NOT RUN |
| Cloud/object storage | 제품용 connector/credential/config 없음 | adapter/config 없음 | UNAVAILABLE / NOT RUN |
| trusted dispatcher | repository 밖 실제 enforcement 증거 없음 | active receipt/packet 없음 | REQUIRED EXTERNAL BLOCKER |

`HOST SURFACE ONLY`는 제품 기능이나 계정 인증, provider 접근, 실제 업로드/게시 권한을 의미하지 않는다. 자격증명 확인과 외부 호출은 이번 범위에서 하지 않았다.
