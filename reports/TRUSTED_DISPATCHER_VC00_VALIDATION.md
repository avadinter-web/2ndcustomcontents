# Trusted Dispatcher / VC-00 Validation

Status: `USER_AUTHORIZATION_REQUIRED` / VC-00 `BLOCKED / NOT ACCEPTED`
Date: 2026-09-07
Target: `E:\Custom_Contents_APP`

understood as: 사용자가 승인한 두 작업은 현재 환경 스캐폴드를 정확히 한 번의 로컬 초기 기준선 커밋으로 고정하고, 이 Codex 실행 표면에 실제 trusted host/dispatcher가 제공하는 인증·단조 authority·receipt injection·mutation capability 통제가 존재하는지를 규범 계약 7절과 8절에 따라 증거로 감사하는 것이다. 로컬 JSON·해시·사용자 대화의 재기록은 신뢰 증거로 만들지 않으며, 해당 host interface가 노출되지 않으면 `USER_AUTHORIZATION_REQUIRED`와 VC-00 차단을 유지한다. 제품 코드·DB·migration·서비스·provider·remote·push는 범위 밖이다.

## Scope, risks, completion criteria

- 범위: 현재 agent/tool surface, 저장소 상태, 로컬 환경 보고서와 `TRUSTED_DISPATCHER_BOUNDARY.md` 7절·8절 요구사항을 비교한다. 승인된 파일만 stage하여 초기 로컬 커밋을 한 번 만든다.
- 변경 허용: `.env.example`, `.gitignore`, `README.md`, `pyproject.toml`, `requirements.lock`, `reports/*.md`.
- 변경 금지: 제품 source/tests/migrations/DB, `.venv`, `.runtime`, 실제 `.env`, 비밀값, 설계 패키지, Git 설정·브랜치명·remote, provider/service 실행.
- 주요 위험: 사용자 요청 자체는 작업 의사를 명확히 하지만 규범 계약이 요구하는 host-owned turn record나 repository writer 밖의 mutation grant를 대체하지 않는다. 로컬 커밋 생성은 되돌릴 수 있으나, 이를 VC-00 PASS 또는 제품 구현 권한으로 오인하면 self-authorization이 된다.
- 완료 기준: literal allowlist만 stage되고 ignored runtime/secret 경계와 staged secret scan이 통과하며, lock/toolchain 보고가 현재 파일과 일치하고 `git diff --cached --check`가 통과한 뒤 정확히 한 번의 초기 local commit이 생성된다. Dispatcher 판정은 실제 증거가 없으면 명시적 BLOCKED로 종료한다.

## Actual host/dispatcher evidence audit

현재 Codex agent에 제공된 실행 표면에는 authenticated host user/session/immutable-turn record를 조회하거나, host가 CCS-TEXT-1을 계산하거나, protected monotonic authority stream을 조회·갱신하거나, ACTIVE/ACCEPTED receipt를 주입하거나, repository writer 밖에서 실제 filesystem/tool mutation capability를 grant/deny하는 인터페이스가 없다. 사용 가능한 로컬 shell, filesystem 및 Git 기능은 repository writer와 같은 신뢰 영역에 있으며 trusted dispatcher 증거가 아니다.

| Section 7 required evidence | Available evidence | Verdict |
|---|---|---|
| 실제 trusted host/dispatcher 이름·버전·deployment boundary | agent surface에 식별/attestation API 없음 | ABSENT |
| authenticated user/workspace/session/immutable turn source | host-owned record 조회 API 없음; 대화 텍스트를 agent가 보는 것만으로는 불충분 | ABSENT |
| host-source exact body + CCS-TEXT-1 independent computation | host 측 digest/correlation 결과 없음 | ABSENT |
| protected monotonic stream, freshness/replay/revocation/expiry | repository writer가 접근할 수 없는 stream/record 없음 | ABSENT |
| receipt injection + out-of-band dispatch mediation | injection/grant API 및 writer 밖 enforcement point 없음 | ABSENT |
| host record ↔ exact receipt digest/path correlation | host audit locator/record 없음 | ABSENT |
| Section 8 actual-runtime positive/negative results | actual dispatcher harness가 없어 실행 불가 | NOT RUN |
| offline/stale/revoked resume behavior | actual host control plane을 호출할 수 없어 실행 불가 | NOT RUN |
| no secret/raw-message leakage | 이 감사는 secret/token/cookie/raw credential을 읽거나 기록하지 않음 | PASS (local evidence hygiene only) |

## Section 8 runtime cases

Section 8의 모든 authority 관련 케이스는 repository writer와 다른 신뢰 영역의 실제 host/dispatcher가 필요하다. 이 표면에는 그 대상이나 harness가 없으므로 positive authorization, separate acceptance, forged-receipt sentinel denial, field tamper denial, replay rejection, revocation/expiry denial, ambiguous continuation denial, offline fail-closed 및 action-type mismatch를 실제 enforcement point에 대해 실행할 수 없다. 로컬 mock이나 schema validator로 대체하지 않았다.

어떠한 DRAFT/ACTIVE/ACCEPTED receipt, host attestation, writer lease, task registry, fake audit locator 또는 sentinel mutation도 생성하지 않았다. 사용자 메시지는 로컬 receipt로 복제하거나 해시하지 않았다.

## Decision

- Initial repository baseline: 이 감사와 함께 승인된 scaffold 파일만 대상으로 정확히 한 번의 local root commit을 생성한다. 최종 commit SHA와 clean-status 증거는 실행 결과에서 보고한다. 자기 자신의 SHA를 commit 내용에 순환 삽입하지 않는다.
- Trusted dispatcher/host control: **NOT VERIFIED / CAPABILITY ABSENT FROM CURRENT AGENT SURFACE**.
- Canonical stop code: **`USER_AUTHORIZATION_REQUIRED`**.
- VC-00: **BLOCKED / NOT ACCEPTED**.
- Product implementation authority: **DENIED**. 제품 Feature 구현 진행률은 `0/76 (0%)`다.

VC-00을 PASS로 바꾸려면 실제 Codex deployment가 Section 7 evidence manifest와 Section 8 host-enforced test 결과를 제공해야 한다. 로컬 baseline commit이나 환경 검사 PASS는 이를 충족하지 않는다.
