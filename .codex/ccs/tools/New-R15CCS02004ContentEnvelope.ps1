param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR14 = "9c63a5c9a6a4d0941bcf8aa9d0cb2dcf9acfede0fdf5c8356449e4f64ee51a15"
$expectedR14Digest = "7a6bd34d414ff31db8d815726ac91cd2817cd65f92b84f268b08c4dfc9a38a9b"
$expectedDiscovery = "3bb6b213dff030432dd8835c0a53ceae83ed0edaa5056edcf584c53293db140c"
$expectedSpec = "89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278"
$expectedSchema = "2b532c6fbe5b45241f2cd815b6de4947d0a056b32754165fd06c1e9c12a2980f"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r14Path = Join-Path $revisions "vc01b-local-20260907-r14\task-registry.json"
$r15Dir = Join-Path $revisions "vc01b-local-20260907-r15"
$r15Path = Join-Path $r15Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-004_CONTENT_MODEL_DISCOVERY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-004_CONTENT_ENVELOPE_RESOLUTION.md"
$schemaPath = Join-Path $repoRoot "migrations\0001_initial_v2_2.sql"

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw "Hash mismatch: $Path = $actual" }
    return $actual
}

foreach ($target in @($r15Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r15 output: $target" }
}
$r14Hash = Assert-Hash $r14Path $expectedR14
$discoveryHash = Assert-Hash $discoveryPath $expectedDiscovery
$packageHash = Assert-Hash (Join-Path $SpecRoot "PACKAGE_INDEX.json") $expectedSpec
$schemaHash = Assert-Hash $schemaPath $expectedSchema
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$features = (Get-Content (Join-Path $SpecRoot "FEATURE_REGISTRY.json") -Raw | ConvertFrom-Json).features
$invariants = (Get-Content (Join-Path $SpecRoot "INVARIANT_REGISTRY.json") -Raw | ConvertFrom-Json).invariants
$tests = (Get-Content (Join-Path $SpecRoot "TEST_CATALOG.json") -Raw | ConvertFrom-Json).tests
$slices = (Get-Content (Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json") -Raw | ConvertFrom-Json).slices
foreach ($id in @("F-003", "F-004", "F-005", "F-006")) {
    if (@($features | Where-Object feature_id -eq $id).Count -ne 1) { throw "Missing feature: $id" }
}
if (@($invariants | Where-Object invariant_id -eq "INV-WS-001").Count -ne 1) { throw "Missing INV-WS-001" }
foreach ($id in @("T-011", "T-015", "T-017", "T-INT-050")) {
    if (@($tests | Where-Object test_id -eq $id).Count -ne 1) { throw "Missing test: $id" }
}
$imp = @($slices | Where-Object slice_id -eq "IMP-022")
if ($imp.Count -ne 1 -or $imp[0].title -ne "Content, ContentVersion and independent state services") {
    throw "IMP-022 binding mismatch"
}

$registry = Get-Content $r14Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r14" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) {
    throw "Unexpected r14 source"
}
if ($registry.registry_digest -ne $expectedR14Digest) { throw "Unexpected embedded r14 digest" }
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-004")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-003" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") {
    throw "Unexpected CCS-02-004 baseline"
}
$leaf = $leaf[0]

$create = @(
    "reports/IMP-022_CCS-02-004_IMPLEMENTATION.md",
    "src/custom_content_studio/application/ports/content_repository.py",
    "src/custom_content_studio/application/services/contents.py",
    "src/custom_content_studio/domain/contents.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/contents.py",
    "tests/integration/test_content_service.py",
    "tests/repository/test_content_repository.py",
    "tests/unit/test_content_model.py"
)
$modify = @(
    "src/custom_content_studio/application/ports/__init__.py",
    "src/custom_content_studio/application/services/__init__.py",
    "src/custom_content_studio/bootstrap/composition.py",
    "src/custom_content_studio/domain/__init__.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py"
)
foreach ($path in $create) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create path exists: $path" }
}
foreach ($path in $modify) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" }
}

$leaf.parent_work_package_id = "IMP-022"
$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.application.services.contents"
$leaf.feature_ids = @("F-004", "F-005")
$leaf.invariant_ids = @("INV-WS-001")
$leaf.tests.introduces = @("T-015")
$leaf.tests.must_pass = @("T-011", "T-015", "T-017", "T-INT-050")
$leaf.tests.regression = @("T-011", "T-017", "T-INT-050")
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @(
    ".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock",
    "src/custom_content_studio/api/**", "src/custom_content_studio/ui/**", "tests/gates/**"
)
$leaf.commands = @()
$leaf.interfaces = @([ordered]@{
    kind = "PORT"
    name = "ContentRepositoryPort"
    contract_root = "SPEC_ROOT"
    contract_path = "01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md"
    direction = "BOTH"
})
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Implement only the Content aggregate and Workspace/Project-scoped CRUD subset of F-004 under IMP-022.",
    "Define ContentType and the persisted ContentStatus vocabulary IDEA ACTIVE ARCHIVED, with new Content initially IDEA.",
    "Treat the closed persisted Content state vocabulary as the CCS-02-004 subset of F-005; do not implement transition execution.",
    "Use concealed cross-Workspace lookup, same-Workspace Project association and exact row_version CAS.",
    "Introduce T-015; regress T-011 T-017 and the Content case of T-INT-050 under INV-WS-001.",
    "Keep current_version_id null and leave all linkage to CCS-02-005."
)
$leaf.out_of_scope = @(
    "ContentVersion ReviewSession approval current-version mutation version numbering and INV-APR-001",
    "State-transition commands invalid-transition decisions and derived workflow summaries owned by CCS-02-006",
    "Asset API UI worker scheduler provider media and publication behavior",
    "Migration SQL manifest schema replacement and backfill",
    "Runtime or production databases credentials secrets network dependencies deployment and external effects",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE work packet must bind exact r15 and repository commit before mutation.",
    "Only pytest temporary SQLite databases and synthetic local data are permitted.",
    "No migration runtime database credential provider network media API UI deployment or publication action is authorized."
)
$leaf.error_contracts = @(
    "MIGRATION_DECISION_REQUIRED", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION",
    "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE", "VERSION_CONFLICT", "WORKSPACE_ACCESS_DENIED"
)
$leaf.transaction_requirements = @(
    "One caller-owned local SQLite unit of work; repositories never commit independently.",
    "Mutable descriptive fields use exact row_version CAS and increment once.",
    "Workspace identity and initial Content identity are immutable.",
    "No transition, current-version, external, provider, filesystem, media or runtime database effect is permitted."
)
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="The r15 specification, registry, discovery or schema binding differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-003 or required Workspace/Project/Asset evidence is not accepted."},
    [ordered]@{code="MIGRATION_DECISION_REQUIRED"; condition="Implementation requires any schema, manifest, migration or backfill change."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="The ACTIVE packet omits exact paths, tests, evidence or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires ContentVersion, transition execution, external effects or an unlisted path."}
)
$leaf.recovery = [ordered]@{
    checkpoint_path = $null
    resume_requirements = @(
        "Revalidate r15, discovery, repository commit and existing Content schema hash.",
        "Confirm create paths remain absent and modify paths match the ACTIVE baseline."
    )
    rollback = @()
}
$leaf.evidence = @(
    [ordered]@{
        evidence_id = "EV-CCS-02-004-DISCOVERY"
        kind = "FILE"
        required = $true
        path = "reports/CCS-02-004_CONTENT_MODEL_DISCOVERY.md"
        expected_sha256 = $discoveryHash
        sensitivity = "INTERNAL"
        redaction_required = $false
    },
    [ordered]@{
        evidence_id = "EV-CCS-02-004-SCHEMA"
        kind = "FILE"
        required = $true
        path = "migrations/0001_initial_v2_2.sql"
        expected_sha256 = $schemaHash
        sensitivity = "INTERNAL"
        redaction_required = $false
    }
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r15"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-004"
$registry.context.next_recommendation.candidate_slice_id = "IMP-022"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CCS-02-004 Content model envelope is resolved under IMP-022; separate ACTIVE authorization remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-004_CONTENT_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-004 Immutable Content Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r15 preserves r14 and resolves CCS-02-004 only. It corrects parent IMP-023 to canonical IMP-022,
preserves depends_on=[CCS-02-003], assigns owner custom_content_studio.application.services.contents,
and binds exactly 8 create plus 5 modify paths. It owns the Content subset of F-004 and the closed
persisted-state vocabulary subset of F-005, introduces T-015, regresses T-011/T-017 and the Content
case of T-INT-050, and binds INV-WS-001.

- r14 SHA-256: $r14Hash
- r14 registry digest: $expectedR14Digest
- discovery SHA-256: $discoveryHash
- existing Content schema SHA-256: $schemaHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED

ContentVersion/current-version/approval lineage and transition execution remain owned by CCS-02-005
and CCS-02-006 respectively. Migration/schema/manifest, runtime or production DB, credentials,
network/provider/media, API/UI, deployment and publication actions remain forbidden. r15 stays
DRAFT, NOT_EVALUATED and implementation_authorized=false. No product code or test is created here.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r15Dir) | Out-Null
[IO.File]::WriteAllText($r15Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r15Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r15Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$verified = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r15Path --profile task-registry).Trim()
if ($verified -ne $digest) { throw "Embedded digest verification failed" }
if ((Get-FileHash $r14Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedR14) { throw "r14 changed" }

[pscustomobject]@{
    r15_path = $r15Path
    registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    create_paths = $create.Count
    modify_paths = $modify.Count
    resolved = $resolved
    discovery_required = $discovery
    implementation_authorized = $registry.implementation_authorized
} | Format-List
