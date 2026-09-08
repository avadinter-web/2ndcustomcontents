param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r4Path = Join-Path $revisionRoot "vc01b-local-20260907-r4\task-registry.json"
$r5Dir = Join-Path $revisionRoot "vc01b-local-20260907-r5"
$r5Path = Join-Path $r5Dir "task-registry.json"
$reportPath = Join-Path $repoRoot "reports\VC-01B_R5_FULL_REGISTRY_NORMALIZATION.md"
if (-not (Test-Path -LiteralPath $r4Path -PathType Leaf)) { throw "Missing r4: $r4Path" }
if (Test-Path -LiteralPath $r5Dir) { throw "Refusing to overwrite immutable r5: $r5Dir" }

$r = Get-Content -Raw -LiteralPath $r4Path | ConvertFrom-Json
$r4Sha = (Get-FileHash -LiteralPath $r4Path -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceByLeaf = @{}
foreach ($d in $r.normalization.dispositions) {
    $id = [string]$d.canonical_leaf_task_id
    if (-not $sourceByLeaf.ContainsKey($id)) { $sourceByLeaf[$id] = [Collections.Generic.List[string]]::new() }
    $sourceByLeaf[$id].Add([string]$d.source_key)
}

$r.registry_id = "vc01b-local-20260907-r5"
$r.registry_status = "DRAFT"
$r.registry_digest = $zero
$r.implementation_authorized = $false
$r.context.repository.current_commit = (& git -C $repoRoot rev-parse HEAD).Trim()
$r.context.repository.dirty_state_digest = $zero
$r.context.spec_package_digest = (Get-FileHash -LiteralPath (Join-Path $SpecRoot "PACKAGE_INDEX.json") -Algorithm SHA256).Hash.ToLowerInvariant()
$r.context.implementation_plan_digest = $zero
$r.context.leaf_task_id = $null
$r.context.slice_id = $null
$r.context.next_recommendation.candidate_leaf_task_id = "CCS-01-004"
$r.context.next_recommendation.candidate_slice_id = "IMP-010"
$r.context.next_recommendation.authorized = $false
$r.context.next_recommendation.requires_new_authorization = $true
$r.context.next_recommendation.reason = "Recommendation only; r5 remains DRAFT until all discovery and a new authorization are complete."
$r.readiness.graph_validated = $false
$r.readiness.owner_path_test_ownership_validated = $false
$r.readiness.gate_closure_validated = $false
$r.readiness.final_closure_leaf_id = $null
$r.readiness.final_closure_complete = $false
$r.readiness.report_path = "reports/VC-01B_R5_FULL_REGISTRY_NORMALIZATION.md"
$r.readiness.report_sha256 = $null
$r.readiness.decision = "NOT_EVALUATED"

function Resolve-Leaf([object]$Task, [string[]]$Allowed, [string[]]$Create, [string[]]$Modify, [string]$Owner) {
    $Task.path_resolution_status = "RESOLVED"
    $Task.allowed_paths = @($Allowed | Sort-Object -Unique)
    $Task.create_paths = @($Create | Sort-Object -Unique)
    $Task.modify_paths = @($Modify | Sort-Object -Unique)
    $Task.forbidden_paths = @(".env", "migrations/**", "**/*.key", "**/*.pem")
    $Task.owner_module = $Owner
    $Task.leaf_definition_digest = $zero
}

$resolved = @("CCS-01-001", "CCS-01-002", "CCS-01-003", "CCS-01-004")
foreach ($t in $r.tasks) {
    if ($t.leaf_task_id -in $resolved) { continue }
    $id = [string]$t.leaf_task_id
    $sources = if ($sourceByLeaf.ContainsKey($id)) { ($sourceByLeaf[$id] | Sort-Object) -join ", " } else { "no unique baseline source disposition" }
    $oldOwner = [string]$t.owner_module
    $oldParent = [string]$t.parent_work_package_id
    $t.path_resolution_status = "DISCOVERY_REQUIRED"
    $t.allowed_paths = @()
    $t.create_paths = @()
    $t.modify_paths = @()
    $t.forbidden_paths = @("**")
    $t.owner_module = "orchestration.discovery"
    $t.feature_ids = @()
    $t.invariant_ids = @()
    $t.tests.introduces = @()
    $t.tests.must_pass = @()
    $t.tests.regression = @()
    $t.interfaces = @()
    $t.commands = @()
    $t.evidence = @()
    $t.leaf_definition_digest = $zero
    $t.in_scope = @(
        "Discovery-only planning for $id from $sources.",
        "DISCOVERY BLOCKER [$id]: approve exact canonical source/test/interface paths, semantic owner, $oldParent parent mapping, and feature/invariant/test ownership. Former generated owner '$oldOwner' is not authority."
    )
    $t.out_of_scope = @("All repository writes until resolution in a later immutable revision", "Generated placeholder traceability", "External side effects and automatic activation")
    $t.authorization_requirements = @("Complete path and traceability discovery in a later immutable registry revision.", "Issue a separate ACTIVE work packet only after discovery.")
}

$byId = @{}; foreach ($t in $r.tasks) { $byId[[string]$t.leaf_task_id] = $t }
$p001 = @(
    "README.md", "pyproject.toml", "reports/IMP-010_CCS-01-001_IMPLEMENTATION.md", "scripts/run-module.ps1", "src/custom_content_studio/__init__.py",
    "src/custom_content_studio/api/__init__.py", "src/custom_content_studio/api/__main__.py",
    "src/custom_content_studio/bootstrap/__init__.py", "src/custom_content_studio/bootstrap/__main__.py", "src/custom_content_studio/bootstrap/composition.py", "src/custom_content_studio/bootstrap/startup.py",
    "src/custom_content_studio/cli/__init__.py", "src/custom_content_studio/cli/__main__.py",
    "src/custom_content_studio/config/__init__.py", "src/custom_content_studio/config/__main__.py", "src/custom_content_studio/config/loader.py", "src/custom_content_studio/config/models.py",
    "src/custom_content_studio/scheduler/__init__.py", "src/custom_content_studio/scheduler/__main__.py", "src/custom_content_studio/scheduler/runner.py",
    "src/custom_content_studio/ui/__init__.py", "src/custom_content_studio/ui/__main__.py", "src/custom_content_studio/worker.py",
    "src/custom_content_studio/workers/__init__.py", "src/custom_content_studio/workers/__main__.py", "src/custom_content_studio/workers/runner.py",
    "tests/test_bootstrap.py", "tests/test_config.py"
)
Resolve-Leaf $byId["CCS-01-001"] $p001 @() $p001 "custom_content_studio"
$byId["CCS-01-001"].in_scope = @("Current canonical package form of the completed 01-01 scaffold and entrypoint shells.", "CCS-01-011 records the dependency-ordered flat-to-package migration.")
$p002 = @("reports/IMP-010_CCS-01-002_IMPLEMENTATION.md", "src/custom_content_studio/bootstrap/composition.py", "src/custom_content_studio/scope_guard.py", "tests/test_scope_guard.py")
Resolve-Leaf $byId["CCS-01-002"] $p002 @() $p002 "custom_content_studio.scope_guard"
$p003 = @("reports/IMP-010_CCS-01-003_IMPLEMENTATION.md", "src/custom_content_studio/runtime_paths.py", "tests/test_runtime_paths.py")
$byId["CCS-01-003"].parent_work_package_id = "IMP-010"
Resolve-Leaf $byId["CCS-01-003"] $p003 @() $p003 "custom_content_studio.runtime_paths"

$p004 = @(".env.example", "README.md", "config", "config/dev.toml", "config/staging.toml", "config/prod.toml", "reports/IMP-010_CCS-01-004_IMPLEMENTATION.md", "src/custom_content_studio/bootstrap/composition.py", "src/custom_content_studio/bootstrap/startup.py", "src/custom_content_studio/cli/__init__.py", "src/custom_content_studio/config/__init__.py", "src/custom_content_studio/config/loader.py", "src/custom_content_studio/config/models.py", "tests/test_bootstrap.py", "tests/test_environment_profiles.py")
$c004 = @("config", "config/dev.toml", "config/staging.toml", "config/prod.toml", "reports/IMP-010_CCS-01-004_IMPLEMENTATION.md", "tests/test_environment_profiles.py")
$m004 = @(".env.example", "README.md", "src/custom_content_studio/bootstrap/composition.py", "src/custom_content_studio/bootstrap/startup.py", "src/custom_content_studio/cli/__init__.py", "src/custom_content_studio/config/__init__.py", "src/custom_content_studio/config/loader.py", "src/custom_content_studio/config/models.py", "tests/test_bootstrap.py")
$byId["CCS-01-004"].parent_work_package_id = "IMP-010"
$byId["CCS-01-004"].depends_on = @("CCS-01-011")
Resolve-Leaf $byId["CCS-01-004"] $p004 $c004 $m004 "custom_content_studio.config"
$byId["CCS-01-004"].in_scope = @("Implement secret-free DEV, STAGING and PROD profiles in the canonical config package.", "Create config and its three direct TOML children under CHG-2026-0020.")

$layout = @(
    "reports/IMP-010_CCS-01-011_IMPLEMENTATION.md", "src/custom_content_studio/api/__init__.py", "src/custom_content_studio/api/__main__.py",
    "src/custom_content_studio/bootstrap/__init__.py", "src/custom_content_studio/bootstrap/__main__.py", "src/custom_content_studio/bootstrap/composition.py", "src/custom_content_studio/bootstrap/startup.py",
    "src/custom_content_studio/cli/__init__.py", "src/custom_content_studio/cli/__main__.py", "src/custom_content_studio/config/__init__.py", "src/custom_content_studio/config/__main__.py", "src/custom_content_studio/config/loader.py", "src/custom_content_studio/config/models.py",
    "src/custom_content_studio/scheduler/__init__.py", "src/custom_content_studio/scheduler/__main__.py", "src/custom_content_studio/scheduler/runner.py", "src/custom_content_studio/ui/__init__.py", "src/custom_content_studio/ui/__main__.py",
    "src/custom_content_studio/workers/__init__.py", "src/custom_content_studio/workers/__main__.py", "src/custom_content_studio/workers/runner.py", "tests/test_package_layout.py"
)
$leaf011 = [ordered]@{
    allowed_paths=@($layout|Sort-Object -Unique); authorization_requirements=@("Completed migration record only; this DRAFT does not authorize replay."); commands=@(); create_paths=@(); depends_on=@("CCS-01-003"); directly_executable=$false
    error_contracts=@("TASK_ENVELOPE_INCOMPLETE","PREREQUISITE_NOT_ACCEPTED"); evidence=@(); external_side_effect_policy="FORBIDDEN"; feature_ids=@("F-001"); forbidden_paths=@(".env","migrations/**","**/*.key","**/*.pem")
    gate_receipts=@([ordered]@{gate_id="VC-02";receipt_digest=$null;receipt_id=$null;status="MISSING"}); implementation_authority_source="SEPARATE_ACTIVE_AUTHORIZATION_AND_APPROVED_WORK_PACKET"
    in_scope=@("Record completed CHG-2026-0021 canonical layout migration at commit 652e065b69652312efc1ee9eb9556bc054508056.","Preserve public module names without product behavior."); interfaces=@(); invariant_ids=@("INV-TL-001")
    leaf_definition_digest=$zero; leaf_task_id="CCS-01-011"; migration_policy="NON_DESTRUCTIVE_ONLY"; modify_paths=@($layout|Sort-Object -Unique); out_of_scope=@("Product behavior, persistence, providers, secrets, network and deployment","Replay")
    owner_module="custom_content_studio"; parent_work_package_id="IMP-010"; path_resolution_status="RESOLVED"; recovery=[ordered]@{checkpoint_path=$null;resume_requirements=@("Do not replay; validate current package layout and commit identity.");rollback=@()}
    stage="CCS-01"; status="PLANNED"; stop_conditions=@([ordered]@{code="TASK_ENVELOPE_INCOMPLETE";condition="Any replay or scope expansion must stop."}); tests=[ordered]@{introduces=@();must_pass=@("T-001","T-002","T-ENV-001","T-ENV-002");regression=@()}; transaction_requirements=@("No transaction or external effect.")
}
$tasks = [Collections.Generic.List[object]]::new()
foreach ($t in $r.tasks) { if ($t.leaf_task_id -eq "CCS-01-004") { $tasks.Add([pscustomobject]$leaf011) }; $tasks.Add($t) }
$r.tasks = @($tasks)

$stageRows = $r.tasks | Group-Object stage,path_resolution_status | Sort-Object Name | ForEach-Object { $a=$_.Name-split ", "; "| $($a[0]) | $($a[1]) | $($_.Count) |" }
$leafRows = foreach ($t in $r.tasks) {
    if ($t.path_resolution_status -eq "RESOLVED") {
        $detail = switch ($t.leaf_task_id) { "CCS-01-001"{"Canonical current scaffold paths."};"CCS-01-002"{"Canonical scope-guard composition path."};"CCS-01-003"{"IMP-010 runtime-path ownership."};"CCS-01-004"{"IMP-010, CHG-2026-0020 and CCS-01-011 dependency."};"CCS-01-011"{"Completed CHG-2026-0021 exact current paths."} }
    } else {
        $s = if($sourceByLeaf.ContainsKey([string]$t.leaf_task_id)){($sourceByLeaf[[string]$t.leaf_task_id]|Sort-Object)-join "<br>"}else{"none"}
        $detail = "From ${s}: approve exact paths, semantic owner/parent and feature/invariant/test ownership."
    }
    "| $($t.leaf_task_id) | $($t.stage) | $($t.parent_work_package_id) | $($t.path_resolution_status) | $detail |"
}
$resolvedCount=@($r.tasks|Where-Object path_resolution_status -eq "RESOLVED").Count
$discoveryCount=@($r.tasks|Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report=@"
# VC-01B r5 Full Registry Normalization

Status: `DRAFT / NOT AUTHORIZED`
Date: 2026-09-08

## Outcome

r5 derives from immutable r4 SHA-256 `$r4Sha`. Unsupported placeholder path and traceability claims are removed. Only five foundation leaves have repository- and specification-backed exact paths; $discoveryCount leaves fail closed.

- Total: $($r.tasks.Count)
- RESOLVED: $resolvedCount
- DISCOVERY_REQUIRED: $discoveryCount
- Readiness: `NOT_EVALUATED`
- Implementation authorized: `false`
- Source dispositions: $($r.normalization.dispositions.Count) / $($r.normalization.baseline_source_count)

## Stage counts

| Stage | Status | Count |
|---|---|---:|
$($stageRows-join "`n")

## Complete leaf ledger

| Leaf | Stage | Parent | Status | Correction or blocker |
|---|---|---|---|---|
$($leafRows-join "`n")

## Mandatory prerequisites before FROZEN

1. Approve exact canonical source, test and interface paths for every discovery leaf.
2. Approve semantic owner and parent package; stage equality alone is insufficient.
3. Rebuild feature, invariant and test ownership from canonical registries without generated assignment.
4. Prove unique dependency-ordered path ownership against the live repository.
5. Recompute every leaf digest, readiness hash and registry digest in a new immutable revision.
6. Validate graph, ownership, traceability, gates and VC-07 closure before PASS/FROZEN.
7. Issue a separate ACTIVE work packet and authorization; this registry grants none.

## Reproducibility

The retained `.codex/ccs/tools/New-R5RegistryNormalization.ps1` refuses to overwrite an existing r5 directory.
"@
[IO.File]::WriteAllText($reportPath,$report,[Text.UTF8Encoding]::new($false))
$r.readiness.report_sha256=(Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r5Dir)|Out-Null
[IO.File]::WriteAllText($r5Path,($r|ConvertTo-Json -Depth 100)+"`n",[Text.UTF8Encoding]::new($false))
$digest=(& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r5Path --profile task-registry).Trim()
if($digest -notmatch "^[0-9a-f]{64}$"){throw "Bad digest output: $digest"}
$r.registry_digest=$digest; $r.context.implementation_plan_digest=$digest
[IO.File]::WriteAllText($r5Path,($r|ConvertTo-Json -Depth 100)+"`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]@{r4_sha256=$r4Sha;r5_path=$r5Path;r5_digest=$digest;resolved=$resolvedCount;discovery_required=$discoveryCount;report=$reportPath;report_sha256=$r.readiness.report_sha256}|Format-List
