# Implementation Unlock Checklist

Status: `LD-00 PASS / ACCEPTED FOR LOCAL DEVELOPMENT ONLY`
Canonical stop code: `LOCAL_DEVELOPMENT_GATE_MISMATCH`
Verified product progress: `0/76 (0%)`

understood as: 조직 관리형 VC-00 요구를 로컬 개발 안전 게이트 LD-00으로 대체한다. LD-00은 현재 장치의 정책·훅·런타임 차단을 검증하여 개발을 시작시키지만, 조직 관리 배포·원격 업데이트·운영 보안 승인을 증명하지 않는다.

## 1. LD-00 local-development gate

LD-00은 이 개발 장치에서만 유효하다. SYSTEM 소유/보호 ACL, 고정 해시, effective configuration, 실제 Codex CLI app-root 차단과 무부작용 probe 부재를 확인한다. 이 확인은 로컬 관리자·물리 장치 접근자·Codex 호스트 제공자를 상대로 한 신뢰 경계를 만들지 않는다.

| # | Local control | `PASS` 조건 | 현재 |
|---|---|---|---|
| 1 | Protected active files | requirements와 hook이 기대 SHA-256이며 SYSTEM 소유·보호 ACL이고 일반 사용자 쓰기가 불가함 | `PASS` |
| 2 | Effective hook configuration | Codex Desktop App Server가 Windows managed requirements와 `PreToolUse` matcher를 효과적으로 읽음 | `PASS` |
| 3 | Runtime event sink | 실제 PreToolUse 실행이 allowlist 형식의 Windows Application event를 남김 | `PASS` |
| 4 | App-root fail-closed probe | `E:\Custom_Contents_APP`에서 실제 Codex CLI가 mutation 의도를 `D100_VC00_BLOCKED`로 실행 전 거부하고 probe 파일이 없음 | `PASS` |
| 5 | Local verification record | 해시·ACL·이벤트·probe 결과가 비밀정보 없이 검증 보고서에 보존됨 | `PASS` |

LD-00은 다섯 항목이 모두 `PASS`이고 사용자가 이 문서의 로컬 개발 한계를 수락했을 때만 `PASS`다. 한 항목이라도 `FAIL`, `UNKNOWN`, 해시 불일치, ACL 약화, 이벤트 누락 또는 비밀정보 노출이면 `BLOCKED`다. LD-00 통과는 다음 leaf를 자동 시작시키지 않는다.

### Local-development boundary

- 허용 범위: 로컬 저장소 코드·테스트·개발용 DB·로컬 미디어 도구의 구현과 검증.
- 금지 범위: 운영 배포, 실제 콘텐츠 게시, 외부 계정·API credential 변경, 유료 결제, 원격 업데이트 배포, 조직 보안 준수 선언.
- 재평가: 공유 장치, 외부 협업자 write access, CI/CD, 원격 업데이트 또는 운영 배포를 시작하기 전에는 `MANAGED_DEPLOYMENT_HANDOFF.md`의 조직 관리형 증거를 다시 활성화하고 별도 승인을 받는다.

## 2. Product-code start gates

제품 코드 변경은 다음 네 게이트가 실제 구현 저장소 증거로 각각 `PASS`이고 별도 `ACCEPTED`일 때만 시작한다.

- [x] LD-00: local-development safety gate (조직 관리형 VC-00 대체, 로컬 개발에 한정)
- [x] VC-01: executable contract freeze (local-development profile; see `reports/VC-01_CONTRACT_FREEZE.md`)
- [x] VC-01B: implementation readiness 및 immutable runtime leaf registry (local-development planning only; `reports/VC-01B_IMPLEMENTATION_READINESS.md`)
- [x] VC-02: FFmpeg/FFprobe media toolchain smoke (local-development only; `reports/VC-02_GATE_RESULT.md`)

추가 필수 조건:

- 활성 task는 0개 또는 1개이며, 실행 시 정확히 하나의 canonical leaf와 하나의 writer/worktree만 존재한다.
- 현재 base commit, dirty-state ownership, spec/package digest, task-registry digest, work-packet digest가 ACTIVE authorization과 일치한다.
- 승인된 경로 allowlist, 명령, 테스트, evidence 요구사항 밖의 변경은 하지 않는다.
- 패키지 `IMPLEMENTATION_REGISTRY.json`의 `IMP-*` 항목은 비직접 work package이므로 그 자체를 실행 권한으로 사용하지 않는다.
- LD-00 직접 실행은 [로컬 직접 권한 프로토콜](LOCAL_DIRECT_AUTHORIZATION_PROTOCOL.md)의
  `LD00_DIRECT_USER_AUTHORIZATION` 기록, 정확한 leaf 범위 제시 후의 명시적 사용자 승인,
  그리고 attempt-scoped work packet을 모두 요구한다. 이 기록은 trusted-dispatcher
  `ACTIVE` receipt나 운영 권한을 대체하지 않는다.

## 3. Exact first implementation tranche

아래 순서는 기존 `IMPLEMENTATION_REGISTRY.json`과 `11_CODEX_TASKS/00_EXECUTION_ORDER.md`를 따른다. 실제 작업은 VC-01B가 생성한 immutable runtime registry의 canonical leaf ID로 한 번에 하나만 실행한다. 이 문서의 단계명은 권한 토큰이 아니다.

### A. `IMP-010` — Repository scaffold, composition root and runtime profiles

- 기존 `pyproject.toml`, committed lock, `.gitignore`, `.env.example`를 검증하고 실제 비밀값이 추적되지 않음을 확인한다.
- 기준 스택을 확정한다: CPython 3.12.x, FastAPI/Uvicorn, Streamlit API-only UI, Pydantic v2/settings, Python `sqlite3`, CCS migration runner/worker, FFmpeg/FFprobe, pytest/Ruff/mypy.
- `src/custom_content_studio/`, 단일 `bootstrap/composition.py`, DEV/STAGING/PROD loader와 API/UI/worker/scheduler/CLI entrypoint 골격을 만든다.
- 완료 증거: 각 entrypoint clean boot, optional-provider failure isolation, PowerShell 명령 기록.

### B. `IMP-011` — SQLite migration runner and transaction kernel

- migration manifest/index, baseline schema bootstrap, SQLite repositories와 UnitOfWork 경계를 구현한다.
- startup에서 migration ID/checksum, `foreign_keys`, WAL, `busy_timeout`을 검증한다.
- 완료 증거: 빈 DB migration, 재시작 지속성, drift/checksum 거부, 실패 migration rollback 안전성.

### C. `IMP-012` — Authentication, secret references and ActorContext

- session service, secret-store port, workspace authorization middleware, audit-safe request context를 구현한다.
- 역할별 action matrix와 cross-workspace denial을 강제하고 raw secret을 DB·로그·문서에 저장하지 않는다.
- 완료 증거: hash-only session, cross-workspace denial, role-action matrix, secret masking.

### D. `IMP-013` — API, Streamlit UI and process health shells

- FastAPI application, API client만 사용하는 Streamlit shell, health/readiness endpoint와 structured logging을 구현한다.
- 공통 header/navigation/current-page/work-area 구조와 승인된 theme token을 위한 단일 source를 마련하되, 내구성 있는 도메인 상태를 UI에 두지 않는다.
- 완료 증거: UI durable-state 없음, request correlation 확인, 모든 entrypoint clean shutdown.
- 범위 제한: 최종 01~10 독립 페이지, 색상·접근성·viewport/overflow 전체 구현과 screenshot/interaction 수용 증거는 `UIX-01..04`가 결합된 `IMP-070` 범위다. 이를 `IMP-013` 완료로 가장하거나 선행 구현하지 않는다.

## 4. Stop conditions

다음 중 하나가 발생하면 현재 leaf를 즉시 멈추고 기존 사용자 파일을 되돌리지 않은 채 정확한 stop code와 증거를 기록한다.

- LD-00 해시/ACL/effective configuration/runtime deny 증거 불일치: `LOCAL_DEVELOPMENT_GATE_MISMATCH`
- spec, registry, work packet, repository, result/evidence digest 불일치: `SPEC_DIGEST_MISMATCH`
- schema, binding, injection path 또는 evidence envelope 불완전: `TASK_ENVELOPE_INCOMPLETE`
- replay, monotonic order, 최신 상태 또는 resume ownership 모호: `RECOVERY_STATE_AMBIGUOUS`
- generic continuation 또는 이전 acceptance로 후속 task 활성화 시도: `NEXT_TASK_NOT_AUTHORIZED`
- scope/architecture/stack 변경 필요: 현재 leaf 중지 후 승인된 change control 및 필요한 ADR; 임의 확장 금지
- 배포, 실제 게시, 외부 전송, credential 변경, 파괴적 변경 또는 비가역 migration에 별도 명시 승인이 없음
- 테스트·lint·type check·migration·spec sync 중 필수 항목 실패

## 5. Source links

- [Current VC-00 validation](../../reports/TRUSTED_DISPATCHER_VC00_VALIDATION.md)
- [Local development gate](LOCAL_DEVELOPMENT_GATE.md)
- [Repository baseline](../../reports/VC-00_BASELINE_AUDIT.md)
- Specification: `00_MASTER/CODEX_START_HERE.md`
- Specification: `00_MASTER/IMPLEMENTATION_BASELINE.md`
- Specification: `IMPLEMENTATION_REGISTRY.json`
- Specification: `14_CODEX_ORCHESTRATION/TRUSTED_DISPATCHER_BOUNDARY.md`

## 6. Delivery policy

사용자 지시(2026-09-07): 다음 구현 단위부터 해당 단위의 필수 검증이 모두 통과하면, 그 단위의 변경만 별도 Git commit으로 만들고 configured upstream remote에 자동 push한다.

- 검증 실패, scope guard 실패, 미해결 blocker 또는 사용자 파일 소유권이 불명확한 경우에는 commit/push하지 않고 해당 단위를 `BLOCKED` 또는 `FAILED`로 보고한다.
- 현재의 gate 문서·레지스트리 변경은 이 지시 이전에 발생했으므로 다음 구현 단위의 자동 commit에 섞지 않는다.
- remote가 없거나 upstream이 모호하면 remote URL/branch를 임의로 생성·추정하지 않는다. 구현·검증은 진행하되 push만 보류하고 정확한 대상이 설정된 뒤 재개한다.
