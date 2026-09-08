param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR7Sha256 = "3e9f6de7301ac9d60e660b5e3ba7802f4a1abbb07144d7876c7ec00dcc8e51c9"
$expectedDiscoverySha256 = "dbc4b9f3f1b441223aafdbab58761d5fc3c0de0e9b8f40af90ad50c7d1396601"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r7Path = Join-Path $revisionRoot "vc01b-local-20260907-r7\task-registry.json"
$r8Dir = Join-Path $revisionRoot "vc01b-local-20260907-r8"
$r8Path = Join-Path $r8Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-01-007_DISCOVERY_WORK_PACKET.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01-007_CONFLICT_RESOLUTION.md"

if (-not (Test-Path -LiteralPath $r7Path -PathType Leaf)) {
    throw "Missing immutable r7 source: $r7Path"
}
if (-not (Test-Path -LiteralPath $discoveryPath -PathType Leaf)) {
    throw "Missing CCS-01-007 discovery packet: $discoveryPath"
}
if (Test-Path -LiteralPath $r8Dir) {
    throw "Refusing to overwrite immutable r8: $r8Dir"
}
if (Test-Path -LiteralPath $reportPath) {
    throw "Refusing to overwrite conflict report: $reportPath"
}

$r7Sha256 = (Get-FileHash -LiteralPath $r7Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r7Sha256 -ne $expectedR7Sha256) {
    throw "Unexpected r7 SHA-256: $r7Sha256"
}
$discoverySha256 = (Get-FileHash -LiteralPath $discoveryPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($discoverySha256 -ne $expectedDiscoverySha256) {
    throw "Unexpected discovery packet SHA-256: $discoverySha256"
}

$registry = Get-Content -LiteralPath $r7Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r7") {
    throw "Unexpected source registry_id: $($registry.registry_id)"
}
if ($registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized -ne $false) {
    throw "r7 must remain DRAFT and unauthorized"
}

$leaves = @($registry.tasks | Where-Object { $_.leaf_task_id -eq "CCS-01-007" })
if ($leaves.Count -ne 1) {
    throw "Expected exactly one CCS-01-007 leaf, found $($leaves.Count)"
}
$leaf = $leaves[0]
if ($leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") {
    throw "CCS-01-007 must remain DISCOVERY_REQUIRED"
}
if ($leaf.parent_work_package_id -ne "IMP-012") {
    throw "Expected r7 mismatch IMP-012, found $($leaf.parent_work_package_id)"
}
if (@($leaf.allowed_paths).Count -ne 0 -or @($leaf.create_paths).Count -ne 0 -or @($leaf.modify_paths).Count -ne 0) {
    throw "CCS-01-007 r7 discovery leaf unexpectedly permits paths"
}

$implementationRegistryPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$taskBreakdownPath = Join-Path $SpecRoot "11_CODEX_TASKS\CCS-01_TASKS.md"
$implementationRegistrySha256 = (Get-FileHash -LiteralPath $implementationRegistryPath -Algorithm SHA256).Hash.ToLowerInvariant()
$taskBreakdownSha256 = (Get-FileHash -LiteralPath $taskBreakdownPath -Algorithm SHA256).Hash.ToLowerInvariant()
$implementationRegistry = Get-Content -LiteralPath $implementationRegistryPath -Raw | ConvertFrom-Json
$normativeSlices = @($implementationRegistry.slices | Where-Object { $_.slice_id -eq "IMP-013" })
if ($normativeSlices.Count -ne 1) {
    throw "Expected exactly one normative IMP-013 slice"
}
$normativeSlice = $normativeSlices[0]
if ($normativeSlice.title -ne "API, Streamlit UI and process health shells") {
    throw "Unexpected normative IMP-013 title: $($normativeSlice.title)"
}
if (@($normativeSlice.depends_on) -notcontains "IMP-010" -or @($normativeSlice.depends_on) -notcontains "IMP-012") {
    throw "Normative IMP-013 must depend on IMP-010 and IMP-012"
}

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Cannot resolve current repository commit"
}

$registry.registry_id = "vc01b-local-20260907-r8"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-007"
$registry.context.next_recommendation.candidate_slice_id = "IMP-013"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "Discovery evidence is complete; bind its exact allowlist to a separate ACTIVE local work packet under normative IMP-013 before implementation."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-007_CONFLICT_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$leaf.parent_work_package_id = "IMP-013"
$leaf.in_scope = @(
    "Discovery-only planning for CCS-01-007 from 11_CODEX_TASKS/CCS-01_TASKS.md#L16.",
    "Normative ownership corrected to IMP-013; exact local-only paths, interfaces and tests are bound by reports/CCS-01-007_DISCOVERY_WORK_PACKET.md.",
    "DISCOVERY BLOCKER [CCS-01-007]: issue a separate ACTIVE local work packet; this DRAFT registry grants no write or external observability authority."
)

$resolvedCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "RESOLVED" }).Count
$discoveryCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "DISCOVERY_REQUIRED" }).Count

$report = @"
# CCS-01-007 Contract Conflict Resolution

Status: ``DRAFT / NOT AUTHORIZED``
Date: 2026-09-08

## Outcome

The r7 parent assignment for ``CCS-01-007`` is corrected from ``IMP-012`` to normative ``IMP-013`` in immutable successor r8. The leaf remains ``DISCOVERY_REQUIRED`` with no writable paths, no external observability permission and no implementation authority.

| Item | r7 | r8 |
|---|---|---|
| Registry ID | ``vc01b-local-20260907-r7`` | ``vc01b-local-20260907-r8`` |
| CCS-01-007 parent | ``IMP-012`` | ``IMP-013`` |
| Leaf path status | ``DISCOVERY_REQUIRED`` | ``DISCOVERY_REQUIRED`` |
| Registry status | ``DRAFT`` | ``DRAFT`` |
| Implementation authorized | ``false`` | ``false`` |

## Normative basis

- ``IMPLEMENTATION_REGISTRY.json`` assigns API/UI process shells, health/readiness endpoints, structured logging and visible request correlation to ``IMP-013``.
- ``IMP-013`` depends on ``IMP-010`` and ``IMP-012``; process observability ownership is not transferred to the authentication/session package.
- ``11_CODEX_TASKS/CCS-01_TASKS.md`` names ``CCS-01-007`` as "Logging and health".
- ``reports/CCS-01-007_DISCOVERY_WORK_PACKET.md`` binds the exact local-only allowlist and closed observability contract, but does not grant implementation authority.

## Evidence bindings

| Evidence | SHA-256 |
|---|---|
| immutable r7 registry | ``$r7Sha256`` |
| CCS-01-007 discovery packet | ``$discoverySha256`` |
| specification implementation registry | ``$implementationRegistrySha256`` |
| specification CCS-01 task breakdown | ``$taskBreakdownSha256`` |
| repository commit at generation | ``$currentCommit`` |

## Preserved constraints

- Tasks: $($registry.tasks.Count) total, $resolvedCount ``RESOLVED``, $discoveryCount ``DISCOVERY_REQUIRED``.
- r8 remains ``DRAFT / NOT_EVALUATED`` and ``implementation_authorized=false``.
- ``CCS-01-007`` keeps empty path allowlists and ``forbidden_paths=["**"]``.
- No product code, test, dependency, database, credential, listener, provider, external log sink or telemetry service is changed or activated.
- r7 is an immutable input and is never overwritten.

## Next controlled action

Issue a separate attempt-scoped ACTIVE local work packet that copies the discovery packet's exact allowlist and contract under ``IMP-013``. r8 itself does not authorize implementation.

## Reproduction

Run ``.codex/ccs/tools/New-R8CCS01007ConflictResolution.ps1`` from any PowerShell working directory. The generator binds exact r7 and discovery-packet SHA-256 values and refuses to overwrite an existing r8 directory or report.
"@

[IO.File]::WriteAllText($reportPath, $report + "`n", [Text.UTF8Encoding]::new($false))
$reportSha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
$registry.readiness.report_sha256 = $reportSha256
[IO.Directory]::CreateDirectory($r8Dir) | Out-Null
[IO.File]::WriteAllText($r8Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r8Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") {
    throw "Cannot compute r8 registry digest"
}
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r8Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    source_r7_sha256 = $r7Sha256
    discovery_packet_sha256 = $discoverySha256
    r8_path = $r8Path
    r8_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $reportSha256
    resolved = $resolvedCount
    discovery_required = $discoveryCount
    implementation_authorized = $registry.implementation_authorized
} | Format-List
