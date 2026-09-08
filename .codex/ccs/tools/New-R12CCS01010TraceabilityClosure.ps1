param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR11 = "ee27301abce28f6665ca341ce7112b1689e96d6fe6e2e2a8ebe792ec0b51acbb"
$expectedDiscovery = "ed067eed3fbe97777fc6dccb7754c7b99d4424469ec12517c52de51758c64cb1"
$expectedProposal = "18a6d7d5d74fc75d7ce22d32fbe885be9519e80a625cd8da1b7a148b614bbd2e"
$specHashes = [ordered]@{
    "PACKAGE_INDEX.json" = "89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278"
    "FEATURE_REGISTRY.json" = "fd15dbe7675ac3c86f3a30ae93ed4d636c01992941d5a33458eabc7aacb28378"
    "INVARIANT_REGISTRY.json" = "523924aadade515bbd7e888a95ccb30f259e0e9fca89e25197dd5387c63b07d6"
    "TEST_CATALOG.json" = "7352f0ca759c8e3c23e5e2273116670a96f895870aab3d366d38a78c25ef1ceb"
    "IMPLEMENTATION_REGISTRY.json" = "7c3c434e844eff98c7a67bce0a7d9f8e40ee45aa764f01b7c04e8f387802d01d"
    "10_TESTS\V2_2_INTEGRITY_TESTS.md" = "9b50c5b318663468247efc15bb8eb5f463e72010a26743e70023797532ec0122"
    "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md" = "36f5c38e03131bc8b37cde27f97095964c08ebb2fdf2780fcca5016b922a7753"
    "11_CODEX_TASKS\CCS-01_TASKS.md" = "80c7b6be1f5a412c206ba2ce1b603854cbe6a4d0ebf255d64355ed270450846a"
    "09_SHARED_SPEC\AUTH_SESSION_CONTRACT.md" = "3b39b11fda7769cdc15f244236e2703aaf302c97707b0e4fb526d012f5c72d47"
    "09_SHARED_SPEC\SECURITY.md" = "c5aedd9180c06aa0a639e0ba319dd353297ec13921cf776b3f0faddfec18afad"
    "09_SHARED_SPEC\AUDIT_CHAIN.md" = "71bb8a5d6e483b010abf1971dc17fe2aa68e6f2387210ba600d9b3841735984b"
    "09_SHARED_SPEC\TRANSACTION_AND_CONCURRENCY.md" = "7dc10b43699f0bccb9f68421c7774ba2f290939d957799a9d654104e65a66fbf"
    "09_SHARED_SPEC\PORT_AND_ADAPTER_INTERFACES.md" = "07ebd23ef8d5241560998ff2e58599997fae31ca5cc34acd45c567d638b27cce"
    "09_SHARED_SPEC\APPLICATION_SERVICE_CONTRACTS.md" = "4ca480e3e93b6f6db4599fb42e1801b7821fc9255e3619d27495abfb7a7f9242"
    "12_CHANGE_CONTROL\CHANGELOG.md" = "96d14380b49a70f7bee06240a70a576f083860cb8b8a6e171c12667ca4f2624f"
}

$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r11Path = Join-Path $revisions "vc01b-local-20260907-r11\task-registry.json"
$r12Dir = Join-Path $revisions "vc01b-local-20260907-r12"
$r12Path = Join-Path $r12Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-01-010_DISCOVERY_WORK_PACKET.md"
$proposalPath = Join-Path $repoRoot "reports\CCS-01-010_SPEC_CHANGE_CONTROL_PROPOSAL.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01-010_TRACEABILITY_CLOSURE.md"

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw ("Hash mismatch: " + $Path + " = " + $actual) }
    $actual
}

foreach ($target in @($r12Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r12 output: $target" }
}
$r11Hash = Assert-Hash $r11Path $expectedR11
$discoveryHash = Assert-Hash $discoveryPath $expectedDiscovery
$proposalHash = Assert-Hash $proposalPath $expectedProposal
foreach ($relative in $specHashes.Keys) {
    Assert-Hash (Join-Path $SpecRoot $relative) $specHashes[$relative] | Out-Null
}
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join [Environment]::NewLine) -notmatch "SPEC SYNC: PASS") {
    throw ("Spec sync failed: " + ($sync -join "; "))
}

$features = (Get-Content (Join-Path $SpecRoot "FEATURE_REGISTRY.json") -Raw | ConvertFrom-Json).features
$invariants = (Get-Content (Join-Path $SpecRoot "INVARIANT_REGISTRY.json") -Raw | ConvertFrom-Json).invariants
$tests = (Get-Content (Join-Path $SpecRoot "TEST_CATALOG.json") -Raw | ConvertFrom-Json).tests
$slices = (Get-Content (Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json") -Raw | ConvertFrom-Json).slices
if (@($features | Where-Object feature_id -eq "F-043").Count -ne 1 -or
    @($features | Where-Object feature_id -eq "F-077").Count -ne 1) { throw "Feature binding missing" }
if (@($invariants | Where-Object invariant_id -eq "INV-AUD-001").Count -ne 1 -or
    @($invariants | Where-Object invariant_id -eq "INV-AUTH-002").Count -ne 1) { throw "Invariant binding missing" }
foreach ($id in @("T-INT-092", "T-INT-093", "T-INT-138")) {
    if (@($tests | Where-Object test_id -eq $id).Count -ne 1) { throw "Test binding missing: $id" }
}
$imp012 = @($slices | Where-Object slice_id -eq "IMP-012")
if ($imp012.Count -ne 1 -or (@($imp012[0].feature_ids) -join ",") -ne "F-003,F-043,F-051,F-059,F-077") {
    throw "IMP-012 binding mismatch"
}
$changelog = Get-Content (Join-Path $SpecRoot "12_CHANGE_CONTROL\CHANGELOG.md") -Raw
if ([regex]::Matches($changelog, "(?m)^## CHG-2026-0022 ").Count -ne 1) {
    throw "CHG-2026-0022 missing or duplicated"
}

$registry = Get-Content $r11Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r11" -or
    $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) {
    throw "Unexpected r11 source"
}
$matches = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-01-010")
if ($matches.Count -ne 1) { throw "Expected one CCS-01-010" }
$leaf = $matches[0]
if ($leaf.parent_work_package_id -ne "IMP-012" -or
    (@($leaf.depends_on) -join ",") -ne "CCS-01-009" -or
    $leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected r11 leaf baseline" }

$create = @(
    "reports/IMP-012_CCS-01-010_IMPLEMENTATION.md",
    "src/custom_content_studio/application/ports/audit_event_repository.py",
    "src/custom_content_studio/application/ports/service_account_repository.py",
    "src/custom_content_studio/application/services/service_account_credentials.py",
    "src/custom_content_studio/domain/security/service_accounts.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/audit_events.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/service_accounts.py",
    "tests/integration/test_service_account_credential_rotation.py",
    "tests/repository/test_audit_event_repository.py",
    "tests/repository/test_service_account_repository.py",
    "tests/unit/test_service_account_credentials.py"
)
$modify = @(
    "src/custom_content_studio/application/ports/__init__.py",
    "src/custom_content_studio/application/services/__init__.py",
    "src/custom_content_studio/bootstrap/composition.py",
    "src/custom_content_studio/domain/security/__init__.py",
    "src/custom_content_studio/domain/security/models.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py",
    "tests/unit/test_security_contract.py"
)
foreach ($path in $create) {
    if (Test-Path (Join-Path $repoRoot $path)) { throw "Create path exists: $path" }
}
foreach ($path in $modify) {
    if (-not (Test-Path (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" }
}

$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.application.services.service_account_credentials"
$leaf.feature_ids = @("F-043", "F-077")
$leaf.invariant_ids = @("INV-AUD-001", "INV-AUTH-002")
$leaf.tests.introduces = @("T-INT-092", "T-INT-093", "T-INT-138")
$leaf.tests.must_pass = @("T-INT-092", "T-INT-093", "T-INT-138")
$leaf.tests.regression = @()
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @("**/*.db", "**/*.key", "**/*.pem", "**/*.sqlite", "**/*.sqlite3", ".env", ".env.*", ".runtime/**", "config/**", "credentials/**", "data/**", "db/**", "migrations/**")
$leaf.commands = @()
$leaf.interfaces = @(
    [ordered]@{kind="PORT"; name="ServiceAccountCredentialService"; contract_root="SPEC_ROOT"; contract_path="09_SHARED_SPEC/APPLICATION_SERVICE_CONTRACTS.md"; direction="PROVIDES"},
    [ordered]@{kind="PORT"; name="ServiceAccountRepositoryPort"; contract_root="SPEC_ROOT"; contract_path="09_SHARED_SPEC/PORT_AND_ADAPTER_INTERFACES.md"; direction="BOTH"},
    [ordered]@{kind="PORT"; name="AuditEventAppendPort"; contract_root="SPEC_ROOT"; contract_path="09_SHARED_SPEC/PORT_AND_ADAPTER_INTERFACES.md"; direction="BOTH"},
    [ordered]@{kind="EVENT"; name="SERVICE_ACCOUNT_CREDENTIAL_ROTATED"; contract_root="SPEC_ROOT"; contract_path="09_SHARED_SPEC/AUDIT_CHAIN.md"; direction="PROVIDES"}
)
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Local-only ServiceAccount credential-reference rotation using synthetic non-secret locators.",
    "Same-Workspace USER ADMIN authorization with SECRET_REFERENCE_MANAGE; ServiceAccount self-rotation denied.",
    "Exact updated_at CAS and one caller-owned SQLite transaction for account update plus ordered audit append.",
    "First runtime ownership of F-043 and dedicated F-077 behavior.",
    "Locator-hash-only audit payload and T-INT-092, T-INT-093, T-INT-138 tests."
)
$leaf.out_of_scope = @(
    "Actual credential creation resolution rotation revocation or deletion",
    "Account role status or permission changes",
    "OS secret stores environment secrets provider APIs and network access",
    "Runtime or production databases migrations schema edits and backfill",
    "API UI worker scheduler deployment publication and external services",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE work packet must bind exact r12 and repository commit before mutation.",
    "Only synthetic locators and pytest temporary SQLite databases are permitted.",
    "VC-02 and CCS-01-009 prerequisite acceptance must be valid."
)
$leaf.error_contracts = @("DOMAIN_VALIDATION_FAILED", "PREREQUISITE_NOT_ACCEPTED", "TASK_ENVELOPE_INCOMPLETE", "VERSION_CONFLICT", "WORKSPACE_ACCESS_DENIED")
$leaf.transaction_requirements = @(
    "One caller-owned BEGIN IMMEDIATE SQLite unit of work.",
    "Exact expected_updated_at_utc CAS; stale writer returns VERSION_CONFLICT.",
    "Update only credential_secret_ref credential_rotated_at and updated_at.",
    "Append exactly one SERVICE_ACCOUNT_CREDENTIAL_ROTATED event without independent commit.",
    "Rollback account update and audit append together.",
    "No secret resolution provider call network or external I/O."
)
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="CHG-2026-0022 package binding differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="VC-02 or CCS-01-009 acceptance is invalid."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="ACTIVE packet omits exact paths commands tests evidence or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires credentials network runtime DB migration or an unlisted path."}
)
$leaf.recovery = [ordered]@{
    checkpoint_path = $null
    resume_requirements = @("Revalidate r11 discovery proposal CHG-2026-0022 and r12 digests.", "Confirm create paths remain absent and modify paths match the ACTIVE baseline.")
    rollback = @()
}
$leaf.evidence = @(
    [ordered]@{evidence_id="EV-CCS-01-010-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-01-010_DISCOVERY_WORK_PACKET.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false},
    [ordered]@{evidence_id="EV-CCS-01-010-CHANGE-PROPOSAL"; kind="FILE"; required=$true; path="reports/CCS-01-010_SPEC_CHANGE_CONTROL_PROPOSAL.md"; expected_sha256=$proposalHash; sensitivity="INTERNAL"; redaction_required=$false}
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r12"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $specHashes["PACKAGE_INDEX.json"]
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-010"
$registry.context.next_recommendation.candidate_slice_id = "IMP-012"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CCS-01-010 local traceability and paths are resolved; separate ACTIVE authorization and prerequisite acceptance remain required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-010_TRACEABILITY_CLOSURE.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-01-010 Immutable Traceability and Audit Ownership Closure

Status: DRAFT / LOCAL SCOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-08

## Outcome

Immutable successor r12 binds CHG-2026-0022 and resolves CCS-01-010 under IMP-012 without changing
r11. The leaf owns F-043, F-077, INV-AUD-001 and INV-AUTH-002 and introduces/must pass T-INT-092,
T-INT-093 and T-INT-138. It remains DRAFT, NOT_EVALUATED and implementation_authorized=false.

## Immutable sources

| Evidence | SHA-256 |
|---|---|
| r11 registry | $r11Hash |
| CHG-2026-0022 PACKAGE_INDEX | $($specHashes["PACKAGE_INDEX.json"]) |
| discovery packet | $discoveryHash |
| change-control proposal | $proposalHash |
| repository commit at generation | $currentCommit |

## Exact local envelope

- Parent/dependency: IMP-012 / CCS-01-009.
- Owner: custom_content_studio.application.services.service_account_credentials.
- Paths: 11 exact creates and 7 exact modifies.
- Commands remain empty until a separate ACTIVE attempt binds immutable process contracts.
- Migrations, credentials, secret resolution, network, external effects and runtime/production DBs are forbidden.
- Synthetic locators and pytest temporary SQLite databases are the only permitted data boundary.
- Registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED.

## Transaction and security boundary

A same-Workspace USER ADMIN with SECRET_REFERENCE_MANAGE performs an exact updated_at CAS. The
account update and one ordered SERVICE_ACCOUNT_CREDENTIAL_ROTATED audit append share one
caller-owned transaction and roll back together. Audit contains only old/new locator SHA-256
values. No raw credential or locator is resolved, logged, returned or transmitted.

## Preservation and next action

r11 remains byte-identical. No product code, test, migration, credential, database, provider,
deployment or publication operation is performed or authorized. The next controlled action is a
separate attempt-scoped ACTIVE work packet for CCS-01-010 bound to this exact r12 and commit.

## Reproduction

Run .codex/ccs/tools/New-R12CCS01010TraceabilityClosure.ps1. It verifies r11, discovery, proposal,
the CHG-2026-0022 package hashes, strict sync and exact path existence, and refuses overwrite.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r12Dir) | Out-Null
[IO.File]::WriteAllText($r12Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r12Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r12Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
if ((Get-FileHash $r11Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedR11) { throw "r11 changed" }

[pscustomobject]@{
    r11_sha256 = $r11Hash
    spec_package_digest = $specHashes["PACKAGE_INDEX.json"]
    r12_path = $r12Path
    r12_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    create_paths = $create.Count
    modify_paths = $modify.Count
    resolved = $resolved
    discovery_required = $discovery
    implementation_authorized = $registry.implementation_authorized
} | Format-List
