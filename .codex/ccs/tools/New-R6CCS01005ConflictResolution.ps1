param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR5Sha256 = "014ede67735ecefda1400b9c880c582438f2a6bb550b387d763bb5a812a27679"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r5Path = Join-Path $revisionRoot "vc01b-local-20260907-r5\task-registry.json"
$r6Dir = Join-Path $revisionRoot "vc01b-local-20260907-r6"
$r6Path = Join-Path $r6Dir "task-registry.json"
$reportPath = Join-Path $repoRoot "reports\CCS-01-005_CONFLICT_RESOLUTION.md"

if (-not (Test-Path -LiteralPath $r5Path -PathType Leaf)) {
    throw "Missing immutable r5 source: $r5Path"
}
if (Test-Path -LiteralPath $r6Dir) {
    throw "Refusing to overwrite immutable r6: $r6Dir"
}

$r5Sha256 = (Get-FileHash -LiteralPath $r5Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r5Sha256 -ne $expectedR5Sha256) {
    throw "Unexpected r5 SHA-256: $r5Sha256"
}

$registry = Get-Content -LiteralPath $r5Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r5") {
    throw "Unexpected source registry_id: $($registry.registry_id)"
}
if ($registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized -ne $false) {
    throw "r5 must remain DRAFT and unauthorized"
}

$leaves = @($registry.tasks | Where-Object { $_.leaf_task_id -eq "CCS-01-005" })
if ($leaves.Count -ne 1) {
    throw "Expected exactly one CCS-01-005 leaf, found $($leaves.Count)"
}
$leaf = $leaves[0]
if ($leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") {
    throw "CCS-01-005 must remain DISCOVERY_REQUIRED"
}
if ($leaf.parent_work_package_id -ne "IMP-010") {
    throw "Expected r5 mismatch IMP-010, found $($leaf.parent_work_package_id)"
}

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Cannot resolve current repository commit"
}
$implementationRegistryPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$taskBreakdownPath = Join-Path $SpecRoot "11_CODEX_TASKS\CCS-01_TASKS.md"
$implementationRegistrySha256 = (Get-FileHash -LiteralPath $implementationRegistryPath -Algorithm SHA256).Hash.ToLowerInvariant()
$taskBreakdownSha256 = (Get-FileHash -LiteralPath $taskBreakdownPath -Algorithm SHA256).Hash.ToLowerInvariant()

$registry.registry_id = "vc01b-local-20260907-r6"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-005"
$registry.context.next_recommendation.candidate_slice_id = "IMP-011"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "Discovery only: resolve CCS-01-005 exact paths, migration boundaries and traceability under normative IMP-011 ownership before any ACTIVE work packet."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-005_CONFLICT_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$leaf.parent_work_package_id = "IMP-011"
$leaf.in_scope = @($leaf.in_scope | ForEach-Object {
    ([string]$_).Replace("semantic owner, IMP-010 parent mapping", "semantic owner, IMP-011 parent mapping")
})
if (($leaf.in_scope -join "`n") -notmatch "IMP-011 parent mapping") {
    throw "CCS-01-005 discovery blocker was not updated"
}

$resolvedCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "RESOLVED" }).Count
$discoveryCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "DISCOVERY_REQUIRED" }).Count

$report = @"
# CCS-01-005 Contract Conflict Resolution

Status: ``DRAFT / NOT AUTHORIZED``
Date: 2026-09-08

## Outcome

The r5 parent assignment for ``CCS-01-005`` is corrected from ``IMP-010`` to ``IMP-011`` in immutable successor r6. The leaf remains ``DISCOVERY_REQUIRED`` with no writable paths, no migration permission, and no implementation authority.

| Item | r5 | r6 |
|---|---|---|
| Registry ID | ``vc01b-local-20260907-r5`` | ``vc01b-local-20260907-r6`` |
| CCS-01-005 parent | ``IMP-010`` | ``IMP-011`` |
| Leaf path status | ``DISCOVERY_REQUIRED`` | ``DISCOVERY_REQUIRED`` |
| Registry status | ``DRAFT`` | ``DRAFT`` |
| Implementation authorized | ``false`` | ``false`` |

## Normative evidence

- ``11_CODEX_TASKS/CCS-01_TASKS.md`` defines legacy task ``01-05`` as SQLite bootstrap with durable initialization and restart testing.
- ``IMPLEMENTATION_REGISTRY.json`` assigns migration manifest, schema bootstrap, ``UnitOfWork``, and SQLite foreign-key/WAL/busy-timeout bootstrap to ``IMP-011``.
- ``IMP-010`` owns repository scaffold, composition root, runtime profiles, and entrypoint shells; it does not own persistence.

Evidence bindings:

- r5 SHA-256: ``$r5Sha256``
- specification ``IMPLEMENTATION_REGISTRY.json`` SHA-256: ``$implementationRegistrySha256``
- specification ``11_CODEX_TASKS/CCS-01_TASKS.md`` SHA-256: ``$taskBreakdownSha256``
- repository baseline commit: ``$currentCommit``

## Preserved fail-closed state

- Total leaves: $($registry.tasks.Count)
- ``RESOLVED``: $resolvedCount
- ``DISCOVERY_REQUIRED``: $discoveryCount
- readiness decision: ``NOT_EVALUATED``
- CCS-01-005 allowed/create/modify paths remain empty
- CCS-01-005 forbidden paths remain ``**``
- CCS-01-005 migration policy remains ``FORBIDDEN`` until a later exact discovery revision
- no product code, database, migration, or product test is created or executed by this correction

## Required next design step

Resolve the exact canonical source, migration, test, and interface paths for CCS-01-005 under IMP-011. Bind feature, invariant, and test ownership; define migration safety and rollback evidence; then issue a later immutable registry revision and a separate ACTIVE work packet. r6 itself cannot authorize implementation.

## Reproduction

Run ``.codex/ccs/tools/New-R6CCS01005ConflictResolution.ps1`` from any PowerShell working directory. The generator binds the exact r5 SHA-256 and refuses to overwrite an existing r6 directory.
"@

[IO.File]::WriteAllText($reportPath, $report, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r6Dir) | Out-Null
[IO.File]::WriteAllText($r6Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r6Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") {
    throw "Bad registry digest output: $digest"
}
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r6Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    source_r5_sha256 = $r5Sha256
    r6_path = $r6Path
    r6_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    resolved = $resolvedCount
    discovery_required = $discoveryCount
    implementation_authorized = $registry.implementation_authorized
} | Format-List
