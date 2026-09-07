# Risk Register — VC-00 / ENV-01

Date: 2026-09-07

| ID | 심각도 | 위험/근거 | 현재 영향 | 처리/소유 단계 |
|---|---|---|---|---|
| R-VC00-001 | P0 BLOCKER | trusted host/dispatcher가 실제 user turn 인증, monotonic authority, receipt injection, mutation-tool enforcement를 제공한다는 증거가 없음 | VC-00 PASS/ACCEPTED 및 제품 leaf 활성화 불가; `USER_AUTHORIZATION_REQUIRED` | host 통합/VC-00 별도 검증 |
| R-VC00-002 | P0 BLOCKER | repository가 unborn이며 base commit이 없음 | digest-bound work packet과 writer baseline의 base commit 고정 불가 | 초기 scaffold 승인 후 별도 initial commit 결정 |
| R-ENV-001 | P0 | 설계 기준 CPython 3.12.x 전용 interpreter가 없고 host 기본은 3.14.7 | 버전 호환성·module origin·lock 재현성 미확정 | ENV-02에서 patch/lock workflow 확정, ENV-03 설치 |
| R-ENV-002 | P0 | FFmpeg/FFprobe가 PATH에서 발견되지 않음 | VC-02 media smoke 및 필수 media 기능 불가 | ENV-02 배치/버전 결정, ENV-03 설치, VC-02 검증 |
| R-ENV-003 | P0 | pyproject/committed lock/venv/제품 dependencies가 없음 | API/UI/test 실행 불가 | ENV-02/03 |
| R-ENV-004 | P0 | 소스·schema·migration·config·tests가 0개 | VC-01 actual-code 비교 및 제품 smoke 불가 | 후속 승인 단계; 현재는 정직하게 NOT IMPLEMENTED |
| R-VC00-003 | P1 | current host tool 목록은 제품 adapter/계정/capability grant가 아님 | connector availability를 제품 통합 PASS로 오판할 수 있음 | 각 adapter leaf와 provider-safe smoke에서 별도 검증 |
| R-ENV-005 | P1 | repo/spec/legacy가 같은 `E:` 물리 볼륨을 공유 | 디스크 장애영역 분리는 제공하지 않음 | 운영 storage/backup 배치 설계에서 별도 failure domain 확보 |
| R-ENV-006 | P1 | repository `.gitignore`가 아직 없음 | venv/runtime/secret 생성 전에 ignore 정책이 없으면 오추적 위험 | 실제 scaffold/ENV-02에서 정책 고정 후 최초 생성; 현재 비밀/runtime 파일 없음 |
| R-ENV-007 | P2 | Git 기본 unborn branch가 `master`로 생성됨 | 장래 branch 정책과 다를 수 있음 | branch/commit 정책 승인 시 결정; 이번에는 변경 안 함 |
| R-AUDIT-001 | P2 | 최초 광범위 legacy 재귀 검색이 제한 시간 내 완료되지 않음 | 해당 실행을 증거로 쓸 수 없음 | 제한된 관련 경로 검색과 정확한 known legacy path resolve로 대체 완료 |

현재 외부 전송·게시·결제·credential 변경·migration·삭제는 없었다. 위험을 해결하기 위한 설치나 설정 변경은 이번 단계에서 수행하지 않았다.
