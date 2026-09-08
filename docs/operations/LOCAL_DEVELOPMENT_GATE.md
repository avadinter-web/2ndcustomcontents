# Local Development Gate (LD-00)

Status: `PASS / ACCEPTED FOR LOCAL DEVELOPMENT ONLY`
Scope: `E:\Custom_Contents_APP` local implementation and verification

understood as: 사용자는 조직 관리형 VC-00의 외부 provenance 요구를 현재 구현 착수 조건에서 제외하고, 이미 검증한 로컬 PreToolUse 보호를 LD-00으로 채택했다. 이 결정을 운영 배포, 원격 업데이트 또는 조직 보안 준수 선언으로 해석하지 않는다.

## Accepted controls

| Control | Verified evidence | Result |
|---|---|---|
| Protected policy and hook | SYSTEM ownership, protected ACL, frozen SHA-256 | `PASS` |
| Effective configuration | Codex Desktop App Server returned the managed Windows requirements and PreToolUse matcher | `PASS` |
| Runtime audit | `CustomContentStudioManagedGate` Application events record sanitized allow/deny decisions | `PASS` |
| Fail-closed app-root check | Codex CLI app-root `Set-Content -WhatIf` intent was denied as `D100_VC00_BLOCKED`; probe file remained absent | `PASS` |
| Evidence record | Validation report and recheck protocol retain non-secret verification data | `PASS` |

## Explicit limitations

- Local administrator access, physical device access, or a compromised host can alter this protection; LD-00 does not claim resistance to those actors.
- LD-00 does not prove MDM enrollment, signed package provenance, remote policy enforcement, immutable user-turn binding, authority lifecycle, or host-issued mutation receipts.
- The gate may be used only for local source changes, tests, local database files, and local media-tool validation. It grants no authority for deployment, publishing, external transmission, billing, credential changes, or remote updates.

## Direct local leaf authorization

For this repository's LD-00 profile only, an explicit user decision in the active Codex
conversation may authorize one exact local-development leaf after its scope has been presented,
or a bounded serial local-leaf scope that follows the frozen design order. This is a local
development control, not a replacement for the package's trusted-dispatcher boundary. The
decision must be recorded in an attempt-scoped local work packet together with:

- one canonical leaf ID, parent `IMP-*` package, exact repository and frozen-registry revision;
- the exact allowed paths, tests, commands, exclusions and no-external-effect policy;
- the preceding assistant scope presentation, the user decision locator, and, for serial scope,
  its exact excluded action classes and design-order boundary;
- one writer/worktree and a fresh preflight check of LD-00, VC-01, VC-01B and VC-02 evidence.

The local record must use a distinct `LD00_DIRECT_USER_AUTHORIZATION` authority label. It must
never claim `ACTIVE` trusted-dispatcher status, host injection, MDM provenance, or authority to
perform deployment, publishing, credential changes, billing, remote updates, external writes or
destructive actions. A serial decision applies only while its stated design-order boundary and
exclusions remain unchanged; otherwise a new user decision is required.

## Re-entry criteria for managed or production work

Before the first CI/CD connection, remote updater, shared-writer workflow, external release, production deployment, or public content publication, stop and reactivate [Managed deployment handoff](MANAGED_DEPLOYMENT_HANDOFF.md). Complete its provenance evidence and obtain the separately required user approval for the external action.

## Linked verification

- [Implementation unlock checklist](IMPLEMENTATION_UNLOCK_CHECKLIST.md)
- [Local recheck protocol](VC00_RECHECK_PROTOCOL.md)
- [Current validation report](../../reports/TRUSTED_DISPATCHER_VC00_VALIDATION.md)
