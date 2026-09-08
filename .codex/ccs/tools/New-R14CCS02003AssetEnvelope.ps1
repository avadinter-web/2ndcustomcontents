param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR13 = "437e2e138299f0af078937da085f5b08ad32b513dd1beecb76ca88519da7a4a5"
$expectedDiscovery = "1acbe367236245b53833cb75101dfa0c9df67332341917d71dece92c9cfa6eaf"
$expectedSpec = "89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r13Path = Join-Path $revisions "vc01b-local-20260907-r13\task-registry.json"
$r14Dir = Join-Path $revisions "vc01b-local-20260907-r14"
$r14Path = Join-Path $r14Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-003_ASSET_REGISTRY_DISCOVERY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-003_ASSET_ENVELOPE_RESOLUTION.md"

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw "Hash mismatch: $Path = $actual" }
    return $actual
}

foreach ($target in @($r14Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r14 output: $target" }
}
$r13Hash = Assert-Hash $r13Path $expectedR13
$discoveryHash = Assert-Hash $discoveryPath $expectedDiscovery
$packageHash = Assert-Hash (Join-Path $SpecRoot "PACKAGE_INDEX.json") $expectedSpec
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$features = (Get-Content (Join-Path $SpecRoot "FEATURE_REGISTRY.json") -Raw | ConvertFrom-Json).features
$invariants = (Get-Content (Join-Path $SpecRoot "INVARIANT_REGISTRY.json") -Raw | ConvertFrom-Json).invariants
$tests = (Get-Content (Join-Path $SpecRoot "TEST_CATALOG.json") -Raw | ConvertFrom-Json).tests
$slices = (Get-Content (Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json") -Raw | ConvertFrom-Json).slices
foreach ($id in @("F-003", "F-004", "F-006")) { if (@($features | Where-Object feature_id -eq $id).Count -ne 1) { throw "Missing feature: $id" } }
if (@($invariants | Where-Object invariant_id -eq "INV-WS-001").Count -ne 1) { throw "Missing INV-WS-001" }
foreach ($id in @("T-010", "T-011", "T-013", "T-017")) { if (@($tests | Where-Object test_id -eq $id).Count -ne 1) { throw "Missing test: $id" } }
$imp = @($slices | Where-Object slice_id -eq "IMP-021")
if ($imp.Count -ne 1 -or $imp[0].title -ne "Asset identity, storage registration and media probe") { throw "IMP-021 binding mismatch" }

$registry = Get-Content $r13Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r13" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r13 source" }
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-003")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-002" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-003 baseline" }
$leaf = $leaf[0]

$create = @(
    "reports/IMP-021_CCS-02-003_IMPLEMENTATION.md",
    "src/custom_content_studio/application/ports/asset_repository.py",
    "src/custom_content_studio/application/services/assets.py",
    "src/custom_content_studio/domain/assets.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/assets.py",
    "tests/integration/test_asset_service.py",
    "tests/repository/test_asset_repository.py",
    "tests/unit/test_asset_model.py"
)
$modify = @(
    "src/custom_content_studio/application/ports/__init__.py",
    "src/custom_content_studio/application/services/__init__.py",
    "src/custom_content_studio/bootstrap/composition.py",
    "src/custom_content_studio/domain/__init__.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py"
)
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create path exists: $path" } }
foreach ($path in $modify) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" } }

$leaf.parent_work_package_id = "IMP-021"
$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.application.services.assets"
$leaf.feature_ids = @("F-004")
$leaf.invariant_ids = @("INV-WS-001")
$leaf.tests.introduces = @("T-013")
$leaf.tests.must_pass = @("T-010", "T-011", "T-013", "T-017")
$leaf.tests.regression = @("T-010", "T-011", "T-017")
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/custom_content_studio/api/**", "src/custom_content_studio/ui/**", "src/custom_content_studio/persistence/**", "tests/gates/**")
$leaf.commands = @()
$leaf.interfaces = @([ordered]@{kind="PORT"; name="AssetRepositoryPort"; contract_root="SPEC_ROOT"; contract_path="01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md"; direction="BOTH"})
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Implement only the F-004 Asset metadata registry subset under IMP-021.",
    "Register caller-supplied storage references without opening storage or reading Asset bytes.",
    "Workspace-scoped get/list, optional same-Workspace Project association, deterministic metadata JSON and row_version CAS.",
    "Introduce T-013 and regress F-003/F-006 through T-010, T-011 and T-017.",
    "Enforce the Asset-to-Project subset of INV-WS-001 in service and existing SQLite backstops."
)
$leaf.out_of_scope = @(
    "MediaProbe StoragePort provider SDK upload download filesystem and FFmpeg/FFprobe execution",
    "Asset proxy waveform derivative and immutable-byte evidence completion",
    "API UI Content ContentVersion and downstream Tooling",
    "Migration SQL manifest table replacement and backfill",
    "F-052 F-056 and their tests",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE work packet must bind exact r14 and repository commit before mutation.",
    "Only pytest tmp_path SQLite databases and synthetic storage references are permitted.",
    "No provider network media arguments credentials or Subs secret may be used."
)
$leaf.error_contracts = @("MIGRATION_DECISION_REQUIRED", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE", "VERSION_CONFLICT", "WORKSPACE_ACCESS_DENIED")
$leaf.transaction_requirements = @(
    "One caller-owned local SQLite unit of work; repositories never commit independently.",
    "Mutable metadata, status and Project association use exact row_version CAS and increment once.",
    "AVAILABLE physical identity is immutable and replacement creates a new Asset.",
    "No external, provider, filesystem, media or runtime database effect is permitted."
)
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="The r14 specification, registry or discovery binding differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-002 or required workspace/project evidence is not accepted."},
    [ordered]@{code="MIGRATION_DECISION_REQUIRED"; condition="Implementation requires any schema, manifest, migration or backfill change."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="The ACTIVE packet omits exact paths, tests, evidence or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires storage/media/provider/network/runtime DB/API/UI or an unlisted path."}
)
$leaf.recovery = [ordered]@{checkpoint_path=$null; resume_requirements=@("Revalidate r14, discovery, repository commit and existing Asset schema hash.", "Confirm create paths remain absent and modify paths match the ACTIVE baseline."); rollback=@()}
$leaf.evidence = @([ordered]@{evidence_id="EV-CCS-02-003-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-003_ASSET_REGISTRY_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false})

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r14"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-003"
$registry.context.next_recommendation.candidate_slice_id = "IMP-021"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CCS-02-003 Asset registry envelope is resolved under IMP-021; separate ACTIVE authorization remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-003_ASSET_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-003 Immutable Asset Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-08

r14 preserves r13 and resolves CCS-02-003 only. It corrects the parent from IMP-022 to canonical
IMP-021, preserves depends_on=[CCS-02-002], assigns owner custom_content_studio.application.services.assets,
and binds exactly 8 create plus 5 modify paths. It owns the Asset subset of F-004 and T-013,
regresses F-003/F-006 with T-010/T-011/T-017, and binds INV-WS-001.

- r13 SHA-256: $r13Hash
- r13 registry digest: 906fdbe838f1733013581afa2e0bf4e1143116a686bc51b949fb71d5403f0eb4
- discovery SHA-256: $discoveryHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED

Migration, storage/media/provider/network/runtime DB/API/UI actions remain forbidden. r14 stays
DRAFT, NOT_EVALUATED and implementation_authorized=false. No code or test is created here.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r14Dir) | Out-Null
[IO.File]::WriteAllText($r14Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r14Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r14Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$verified = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r14Path --profile task-registry).Trim()
if ($verified -ne $digest) { throw "Embedded digest verification failed" }
if ((Get-FileHash $r13Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedR13) { throw "r13 changed" }

[pscustomobject]@{r14_path=$r14Path; registry_digest=$digest; report_path=$reportPath; report_sha256=$registry.readiness.report_sha256; create_paths=$create.Count; modify_paths=$modify.Count; resolved=$resolved; discovery_required=$discovery; implementation_authorized=$registry.implementation_authorized} | Format-List
