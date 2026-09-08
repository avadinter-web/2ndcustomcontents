param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR16 = "7fa3621fd8aeb72a627855eabd8ec288c76f012b14f5daa714e2e11d4b8547d4"
$expectedR16Digest = "62bd1c4b91fc867786c51797fb983c057edaa3c48149fcc377d06df579160645"
$expectedDiscovery = "5841269e1f9fe4e345ae2ac93fea8d507d33a42d302480ce316be84673ac333e"
$expectedChange = "e6e9711de8bae1058f8cf22a583a7b3d8ce469e0d44299bbb82fd44f9facc0d9"
$expectedSpec = "f1083df87ea9bf50fe4c19c60363e7a0e1a5fd2aa7cb562ec84ecdecc88ddd54"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r16Path = Join-Path $revisions "vc01b-local-20260907-r16\task-registry.json"
$r17Dir = Join-Path $revisions "vc01b-local-20260907-r17"
$r17Path = Join-Path $r17Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-006_STATE_TRANSITION_DISCOVERY.md"
$changePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\CHG-2026-0024_CCS_02_006_STATE_TRANSITION_BOUNDARY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-006_STATE_TRANSITION_ENVELOPE_RESOLUTION.md"

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw "Hash mismatch: $Path = $actual" }
    return $actual
}

foreach ($target in @($r17Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r17 output: $target" }
}
$r16Hash = Assert-Hash $r16Path $expectedR16
$discoveryHash = Assert-Hash $discoveryPath $expectedDiscovery
$changeHash = Assert-Hash $changePath $expectedChange
$packageHash = Assert-Hash (Join-Path $SpecRoot "PACKAGE_INDEX.json") $expectedSpec

$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$registry = Get-Content $r16Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r16" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r16 source" }
if ($registry.registry_digest -ne $expectedR16Digest) { throw "Unexpected embedded r16 digest" }
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-006")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-005" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-006 baseline" }
$leaf = $leaf[0]

$create = @(
    "reports/IMP-022_CCS-02-006_IMPLEMENTATION.md",
    "src/custom_content_studio/domain/content_state_transitions.py",
    "src/custom_content_studio/application/ports/content_state_transition_repository.py",
    "src/custom_content_studio/application/services/content_state_transitions.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/content_state_transitions.py",
    "tests/unit/test_content_state_transition_policy.py",
    "tests/repository/test_content_state_transition_repository.py",
    "tests/integration/test_content_state_transition_service.py"
)
$modify = @(
    "src/custom_content_studio/domain/__init__.py",
    "src/custom_content_studio/application/ports/__init__.py",
    "src/custom_content_studio/application/services/__init__.py",
    "src/custom_content_studio/infrastructure/sqlite/repositories/__init__.py",
    "src/custom_content_studio/bootstrap/composition.py"
)
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create path exists: $path" } }
foreach ($path in $modify) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" } }

$leaf.parent_work_package_id = "IMP-022"
$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.application.services.content_state_transitions"
$leaf.feature_ids = @("F-005")
$leaf.invariant_ids = @("INV-IMM-001", "INV-WS-001")
$leaf.tests.introduces = @("T-016")
$leaf.tests.must_pass = @("T-011", "T-014", "T-015", "T-016", "T-017", "T-INT-031", "T-INT-050")
$leaf.tests.regression = @("T-011", "T-014", "T-015", "T-017", "T-INT-031", "T-INT-050")
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/custom_content_studio/api/**", "src/custom_content_studio/ui/**", "tests/gates/**")
$leaf.commands = @()
$leaf.interfaces = @([ordered]@{kind="PORT"; name="ContentStateTransitionRepositoryPort"; contract_root="SPEC_ROOT"; contract_path="12_CHANGE_CONTROL/CHG-2026-0024_CCS_02_006_STATE_TRANSITION_BOUNDARY.md"; direction="BOTH"})
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Implement ActivateContent for exact IDEA to ACTIVE with a current DRAFT authoring head.",
    "Implement ArchiveContent for exact ACTIVE to ARCHIVED with matching updated_at and archived_at.",
    "Implement SubmitContentVersionForReview for exact DRAFT to REVIEW_REQUIRED while preserving version identity.",
    "Require authenticated USER CONTENT_EDIT Workspace scope and exact source-state plus row-version CAS.",
    "Reject every other Content and ContentVersion edge with INVALID_STATE_TRANSITION.",
    "Introduce T-016 and regress T-011 T-014 T-015 T-017 T-INT-031 and T-INT-050."
)
$leaf.out_of_scope = @(
    "CCS-07 approval revision rejection and APPROVED to SUPERSEDED lineage",
    "ReviewSession TimelineApproval approved_at approved_by approval selection restore and edit-as-new-revision",
    "Migration SQL manifest schema trigger change and backfill",
    "API UI derived workflow summary Asset render publication and media behavior",
    "Runtime or production databases credentials secrets network provider dependencies deployment publication and external effects",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE local work packet must bind exact r17 and repository commit before mutation.",
    "Only authenticated USER ActorContext fixtures and pytest temporary SQLite databases are permitted.",
    "No approval lineage migration runtime database credential provider network API UI deployment publication or external action is authorized."
)
$leaf.error_contracts = @("DOMAIN_VALIDATION_FAILED", "INVALID_STATE_TRANSITION", "MIGRATION_DECISION_REQUIRED", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE", "VERSION_CONFLICT", "WORKSPACE_ACCESS_DENIED")
$leaf.transaction_requirements = @(
    "One caller-owned BEGIN IMMEDIATE SQLite unit of work; repositories never commit independently.",
    "Each update predicates on owning Workspace resource ID exact source state and exact row_version and increments row_version once.",
    "Any failure rolls back the complete transition and no external effect occurs."
)
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="The r17 specification change-control registry or discovery binding differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-005 or required Content and ContentVersion evidence is not accepted."},
    [ordered]@{code="MIGRATION_DECISION_REQUIRED"; condition="Implementation requires any migration SQL schema manifest trigger or backfill change."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="The ACTIVE packet omits exact paths tests evidence or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires CCS-07 lineage external effects or an unlisted path."}
)
$leaf.recovery = [ordered]@{checkpoint_path=$null; resume_requirements=@("Revalidate r17 CHG-2026-0024 discovery repository commit and prerequisite acceptance.", "Confirm create paths remain absent and modify paths match the ACTIVE baseline."); rollback=@()}
$leaf.evidence = @(
    [ordered]@{evidence_id="EV-CCS-02-006-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-006_STATE_TRANSITION_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false}
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r17"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-006"
$registry.context.next_recommendation.candidate_slice_id = "IMP-022"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CHG-2026-0024 closes the exact CCS-02-006 transition boundary; a separate ACTIVE local work packet remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-006_STATE_TRANSITION_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-006 Immutable State Transition Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r17 preserves r16 and resolves CCS-02-006 only. It corrects parent IMP-021 to IMP-022, retains
depends_on=[CCS-02-005] and binds CHG-2026-0024. The exact envelope has 8 create and 5 modify paths.
It owns F-005/T-016 and regresses Workspace, CAS, Content state and ContentVersion preservation.

- r16 SHA-256: $r16Hash
- r16 registry digest: $expectedR16Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0024 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED

Only Content IDEA->ACTIVE->ARCHIVED and ContentVersion DRAFT->REVIEW_REQUIRED are in scope.
CCS-07 lineage, migrations, runtime databases, credentials, network/provider/media, API/UI,
deployment, publication and external effects remain forbidden. r17 is DRAFT, NOT_EVALUATED and
implementation_authorized=false. No product code or test is created here.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r17Dir) | Out-Null
[IO.File]::WriteAllText($r17Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r17Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r17Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$verified = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r17Path --profile task-registry).Trim()
if ($verified -ne $digest) { throw "Embedded digest verification failed" }
if ((Get-FileHash $r16Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedR16) { throw "r16 changed" }

[pscustomobject]@{r17_path=$r17Path; registry_digest=$digest; report_path=$reportPath; create_paths=$create.Count; modify_paths=$modify.Count; implementation_authorized=$registry.implementation_authorized} | Format-List
