param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR9Sha256 = "08335c5b661806777af006a448168204f58109f2c1f9b64135c2eccc7f66c662"
$expectedImplementationRegistrySha256 = "143a41bab166f50adeb888d6eee74de81aa18ba54559f6e0601a23c77f354d83"
$expectedTaskCatalogSha256 = "7462e0eca03f1531f56407af2f23729c213d8e29cda0c68b88533e170c1f5509"
$expectedFoundationSha256 = "ca16ae21c502634a2d56769fbe830e1e36c3807415733a6a211f75a5e2f7d979"
$expectedDiscoverySha256 = "b6a9cf6b24ca7a1da57f31329f2d9350297c32d5b5490fad3ec64ba6b7acb0e9"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r9Path = Join-Path $revisionRoot "vc01b-local-20260907-r9\task-registry.json"
$r10Dir = Join-Path $revisionRoot "vc01b-local-20260907-r10"
$r10Path = Join-Path $r10Dir "task-registry.json"
$implementationRegistryPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$taskCatalogPath = Join-Path $SpecRoot "11_CODEX_TASKS\CCS-01_TASKS.md"
$foundationPath = Join-Path $SpecRoot "01_FOUNDATION\CCS-01_FOUNDATION.md"
$discoveryPath = Join-Path $repoRoot "reports\CCS-01-008_DISCOVERY_WORK_PACKET.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01_EXECUTION_ORDER_REPAIR.md"

foreach ($source in @($r9Path, $implementationRegistryPath, $taskCatalogPath, $foundationPath, $discoveryPath)) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing required source: $source"
    }
}
foreach ($target in @($r10Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite immutable r10 output: $target"
    }
}

function Assert-Sha256([string]$Path, [string]$Expected) {
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) {
        throw "Unexpected SHA-256 for $Path`: $actual"
    }
    return $actual
}

$r9Sha256 = Assert-Sha256 $r9Path $expectedR9Sha256
$implementationRegistrySha256 = Assert-Sha256 $implementationRegistryPath $expectedImplementationRegistrySha256
$taskCatalogSha256 = Assert-Sha256 $taskCatalogPath $expectedTaskCatalogSha256
$foundationSha256 = Assert-Sha256 $foundationPath $expectedFoundationSha256
$discoverySha256 = Assert-Sha256 $discoveryPath $expectedDiscoverySha256

$implementationRegistry = Get-Content -LiteralPath $implementationRegistryPath -Raw | ConvertFrom-Json
$imp012Matches = @($implementationRegistry.slices | Where-Object { $_.slice_id -eq "IMP-012" })
if ($imp012Matches.Count -ne 1) {
    throw "Expected exactly one normative IMP-012 slice"
}
$imp012 = $imp012Matches[0]
if ($imp012.title -ne "Authentication, secret references and ActorContext") {
    throw "Unexpected normative IMP-012 title: $($imp012.title)"
}
foreach ($deliverable in @("session service", "secret store port", "audit-safe request context")) {
    if ($deliverable -notin @($imp012.deliverables)) {
        throw "Normative IMP-012 is missing deliverable: $deliverable"
    }
}
foreach ($evidence in @("hash-only session test", "secret masking")) {
    if ($evidence -notin @($imp012.acceptance_evidence)) {
        throw "Normative IMP-012 is missing acceptance evidence: $evidence"
    }
}

$taskLines = @(Get-Content -LiteralPath $taskCatalogPath)
if ($taskLines.Count -lt 30 -or $taskLines[28] -notmatch "Session token hash, rotation family and one-way revocation") {
    throw "CCS-01-009 semantic source is missing at CCS-01_TASKS.md#L29"
}
if ($taskLines[29] -notmatch "ServiceAccount credential secret reference and rotation audit") {
    throw "CCS-01-010 semantic source is missing at CCS-01_TASKS.md#L30"
}

$registry = Get-Content -LiteralPath $r9Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r9") {
    throw "Unexpected source registry_id: $($registry.registry_id)"
}
if ($registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized -ne $false) {
    throw "r9 must remain DRAFT and unauthorized"
}

$byId = @{}
foreach ($task in $registry.tasks) {
    $byId[$task.leaf_task_id] = $task
}
foreach ($leafId in @("CCS-01-007", "CCS-01-008", "CCS-01-009", "CCS-01-010")) {
    if (-not $byId.ContainsKey($leafId)) {
        throw "Missing leaf in r9: $leafId"
    }
    $leaf = $byId[$leafId]
    if ($leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") {
        throw "$leafId must remain DISCOVERY_REQUIRED"
    }
    if (@($leaf.allowed_paths).Count -ne 0 -or @($leaf.create_paths).Count -ne 0 -or @($leaf.modify_paths).Count -ne 0) {
        throw "$leafId unexpectedly permits repository paths"
    }
    if (@($leaf.forbidden_paths).Count -ne 1 -or $leaf.forbidden_paths[0] -ne "**") {
        throw "$leafId must remain deny-all"
    }
}

if ($byId["CCS-01-007"].parent_work_package_id -ne "IMP-013" -or
    @($byId["CCS-01-007"].depends_on).Count -ne 1 -or
    $byId["CCS-01-007"].depends_on[0] -ne "CCS-01-006") {
    throw "Unexpected CCS-01-007 baseline"
}
if ($byId["CCS-01-008"].parent_work_package_id -ne "IMP-013" -or $byId["CCS-01-008"].depends_on[0] -ne "CCS-01-007") {
    throw "Unexpected CCS-01-008 baseline"
}
if ($byId["CCS-01-009"].parent_work_package_id -ne "IMP-010" -or $byId["CCS-01-009"].depends_on[0] -ne "CCS-01-008") {
    throw "Unexpected CCS-01-009 baseline"
}
if ($byId["CCS-01-010"].parent_work_package_id -ne "IMP-011" -or $byId["CCS-01-010"].depends_on[0] -ne "CCS-01-009") {
    throw "Unexpected CCS-01-010 baseline"
}

$byId["CCS-01-009"].parent_work_package_id = "IMP-012"
$byId["CCS-01-010"].parent_work_package_id = "IMP-012"
$byId["CCS-01-009"].depends_on = @("CCS-01-007")
$byId["CCS-01-010"].depends_on = @("CCS-01-009")
$byId["CCS-01-008"].depends_on = @("CCS-01-010")
$byId["CCS-01-009"].in_scope = @(
    "Discovery-only planning for CCS-01-009 from 11_CODEX_TASKS/CCS-01_TASKS.md#L29.",
    "Normative IMP-012 owns the session service and hash-only session evidence; r10 corrects semantic ownership and orders this leaf after CCS-01-007.",
    "DISCOVERY BLOCKER [CCS-01-009]: resolve overlap with accepted CCS-01-006 evidence and bind exact paths/tests in a separate successor; r10 grants no write authority."
)
$byId["CCS-01-010"].in_scope = @(
    "Discovery-only planning for CCS-01-010 from 11_CODEX_TASKS/CCS-01_TASKS.md#L30.",
    "Normative IMP-012 owns secret references, masking and audit-safe request context; r10 corrects semantic ownership and orders this leaf after CCS-01-009.",
    "DISCOVERY BLOCKER [CCS-01-010]: bind exact ServiceAccount rotation-audit paths/tests in a separate successor; r10 grants no write or credential authority."
)
$byId["CCS-01-008"].in_scope = @(
    "Discovery-only planning for CCS-01-008 from 11_CODEX_TASKS/CCS-01_TASKS.md#L17.",
    "The terminal CCS-01 gate remains under IMP-013 and now depends on CCS-01-010, establishing CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008.",
    "DISCOVERY BLOCKER [CCS-01-008]: resolve prerequisite acceptance and exact test ownership before a separate gate authorization; r10 grants no write authority."
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Cannot resolve current repository commit"
}

$registry.registry_id = "vc01b-local-20260907-r10"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-009"
$registry.context.next_recommendation.candidate_slice_id = "IMP-012"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "Execution order and IMP-012 ownership are repaired; resolve CCS-01-009 overlap and exact paths/tests in a separate immutable discovery successor before implementation."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01_EXECUTION_ORDER_REPAIR.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolvedCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "RESOLVED" }).Count
$discoveryCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "DISCOVERY_REQUIRED" }).Count
$report = @"
# CCS-01 Execution Order and Semantic Ownership Repair

Status: ``DRAFT / NOT AUTHORIZED``
Date: 2026-09-08

## Outcome

Immutable successor r10 repairs the effective CCS-01 tail order to:

``CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008``

It also corrects ``CCS-01-009`` and ``CCS-01-010`` to normative parent ``IMP-012``. All four
leaves remain ``DISCOVERY_REQUIRED`` with empty write allowlists and ``forbidden_paths=["**"]``.
r10 is ``DRAFT / NOT_EVALUATED`` and ``implementation_authorized=false``.

## Normative proof

- ``CCS-01_TASKS.md#L29`` defines app-managed Session token hash, rotation family and one-way revocation.
- ``CCS-01_TASKS.md#L30`` defines ServiceAccount credential secret reference and rotation audit.
- ``IMP-012`` is titled "Authentication, secret references and ActorContext" and owns the session service,
  secret-store port, audit-safe request context, hash-only session test and secret masking evidence.
- ``CCS-01-008`` is the CCS-01 gate and the foundation gate rejects secrets-safety failures, so it must
  follow the two applicable security leaves.

| Evidence | SHA-256 |
|---|---|
| immutable r9 registry | ``$r9Sha256`` |
| ``IMPLEMENTATION_REGISTRY.json`` | ``$implementationRegistrySha256`` |
| ``11_CODEX_TASKS/CCS-01_TASKS.md`` | ``$taskCatalogSha256`` |
| ``01_FOUNDATION/CCS-01_FOUNDATION.md`` | ``$foundationSha256`` |
| ``reports/CCS-01-008_DISCOVERY_WORK_PACKET.md`` | ``$discoverySha256`` |
| repository commit at generation | ``$currentCommit`` |

## Exact graph delta

| Leaf | r9 parent / dependency | r10 parent / dependency |
|---|---|---|
| ``CCS-01-007`` | ``IMP-013`` / ``CCS-01-006`` | unchanged |
| ``CCS-01-009`` | ``IMP-010`` / ``CCS-01-008`` | ``IMP-012`` / ``CCS-01-007`` |
| ``CCS-01-010`` | ``IMP-011`` / ``CCS-01-009`` | ``IMP-012`` / ``CCS-01-009`` |
| ``CCS-01-008`` | ``IMP-013`` / ``CCS-01-007`` | ``IMP-013`` / ``CCS-01-010`` |

## Preserved constraints and remaining work

- r9 is retained byte-identically; the generator binds and rechecks its exact SHA-256.
- r10 contains $($registry.tasks.Count) tasks: $resolvedCount ``RESOLVED`` and $discoveryCount ``DISCOVERY_REQUIRED``.
- No product source, tests, migration, runtime data, credential, provider, deployment or publication is changed.
- This repair does not infer that ``CCS-01-006`` supersedes ``CCS-01-009`` and assigns no missing catalog test ownership.
- The next safe action is a separate discovery successor for ``CCS-01-009`` overlap, exact paths and tests.
- No leaf implementation or CCS-01 gate execution is authorized by r10.

## Reproduction

Run ``.codex/ccs/tools/New-R10CCS01ExecutionOrderRepair.ps1``. The generator validates all bound
normative hashes and semantic markers and refuses to overwrite r10 or this report.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd([char[]]"`r`n") + "`n", [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()

[IO.Directory]::CreateDirectory($r10Dir) | Out-Null
[IO.File]::WriteAllText($r10Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r10Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") {
    throw "Bad registry digest output: $digest"
}
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r10Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))

$r9Sha256After = (Get-FileHash -LiteralPath $r9Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r9Sha256After -ne $expectedR9Sha256) {
    throw "Immutable r9 changed during r10 generation"
}

[pscustomobject]@{
    source_r9_sha256 = $r9Sha256
    r10_path = $r10Path
    r10_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    effective_order = "CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008"
    resolved = $resolvedCount
    discovery_required = $discoveryCount
    implementation_authorized = $registry.implementation_authorized
} | Format-List
