param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r18Path = Join-Path $revisions "vc01b-local-20260907-r18\task-registry.json"
$r19Dir = Join-Path $revisions "vc01b-local-20260907-r19"
$r19Path = Join-Path $r19Dir "task-registry.json"
$reportPath = Join-Path $repoRoot "reports\CCS-02-008_NORMALIZED_RECT_ENVELOPE_RESOLUTION.md"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-008_NORMALIZED_RECT_DISCOVERY.md"
$changeRelative = "12_CHANGE_CONTROL/CHG-2026-0026_CCS_02_008_NORMALIZED_RECT.md"
$changePath = Join-Path $SpecRoot $changeRelative

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-Utf8([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string]$Path, $Value) { Write-Utf8 $Path (($Value | ConvertTo-Json -Depth 100)) }

foreach ($target in @($r19Dir, $reportPath, $changePath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r19 output: $target" }
}

$r18Hash = Get-Sha256 $r18Path
$discoveryHash = Get-Sha256 $discoveryPath
$registry = Get-Content -Raw $r18Path | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r18" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r18 source" }
$r18Digest = $registry.registry_digest
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-008")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-007" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-008 baseline" }

# Narrow normative traceability change: it introduces ownership only; no schema shape is changed.
$change = @"
# CHG-2026-0026 — CCS-02-008 NormalizedRect domain boundary

Status: ACCEPTED / NORMATIVE / PRODUCT IMPLEMENTATION PENDING
Date: 2026-09-09
Scope: CCS-02-008 under IMP-022
Introduced feature/test/invariant: F-079 / T-019 / INV-GEOMETRY-001

## Contract

CCS-02-008 owns a pure immutable `NormalizedRect` domain value. It has exactly four numeric fields:
`x`, `y`, `width`, and `height`. `x` and `y` are inclusive normalized coordinates in `[0, 1]`.
`width` and `height` are positive normalized sizes in `(0, 1]`. Booleans, non-real values, NaN and
infinities are rejected with the stable domain validation error contract.

This contract deliberately has no containment rule. In particular, `x + width <= 1` and
`y + height <= 1` are not imposed here. Clipping, crop, rotation, anchor, aspect ratio, safe area,
pixel conversion, render-plan mutation and editor policy are caller concerns. The object aligns to
`13_IMPLEMENTATION_CONTRACTS/schemas/render-plan.v1.schema.json#/$defs/NormalizedRect` without
modifying that schema.

## Ownership and exclusions

F-079, T-019 and INV-GEOMETRY-001 are CCS-02 ownership. F-009 Design override/reset and T-051
remain exclusively CCS-05 integration ownership. This change transfers neither feature nor test
ownership from CCS-05.

The successor implementation allowlist has exactly four paths: create the domain object, create
its unit test, create its implementation report, and modify the domain export. It authorizes no
migration, persistence, API/UI, external/provider/media/network action, dependency change,
deployment or publication.
"@
Write-Utf8 $changePath $change

$featurePath = Join-Path $SpecRoot "FEATURE_REGISTRY.json"
$invariantPath = Join-Path $SpecRoot "INVARIANT_REGISTRY.json"
$testPath = Join-Path $SpecRoot "TEST_CATALOG.json"
$implementationPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$tracePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md"
$decisionsPath = Join-Path $SpecRoot "12_CHANGE_CONTROL\DECISIONS.md"
$changelogPath = Join-Path $SpecRoot "12_CHANGE_CONTROL\CHANGELOG.md"
$foundationPath = Join-Path $SpecRoot "01_FOUNDATION\CCS-02_PROJECT_CONTENT_ASSET.md"

$features = Get-Content -Raw $featurePath | ConvertFrom-Json
if (@($features.features | Where-Object feature_id -eq "F-079").Count) { throw "F-079 already exists" }
$features.features += [pscustomobject]@{feature_id="F-079";phase="CCS-02";name="NormalizedRect domain value";specs=@($changeRelative,"13_IMPLEMENTATION_CONTRACTS/schemas/render-plan.v1.schema.json");tests=@("T-019");code_paths=@();status="PLANNED"}
Write-Json $featurePath $features

$invariants = Get-Content -Raw $invariantPath | ConvertFrom-Json
if (@($invariants.invariants | Where-Object invariant_id -eq "INV-GEOMETRY-001").Count) { throw "INV-GEOMETRY-001 already exists" }
$invariants.invariants += [pscustomobject]@{invariant_id="INV-GEOMETRY-001";name="normalized rectangles accept only schema-representable coordinates and positive sizes";enforcement=@("DOMAIN_VALUE_OBJECT");tests=@("T-019")}
Write-Json $invariantPath $invariants

$tests = Get-Content -Raw $testPath | ConvertFrom-Json
if (@($tests.tests | Where-Object test_id -eq "T-019").Count) { throw "T-019 already exists" }
$tests.tests += [pscustomobject]@{test_id="T-019";name="NormalizedRect endpoint non-finite and immutability validation";phase="CCS-02"}
Write-Json $testPath $tests

$implementation = Get-Content -Raw $implementationPath | ConvertFrom-Json
$slice = @($implementation.slices | Where-Object slice_id -eq "IMP-022")
if ($slice.Count -ne 1) { throw "IMP-022 missing" }
if (@($slice[0].feature_ids) -contains "F-079") { throw "IMP-022 already owns F-079" }
$slice[0].feature_ids = @($slice[0].feature_ids + "F-079")
Write-Json $implementationPath $implementation

$trace = Get-Content -Raw $tracePath
$traceRow = "| F-079 | CCS-02 | NormalizedRect domain value | $changeRelative, 13_IMPLEMENTATION_CONTRACTS/schemas/render-plan.v1.schema.json | T-019 | `(planned)` | PLANNED |"
Write-Utf8 $tracePath ($trace -replace "(\| F-078 \|[^\r\n]*\r?\n)", "`$1$traceRow`r`n")

$decision = @"

## ADR-0048 — Shared normalized rectangle is schema-aligned, not containment policy
- Date: 2026-09-09
- Status: ACCEPTED IMPLEMENTATION CONTRACT; PRODUCT IMPLEMENTATION PENDING
- Decision: CCS-02-008 owns an immutable normalized rectangle with x/y in [0,1] and width/height
  in (0,1]. It does not require a rectangle to be contained within the unit square.
- Consequence: later CCS-05/editor and CCS-06/render callers choose clipping/crop/anchor policy;
  F-009/T-051 remain exclusively CCS-05-owned. No persistence or schema mutation is introduced.
"@
Write-Utf8 $decisionsPath ((Get-Content -Raw $decisionsPath) + $decision)

$changeLog = @"

## CHG-2026-0026 — CCS-02 NormalizedRect value boundary
- Date: 2026-09-09
- F-079 / T-019 / INV-GEOMETRY-001 added under IMP-022.
- x/y are inclusive [0,1]; width/height are (0,1]; containment is intentionally excluded.
- F-009/T-051 remain CCS-05-owned. No schema, migration, external action or product code changed.
"@
Write-Utf8 $changelogPath ($changeLog + (Get-Content -Raw $changelogPath))

$foundation = Get-Content -Raw $foundationPath
$foundation = $foundation -replace "### NormalizedRect\r?\nx/y/width/height between 0 and 1\.", "### NormalizedRect`r`nF-079 owns the immutable shared value: x/y are inclusive [0,1]; width/height are (0,1].`r`nContainment, crop, clipping, anchor and pixel policy are excluded."
Write-Utf8 $foundationPath $foundation

& $Python -I -B (Join-Path $SpecRoot "tools\update_package_index.py")
if ($LASTEXITCODE -ne 0) { throw "Package index refresh failed" }
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$changeHash = Get-Sha256 $changePath
$packageHash = Get-Sha256 (Join-Path $SpecRoot "PACKAGE_INDEX.json")
$create = @("reports/IMP-022_CCS-02-008_IMPLEMENTATION.md", "src/custom_content_studio/domain/normalized_rect.py", "tests/unit/test_normalized_rect.py")
$modify = @("src/custom_content_studio/domain/__init__.py")
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create path exists: $path" } }
foreach ($path in $modify) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify path missing: $path" } }

$leaf = $leaf[0]
$leaf.parent_work_package_id = "IMP-022"
$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "custom_content_studio.domain.normalized_rect"
$leaf.feature_ids = @("F-079")
$leaf.invariant_ids = @("INV-GEOMETRY-001")
$leaf.tests.introduces = @("T-019")
$leaf.tests.must_pass = @("T-019")
$leaf.tests.regression = @()
$leaf.create_paths = $create
$leaf.modify_paths = $modify
$leaf.allowed_paths = @($create + $modify | Sort-Object -Unique)
$leaf.forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/custom_content_studio/api/**", "src/custom_content_studio/ui/**", "src/custom_content_studio/application/**", "src/custom_content_studio/infrastructure/**", "tests/gates/**")
$leaf.interfaces = @([ordered]@{kind="DOMAIN_VALUE_OBJECT";name="NormalizedRect";contract_root="SPEC_ROOT";contract_path=$changeRelative;direction="IN_PROCESS"})
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @("Implement only the immutable, dependency-free NormalizedRect value object and its exact unit tests.", "Validate x/y inclusive [0,1] and width/height (0,1]; reject bool/non-real/NaN/infinity.", "Do not impose unit-square containment; F-009/T-051 remain CCS-05-owned.")
$leaf.out_of_scope = @("Containment clipping crop rotation anchor aspect pixel safe-area or render policy", "F-009/T-051 CCS-05 ownership", "Migration persistence API UI repositories application services bootstrap network provider media credentials dependencies deployment publication", "Any path not listed in allowed_paths")
$leaf.authorization_requirements = @("A separate ACTIVE local work packet must bind exact r19 and repository commit before mutation.", "Only pure synthetic unit tests are permitted.", "No migration, external operation or CCS-05 ownership transfer is authorized.")
$leaf.error_contracts = @("DOMAIN_VALIDATION_FAILED", "MIGRATION_DECISION_REQUIRED", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE")
$leaf.transaction_requirements = @("The value object is pure and performs no transaction, persistence mutation, external effect or caller-input mutation.")
$leaf.stop_conditions = @([ordered]@{code="SPEC_DIGEST_MISMATCH";condition="The r19 change-control, discovery or package binding differs."}, [ordered]@{code="PREREQUISITE_NOT_ACCEPTED";condition="CCS-02-007 acceptance is absent."}, [ordered]@{code="MIGRATION_DECISION_REQUIRED";condition="Implementation needs database storage, migration, SQL, manifest, trigger or backfill."}, [ordered]@{code="TASK_ENVELOPE_INCOMPLETE";condition="The ACTIVE packet omits exact paths, T-019, F-079, INV-GEOMETRY-001 or authority."}, [ordered]@{code="SCOPE_DEVIATION";condition="Work requires containment policy, F-009/T-051 transfer, persistence/API/UI/media/external work or an unlisted path."})
$leaf.recovery = [ordered]@{checkpoint_path=$null;resume_requirements=@("Revalidate r19, CHG-2026-0026, discovery, repository commit and CCS-02-007 acceptance.", "Confirm create paths remain absent and the sole modify path matches the ACTIVE baseline.");rollback=@()}
$leaf.evidence = @([ordered]@{evidence_id="EV-CCS-02-008-DISCOVERY";kind="FILE";required=$true;path="reports/CCS-02-008_NORMALIZED_RECT_DISCOVERY.md";expected_sha256=$discoveryHash;sensitivity="INTERNAL";redaction_required=$false}, [ordered]@{evidence_id="EV-CCS-02-008-CHANGE";kind="FILE";required=$true;path=$changeRelative;expected_sha256=$changeHash;sensitivity="INTERNAL";redaction_required=$false})

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r19"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-008"
$registry.context.next_recommendation.candidate_slice_id = "IMP-022"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CHG-2026-0026 closes the exact CCS-02-008 pure geometry boundary; a separate ACTIVE local work packet remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-008_NORMALIZED_RECT_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-008 Immutable NormalizedRect Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r19 preserves r18 and resolves CCS-02-008 only. It corrects the parent to IMP-022 and retains
depends_on=[CCS-02-007]. The exact envelope has 3 create and 1 modify path. It owns
F-079/T-019 under INV-GEOMETRY-001; F-009/T-051 remain exclusively CCS-05-owned.

- r18 SHA-256: $r18Hash
- r18 registry digest: $r18Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0026 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED

NormalizedRect accepts x/y inclusive [0,1] and width/height (0,1]. It rejects booleans,
non-real values, NaN and infinities. It deliberately imposes no containment rule. No migration,
persistence, API/UI, media/provider/network, credential, dependency, deployment, publication or
external operation is authorized. r19 remains DRAFT, NOT_EVALUATED and implementation_authorized=false.
No product code or test is created here.
"@
Write-Utf8 $reportPath $report
$registry.readiness.report_sha256 = Get-Sha256 $reportPath
[IO.Directory]::CreateDirectory($r19Dir) | Out-Null
Write-Json $r19Path $registry
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r19Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
Write-Json $r19Path $registry
if ((& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r19Path --profile task-registry).Trim() -ne $digest) { throw "Embedded digest verification failed" }
[pscustomobject]@{r19_path=$r19Path;registry_digest=$digest;report_path=$reportPath;change_path=$changePath;allowlist=@($create+$modify);implementation_authorized=$registry.implementation_authorized} | Format-List
