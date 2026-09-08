param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR6Sha256 = "75f316ed32e672a1143909afa96add5c88e9a9694d4ed3a6f97ce09736f96cf8"
$expectedDiscoverySha256 = "b19c5de6e064db201f8577a759c9841e12015f7b8371ee14f2624af132169fff"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r6Path = Join-Path $revisionRoot "vc01b-local-20260907-r6\task-registry.json"
$r7Dir = Join-Path $revisionRoot "vc01b-local-20260907-r7"
$r7Path = Join-Path $r7Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-01-006_DISCOVERY_WORK_PACKET.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01-006_CONFLICT_RESOLUTION.md"

if (-not (Test-Path -LiteralPath $r6Path -PathType Leaf)) {
    throw "Missing immutable r6 source: $r6Path"
}
if (-not (Test-Path -LiteralPath $discoveryPath -PathType Leaf)) {
    throw "Missing CCS-01-006 discovery packet: $discoveryPath"
}
if (Test-Path -LiteralPath $r7Dir) {
    throw "Refusing to overwrite immutable r7: $r7Dir"
}
if (Test-Path -LiteralPath $reportPath) {
    throw "Refusing to overwrite conflict report: $reportPath"
}

$r6Sha256 = (Get-FileHash -LiteralPath $r6Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r6Sha256 -ne $expectedR6Sha256) {
    throw "Unexpected r6 SHA-256: $r6Sha256"
}
$discoverySha256 = (Get-FileHash -LiteralPath $discoveryPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($discoverySha256 -ne $expectedDiscoverySha256) {
    throw "Unexpected discovery packet SHA-256: $discoverySha256"
}

$registry = Get-Content -LiteralPath $r6Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r6") {
    throw "Unexpected source registry_id: $($registry.registry_id)"
}
if ($registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized -ne $false) {
    throw "r6 must remain DRAFT and unauthorized"
}

$leaves = @($registry.tasks | Where-Object { $_.leaf_task_id -eq "CCS-01-006" })
if ($leaves.Count -ne 1) {
    throw "Expected exactly one CCS-01-006 leaf, found $($leaves.Count)"
}
$leaf = $leaves[0]
if ($leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") {
    throw "CCS-01-006 must remain DISCOVERY_REQUIRED"
}
if ($leaf.parent_work_package_id -ne "IMP-011") {
    throw "Expected r6 mismatch IMP-011, found $($leaf.parent_work_package_id)"
}
if (@($leaf.allowed_paths).Count -ne 0 -or @($leaf.create_paths).Count -ne 0 -or @($leaf.modify_paths).Count -ne 0) {
    throw "CCS-01-006 r6 discovery leaf unexpectedly permits paths"
}

$implementationRegistryPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$taskBreakdownPath = Join-Path $SpecRoot "11_CODEX_TASKS\CCS-01_TASKS.md"
$implementationRegistrySha256 = (Get-FileHash -LiteralPath $implementationRegistryPath -Algorithm SHA256).Hash.ToLowerInvariant()
$taskBreakdownSha256 = (Get-FileHash -LiteralPath $taskBreakdownPath -Algorithm SHA256).Hash.ToLowerInvariant()
$implementationRegistry = Get-Content -LiteralPath $implementationRegistryPath -Raw | ConvertFrom-Json
$normativeSlices = @($implementationRegistry.slices | Where-Object { $_.slice_id -eq "IMP-012" })
if ($normativeSlices.Count -ne 1) {
    throw "Expected exactly one normative IMP-012 slice"
}
$normativeSlice = $normativeSlices[0]
if ($normativeSlice.title -ne "Authentication, secret references and ActorContext") {
    throw "Unexpected normative IMP-012 title: $($normativeSlice.title)"
}
if (@($normativeSlice.depends_on) -notcontains "IMP-011") {
    throw "Normative IMP-012 must depend on IMP-011"
}

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Cannot resolve current repository commit"
}

$registry.registry_id = "vc01b-local-20260907-r7"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-006"
$registry.context.next_recommendation.candidate_slice_id = "IMP-012"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "Discovery evidence is complete; bind its exact allowlist to a separate ACTIVE local work packet under normative IMP-012 before implementation."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-006_CONFLICT_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$leaf.parent_work_package_id = "IMP-012"
$leaf.in_scope = @(
    "Discovery-only planning for CCS-01-006 from 11_CODEX_TASKS/CCS-01_TASKS.md#L15.",
    "Normative ownership corrected to IMP-012; exact local-only paths, interfaces and tests are bound by reports/CCS-01-006_DISCOVERY_WORK_PACKET.md.",
    "DISCOVERY BLOCKER [CCS-01-006]: issue a separate ACTIVE local work packet; this DRAFT registry grants no write or credential authority."
)

$resolvedCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "RESOLVED" }).Count
$discoveryCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "DISCOVERY_REQUIRED" }).Count

$report = @"
# CCS-01-006 Contract Conflict Resolution

Status: ``DRAFT / NOT AUTHORIZED``
Date: 2026-09-08

## Outcome

The r6 parent assignment for ``CCS-01-006`` is corrected from ``IMP-011`` to normative ``IMP-012`` in immutable successor r7. The leaf remains ``DISCOVERY_REQUIRED`` with no writable paths, no credential permission and no implementation authority.

| Item | r6 | r7 |
|---|---|---|
| Registry ID | ``vc01b-local-20260907-r6`` | ``vc01b-local-20260907-r7`` |
| CCS-01-006 parent | ``IMP-011`` | ``IMP-012`` |
| Leaf path status | ``DISCOVERY_REQUIRED`` | ``DISCOVERY_REQUIRED`` |
| Registry status | ``DRAFT`` | ``DRAFT`` |
| Implementation authorized | ``false`` | ``false`` |

## Normative evidence

- ``IMPLEMENTATION_REGISTRY.json`` assigns the session service, SecretStore port, Workspace authorization middleware and audit-safe ActorContext to ``IMP-012``.
- ``IMP-012`` depends on ``IMP-011``; authentication/session ownership is not transferred to the SQLite kernel.
- ``11_CODEX_TASKS/CCS-01_TASKS.md`` defines legacy task ``01-06`` as secret references, basic roles and masking.
- ``reports/CCS-01-006_DISCOVERY_WORK_PACKET.md`` closes the exact local-only source, interface, test, safety and approval contract without granting execution authority.

Evidence bindings:

- r6 SHA-256: ``$r6Sha256``
- discovery packet SHA-256: ``$discoverySha256``
- specification ``IMPLEMENTATION_REGISTRY.json`` SHA-256: ``$implementationRegistrySha256``
- specification ``11_CODEX_TASKS/CCS-01_TASKS.md`` SHA-256: ``$taskBreakdownSha256``
- repository baseline commit: ``$currentCommit``

## Preserved fail-closed state

- total leaves: $($registry.tasks.Count)
- ``RESOLVED``: $resolvedCount
- ``DISCOVERY_REQUIRED``: $discoveryCount
- readiness decision: ``NOT_EVALUATED``
- CCS-01-006 allowed/create/modify paths remain empty
- CCS-01-006 forbidden paths remain ``**``
- external side effects and migrations remain forbidden
- no product code, tests, credentials, accounts, runtime database or existing registry is changed by this correction

## Approval boundary and next action

No credential or provider-account approval is required for this registry-only correction. Actual credential/account/OS secret changes remain prohibited and would require a separate explicit approval. The next orchestration action is a separate attempt-scoped ACTIVE local work packet that copies the exact allowlist and contract from the bound discovery packet. r7 itself cannot authorize implementation or activate a successor leaf.

## Reproduction

Run ``.codex/ccs/tools/New-R7CCS01006ConflictResolution.ps1`` from any PowerShell working directory. The generator binds exact r6 and discovery-packet SHA-256 values and refuses to overwrite an existing r7 directory or report.
"@

[IO.File]::WriteAllText($reportPath, $report, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r7Dir) | Out-Null
[IO.File]::WriteAllText($r7Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r7Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") {
    throw "Bad registry digest output: $digest"
}
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r7Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    source_r6_sha256 = $r6Sha256
    discovery_packet_sha256 = $discoverySha256
    r7_path = $r7Path
    r7_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    resolved = $resolvedCount
    discovery_required = $discoveryCount
    implementation_authorized = $registry.implementation_authorized
} | Format-List
