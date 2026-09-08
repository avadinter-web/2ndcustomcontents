param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR15 = "fdc860cf70849c92252c25b4ca9437131e925205488be987ff6dfb457249ec79"
$expectedR15Digest = "52bbf26225e2c5e6af52cf035af57facb846b8ac2b0ac6b93cca5ca5af5954a6"
$expectedDiscovery = "198efbeedd0df893247c61629a032f2cb30f09730c5fb677005d1c4d954ec47e"
$expectedChange = "0525aa4b7ab68b1f56dd83369e5e66299f90d3a2f6344666ea71753e0d087c7c"
$expectedSpec = "cf7fbc99b83f3a258b5c6794df777c10fba4c945a5fffc76791d5bad951c5e1c"
$expectedSnapshotSchema = "3e78c44d49cd809c2381eeed30f4b5c8fae41cee8b90c1436cc20bb32a73880b"
$expectedDatabaseSchema = "2b532c6fbe5b45241f2cd815b6de4947d0a056b32754165fd06c1e9c12a2980f"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r15Path = Join-Path $revisions "vc01b-local-20260907-r15\task-registry.json"
$r16Dir = Join-Path $revisions "vc01b-local-20260907-r16"
$r16Path = Join-Path $r16Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-005_CONTENT_VERSION_DISCOVERY.md"
$changePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\CHG-2026-0023_CCS_02_005_CONTENT_VERSION_IDENTITY.md"
$snapshotSchemaPath = Join-Path $SpecRoot "13_IMPLEMENTATION_CONTRACTS\schemas\content-version-snapshot.v1.schema.json"
$databaseSchemaPath = Join-Path $repoRoot "migrations\0001_initial_v2_2.sql"
$reportPath = Join-Path $repoRoot "reports\CCS-02-005_CONTENT_VERSION_ENVELOPE_RESOLUTION.md"

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw "Hash mismatch: $Path = $actual" }
    return $actual
}

foreach ($target in @($r16Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r16 output: $target" }
}
$r15Hash = Assert-Hash $r15Path $expectedR15
$discoveryHash = Assert-Hash $discoveryPath $expectedDiscovery
$changeHash = Assert-Hash $changePath $expectedChange
$packageHash = Assert-Hash (Join-Path $SpecRoot "PACKAGE_INDEX.json") $expectedSpec
$snapshotSchemaHash = Assert-Hash $snapshotSchemaPath $expectedSnapshotSchema
$databaseSchemaHash = Assert-Hash $databaseSchemaPath $expectedDatabaseSchema
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$features = (Get-Content (Join-Path $SpecRoot "FEATURE_REGISTRY.json") -Raw | ConvertFrom-Json).features
$invariants = (Get-Content (Join-Path $SpecRoot "INVARIANT_REGISTRY.json") -Raw | ConvertFrom-Json).invariants
$tests = (Get-Content (Join-Path $SpecRoot "TEST_CATALOG.json") -Raw | ConvertFrom-Json).tests
$slices = (Get-Content (Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json") -Raw | ConvertFrom-Json).slices
$schemas = (Get-Content (Join-Path $SpecRoot "13_IMPLEMENTATION_CONTRACTS\SCHEMA_REGISTRY.json") -Raw | ConvertFrom-Json).schemas
foreach ($id in @("F-003", "F-004", "F-005", "F-006")) {
    if (@($features | Where-Object feature_id -eq $id).Count -ne 1) { throw "Missing feature: $id" }
}
foreach ($id in @("INV-IMM-001", "INV-WS-001")) {
    if (@($invariants | Where-Object invariant_id -eq $id).Count -ne 1) { throw "Missing invariant: $id" }
}
foreach ($id in @("T-011", "T-014", "T-017", "T-INT-031")) {
    if (@($tests | Where-Object test_id -eq $id).Count -ne 1) { throw "Missing test: $id" }
}
$imp = @($slices | Where-Object slice_id -eq "IMP-022")
if ($imp.Count -ne 1 -or $imp[0].title -ne "Content, ContentVersion and independent state services") { throw "IMP-022 binding mismatch" }
$schema = @($schemas | Where-Object schema_name -eq "ccs.content-version-snapshot")
if ($schema.Count -ne 1 -or $schema[0].version -ne 1 -or $schema[0].status -ne "FROZEN_FOR_IMPLEMENTATION") { throw "ContentVersion snapshot schema binding mismatch" }

$registry = Get-Content $r15Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r15" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r15 source" }
if ($registry.registry_digest -ne $expectedR15Digest) { throw "Unexpected embedded r15 digest" }
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-005")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-004" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-005 baseline" }
$leaf = $leaf[0]

$create = @(
    "reports/IMP-022_CCS-02-005_IMPLEMENTATION.md",
    "src/custom_content_studio/application/ports/content_version_repository.py",
    "src/custom_content_studio/application/services/content_versions.py",
    "src/custom_content_studio/domain/content_versions.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/content_versions.py",
    "tests/integration/test_content_version_service.py",
    "tests/repository/test_content_version_repository.py",
    "tests/unit/test_content_version_model.py"
)
$modify = @(
    "src/custom_content_studio/application/ports/__init__.py",
    "src/custom_content_studio/application/services/__init__.py",
    "src/custom_content_studio/bootstrap/composition.py",
    "src/custom_content_studio/domain/__init__.py",
    "src/custom_content_studio/domain/contents.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/contents.py",
    "tests/repository/test_content_repository.py",
    "tests/unit/test_content_model.py"
)
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create path exists: $path" } }
foreach ($path in $modify) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" } }

$leaf.parent_work_package_id = "IMP-022"
$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.application.services.content_versions"
$leaf.feature_ids = @("F-004", "F-005")
$leaf.invariant_ids = @("INV-IMM-001", "INV-WS-001")
$leaf.tests.introduces = @("T-014", "T-INT-031")
$leaf.tests.must_pass = @("T-011", "T-014", "T-017", "T-INT-031")
$leaf.tests.regression = @("T-011", "T-017", "T-INT-031")
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/custom_content_studio/api/**", "src/custom_content_studio/ui/**", "tests/gates/**")
$leaf.commands = @()
$leaf.interfaces = @([ordered]@{kind="PORT"; name="ContentVersionRepositoryPort"; contract_root="SPEC_ROOT"; contract_path="12_CHANGE_CONTROL/CHG-2026-0023_CCS_02_005_CONTENT_VERSION_IDENTITY.md"; direction="BOTH"})
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Implement normalized ccs.content-version-snapshot v1 validation canonicalization projections and exact snapshot_hash.",
    "Create USER-authored DRAFT versions only, with first/null or exact current-head parent linkage and monotonic per-Content numbering.",
    "Insert the version and advance current_version_id using exact Content row_version and prior-head CAS in one transaction.",
    "Preserve every prior version; support Workspace-scoped reads and reject deletion.",
    "Introduce T-014 and T-INT-031; regress T-011 and T-017 under INV-IMM-001 and INV-WS-001.",
    "Widen only the existing Content read model and mapper to load a validated current_version_id."
)
$leaf.out_of_scope = @(
    "ServiceAccount version creation or null creator projection",
    "Approval ReviewSession TimelineApproval edit-as-new-revision restore branching and F-041 or INV-APR-001",
    "ContentVersion or Content status-transition commands owned by CCS-02-006",
    "Asset generation timeline render publication analytics API UI worker scheduler provider and media behavior",
    "Migration SQL manifest schema replacement trigger change and backfill",
    "Runtime or production databases credentials secrets network dependencies deployment and external effects",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE local work packet must bind exact r16 and repository commit before mutation.",
    "Only authenticated USER ActorContext test fixtures and pytest temporary SQLite databases are permitted.",
    "No approval transition migration runtime database credential provider network media API UI deployment or publication action is authorized."
)
$leaf.error_contracts = @("MIGRATION_DECISION_REQUIRED", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE", "VERSION_CONFLICT", "WORKSPACE_ACCESS_DENIED")
$leaf.transaction_requirements = @(
    "One caller-owned BEGIN IMMEDIATE SQLite unit of work; repositories never commit independently.",
    "Version insert and Content authoring-head advance succeed or roll back together.",
    "The Content update predicates on ID Workspace exact row_version and exact prior current_version_id and increments row_version once.",
    "The new row starts DRAFT; no approval status transition or external effect occurs."
)
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="The r16 specification, schema, change-control, registry, discovery or database-schema binding differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-004 or required Content/Workspace evidence is not accepted."},
    [ordered]@{code="MIGRATION_DECISION_REQUIRED"; condition="Implementation requires any SQL schema manifest migration trigger or backfill change."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="The ACTIVE packet omits exact paths tests evidence or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires ServiceAccount creation approval transition external effects or an unlisted path."}
)
$leaf.recovery = [ordered]@{checkpoint_path=$null; resume_requirements=@("Revalidate r16, CHG-2026-0023, snapshot schema, discovery, repository commit and database-schema hash.", "Confirm create paths remain absent and modify paths match the ACTIVE baseline."); rollback=@()}
$leaf.evidence = @(
    [ordered]@{evidence_id="EV-CCS-02-005-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-005_CONTENT_VERSION_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false},
    [ordered]@{evidence_id="EV-CCS-02-005-DATABASE-SCHEMA"; kind="FILE"; required=$true; path="migrations/0001_initial_v2_2.sql"; expected_sha256=$databaseSchemaHash; sensitivity="INTERNAL"; redaction_required=$false}
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r16"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-005"
$registry.context.next_recommendation.candidate_slice_id = "IMP-022"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CHG-2026-0023 closes CCS-02-005 snapshot and head identity; a separate ACTIVE local work packet remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-005_CONTENT_VERSION_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-005 Immutable ContentVersion Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r16 preserves r15 and resolves CCS-02-005 only. It corrects parent IMP-020 to IMP-022, retains
depends_on=[CCS-02-004] and binds CHG-2026-0023 plus the registered ContentVersion snapshot schema.
The exact envelope has 8 create and 9 modify paths. It binds F-004/F-005, INV-IMM-001/INV-WS-001,
T-014/T-INT-031 and T-011/T-017 regression.

- r15 SHA-256: $r15Hash
- r15 registry digest: $expectedR15Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0023 SHA-256: $changeHash
- snapshot schema SHA-256: $snapshotSchemaHash
- database schema SHA-256: $databaseSchemaHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED

Creation is USER-only. Approval lineage/status transitions, migrations, runtime databases,
credentials, network/provider/media, API/UI, deployment and publication remain forbidden. r16 is
DRAFT, NOT_EVALUATED and implementation_authorized=false. No product code or test is created here.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r16Dir) | Out-Null
[IO.File]::WriteAllText($r16Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r16Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r16Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$verified = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r16Path --profile task-registry).Trim()
if ($verified -ne $digest) { throw "Embedded digest verification failed" }
if ((Get-FileHash $r15Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedR15) { throw "r15 changed" }

[pscustomobject]@{r16_path=$r16Path; registry_digest=$digest; report_path=$reportPath; report_sha256=$registry.readiness.report_sha256; create_paths=$create.Count; modify_paths=$modify.Count; resolved=$resolved; discovery_required=$discovery; implementation_authorized=$registry.implementation_authorized} | Format-List
