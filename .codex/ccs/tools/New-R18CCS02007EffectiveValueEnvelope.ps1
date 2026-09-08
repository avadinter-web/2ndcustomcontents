param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r17Path = Join-Path $revisions "vc01b-local-20260907-r17\task-registry.json"
$r18Dir = Join-Path $revisions "vc01b-local-20260907-r18"
$r18Path = Join-Path $r18Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-007_EFFECTIVE_VALUE_DISCOVERY.md"
$changePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\CHG-2026-0025_CCS_02_007_EFFECTIVE_VALUE_RESOLVER.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-007_EFFECTIVE_VALUE_ENVELOPE_RESOLUTION.md"

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

foreach ($target in @($r18Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r18 output: $target" }
}

$r17Hash = Get-Sha256 $r17Path
$discoveryHash = Get-Sha256 $discoveryPath
$changeHash = Get-Sha256 $changePath
$packageHash = Get-Sha256 (Join-Path $SpecRoot "PACKAGE_INDEX.json")
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$registry = Get-Content -Raw $r17Path | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r17" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r17 source" }
$r17Digest = $registry.registry_digest
$leafMatches = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-007")
if ($leafMatches.Count -ne 1) { throw "CCS-02-007 is not uniquely defined in r17" }
$leaf = $leafMatches[0]
if ((@($leaf.depends_on) -join ",") -ne "CCS-02-006" -or $leaf.parent_work_package_id -ne "IMP-022" -or $leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-007 baseline" }

$create = @(
    "reports/IMP-022_CCS-02-007_IMPLEMENTATION.md",
    "src/custom_content_studio/domain/effective_values.py",
    "tests/unit/test_effective_values.py"
)
$modify = @("src/custom_content_studio/domain/__init__.py")
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create path exists: $path" } }
foreach ($path in $modify) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" } }

$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.domain.effective_values"
$leaf.feature_ids = @("F-078")
$leaf.invariant_ids = @("INV-EFFECTIVE-001")
$leaf.tests.introduces = @("T-018")
$leaf.tests.must_pass = @("T-018")
$leaf.tests.regression = @()
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/custom_content_studio/api/**", "src/custom_content_studio/ui/**", "tests/gates/**")
$leaf.interfaces = @([ordered]@{kind="DOMAIN_POLICY"; name="EffectiveValueResolver"; contract_root="SPEC_ROOT"; contract_path="12_CHANGE_CONTROL/CHG-2026-0025_CCS_02_007_EFFECTIVE_VALUE_RESOLVER.md"; direction="IN_PROCESS"})
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Implement a pure no-I/O four-layer effective value resolver with OVERRIDE AUTO PROJECT_DEFAULT SYSTEM_DEFAULT precedence.",
    "Represent absence independently from an explicitly present JSON null and return source provenance with every resolved output.",
    "Return an explicit unresolved outcome when every candidate is absent; caller supplies field mapping and candidate envelopes.",
    "Implement reset-to-AI as removal of OVERRIDE presence only, without mutation of AUTO or defaults.",
    "Introduce T-018 under INV-EFFECTIVE-001 and F-078; F-009 and T-050 remain CCS-05-owned."
)
$leaf.out_of_scope = @(
    "F-009 and T-050 Design override/reset product, UI, API and persistence ownership",
    "DesignOverride DesignPreset recipe Content ContentVersion timeline keyframe reframe or render mutation",
    "Migration SQL manifest schema trigger and backfill",
    "Runtime or production databases API UI credentials secrets network provider media dependencies deployment publication and external effects",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE local work packet must bind exact r18 and repository commit before mutation.",
    "Only pure unit tests with synthetic in-memory values are permitted.",
    "No persistence migration external operation or CCS-05 ownership transfer is authorized."
)
$leaf.error_contracts = @("DOMAIN_VALIDATION_FAILED", "MIGRATION_DECISION_REQUIRED", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE")
$leaf.transaction_requirements = @("The resolver is pure and performs no transaction, persistence mutation, external effect or caller-input mutation.")
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="The r18 change-control, discovery or package binding differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-006 acceptance is absent."},
    [ordered]@{code="MIGRATION_DECISION_REQUIRED"; condition="Implementation needs database storage, migration, SQL, manifest, trigger or backfill."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="The ACTIVE packet omits exact paths, T-018, F-078, INV-EFFECTIVE-001 or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires F-009/T-050 transfer, persistence/API/UI/media/external work or an unlisted path."}
)
$leaf.recovery = [ordered]@{checkpoint_path=$null; resume_requirements=@("Revalidate r18, CHG-2026-0025, discovery, repository commit and CCS-02-006 acceptance.", "Confirm create paths remain absent and the sole modify path matches the ACTIVE baseline."); rollback=@()}
$leaf.evidence = @(
    [ordered]@{evidence_id="EV-CCS-02-007-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-007_EFFECTIVE_VALUE_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false},
    [ordered]@{evidence_id="EV-CCS-02-007-CHANGE"; kind="FILE"; required=$true; path="12_CHANGE_CONTROL/CHG-2026-0025_CCS_02_007_EFFECTIVE_VALUE_RESOLVER.md"; expected_sha256=$changeHash; sensitivity="INTERNAL"; redaction_required=$false}
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r18"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-007"
$registry.context.next_recommendation.candidate_slice_id = "IMP-022"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CHG-2026-0025 closes the exact CCS-02-007 pure resolver boundary; a separate ACTIVE local work packet remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-007_EFFECTIVE_VALUE_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-007 Immutable Effective Value Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r18 preserves r17 and resolves CCS-02-007 only. It retains parent IMP-022 and depends_on=[CCS-02-006].
The exact envelope has 3 create and 1 modify paths. It owns F-078/T-018 under INV-EFFECTIVE-001.
F-009/T-050 remain exclusively CCS-05-owned.

- r17 SHA-256: $r17Hash
- r17 registry digest: $r17Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0025 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED

The resolver is pure and caller-mapped. Precedence is OVERRIDE, AUTO, PROJECT_DEFAULT, SYSTEM_DEFAULT;
absence differs from explicit JSON null; all absence is explicit unresolved; reset removes override only.
No migration, persistence, API/UI, media/provider/network, credential, dependency, deployment, publication
or external operation is authorized. r18 remains DRAFT, NOT_EVALUATED and implementation_authorized=false.
No product code or test is created here.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = Get-Sha256 $reportPath
[IO.Directory]::CreateDirectory($r18Dir) | Out-Null
[IO.File]::WriteAllText($r18Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r18Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r18Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
if ((& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r18Path --profile task-registry).Trim() -ne $digest) { throw "Embedded digest verification failed" }
[pscustomobject]@{r18_path=$r18Path; registry_digest=$digest; report_path=$reportPath; create_paths=$create.Count; modify_paths=$modify.Count; implementation_authorized=$registry.implementation_authorized} | Format-List
