param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR12 = "241a827f8d36ffea43cb297f257ec59c00285ba73dc9533129ffe077373c10e3"
$expectedDiscovery = "e4b719e2e0187410bd6ffc4fea69b47e572532a4332c1b928c4d2c4142a74597"
$expectedSpec = "89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r12Path = Join-Path $revisions "vc01b-local-20260907-r12\task-registry.json"
$r13Dir = Join-Path $revisions "vc01b-local-20260907-r13"
$r13Path = Join-Path $r13Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-01-008_REFRESHED_GATE_DISCOVERY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01-008_GATE_ENVELOPE_RESOLUTION.md"

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw "Hash mismatch: $Path = $actual" }
    return $actual
}

foreach ($target in @($r13Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r13 output: $target" }
}
$r12Hash = Assert-Hash $r12Path $expectedR12
$discoveryHash = Assert-Hash $discoveryPath $expectedDiscovery
$packageHash = Assert-Hash (Join-Path $SpecRoot "PACKAGE_INDEX.json") $expectedSpec
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$catalog = Get-Content (Join-Path $SpecRoot "TEST_CATALOG.json") -Raw | ConvertFrom-Json
$features = Get-Content (Join-Path $SpecRoot "FEATURE_REGISTRY.json") -Raw | ConvertFrom-Json
$invariants = Get-Content (Join-Path $SpecRoot "INVARIANT_REGISTRY.json") -Raw | ConvertFrom-Json
$slices = Get-Content (Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json") -Raw | ConvertFrom-Json
foreach ($id in @("F-001", "F-002")) { if (@($features.features | Where-Object feature_id -eq $id).Count -ne 1) { throw "Missing feature: $id" } }
foreach ($id in @("INV-AUD-001", "INV-AUTH-001", "INV-AUTH-002")) { if (@($invariants.invariants | Where-Object invariant_id -eq $id).Count -ne 1) { throw "Missing invariant: $id" } }
$mustPass = @("T-001", "T-002", "T-003", "T-004", "T-ENV-001", "T-ENV-002", "T-ENV-003", "T-ENV-004", "T-INT-092", "T-INT-093", "T-INT-137", "T-INT-138")
foreach ($id in $mustPass) { if (@($catalog.tests | Where-Object test_id -eq $id).Count -ne 1) { throw "Missing test: $id" } }
if (@($slices.slices | Where-Object slice_id -eq "IMP-013").Count -ne 1) { throw "Missing IMP-013" }

$registry = Get-Content $r12Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r12" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r12 source" }
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-01-008")
if ($leaf.Count -ne 1 -or $leaf[0].parent_work_package_id -ne "IMP-013" -or (@($leaf[0].depends_on) -join ",") -ne "CCS-01-010" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-01-008 baseline" }
$leaf = $leaf[0]

$futureOutputs = @(
    ".codex/ccs/local_work_packets/CCS-01-008-attempt-001.md",
    ".codex/ccs/local_decisions/LD00-CCS-01-008-attempt-001.md",
    "tests/gates/test_ccs01_gate.py",
    "reports/IMP-013_CCS-01-008_GATE_EVIDENCE.md"
)
foreach ($path in $futureOutputs) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Future create path already exists: $path" } }

$evidenceMap = [ordered]@{
    "reports/CCS-01-008_REFRESHED_GATE_DISCOVERY.md" = $expectedDiscovery
    "reports/IMP-010_CCS-01-001_IMPLEMENTATION.md" = "b00aa9108665e015db207085574590c7efee0883921039ade8a811ef6f7df79c"
    "reports/IMP-010_CCS-01-002_IMPLEMENTATION.md" = "02ea856599b1f730bfbd802591eb51161f4c66b8e1aa85eaf3e54a1326d638ed"
    "reports/IMP-010_CCS-01-003_IMPLEMENTATION.md" = "d6d317ea14a1e6e366ef187f95528d55ea5ab7cbe034cf35c17477fbfda224a9"
    "reports/IMP-010_CCS-01-011_IMPLEMENTATION.md" = "ccfbcdb44ff99027a12dbb8c95549635cbd3dd3dc61bb29c195e251ef8097030"
    "reports/IMP-010_CCS-01-004_IMPLEMENTATION.md" = "f15d909d71e44e8fee2efbb0fc894e0a48e2ef540b139ce03d59eac76a3e99e2"
    "reports/IMP-011_CCS-01-005_IMPLEMENTATION.md" = "51a0bbc99f67f4668165a1202616b5c17878b3d4f3fa3dcb2210a59bfc303843"
    "reports/IMP-012_CCS-01-006_IMPLEMENTATION.md" = "454866fe515a7e29a10caf795d7ad039a83845a1157859adfe6187d2736d720c"
    "reports/IMP-013_CCS-01-007_IMPLEMENTATION.md" = "ae8c3755f5c77adb1d33c3bc8f6a14fee62673503d4a4f8bd7e2312884379381"
    "reports/CCS-01-009_EVIDENCE_CLOSURE.md" = "81a36d8004746f600cddb7d75d1b91b47384ee6ebdaa8314a968b27a28c0a579"
    "reports/IMP-012_CCS-01-010_IMPLEMENTATION.md" = "744bf9b2d3a50dadac8e74a24bd77099596d4b5a4069175c8670948ab4c13189"
    "reports/ENV-02_03_04_EXECUTION_REPORT.md" = "621923b5aa7565d0a99a3e5f14cd3428fb9ba0d85a6a02ae75ded4ecc106c984"
}
$evidence = @()
$n = 0
foreach ($path in $evidenceMap.Keys) {
    Assert-Hash (Join-Path $repoRoot $path) $evidenceMap[$path] | Out-Null
    $n++
    $evidence += [ordered]@{ evidence_id=("EV-CCS-01-008-{0:D2}" -f $n); kind="FILE"; required=$true; path=$path; expected_sha256=$evidenceMap[$path]; sensitivity="INTERNAL"; redaction_required=$false }
}

$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "orchestration.gates.ccs01_foundation"
$leaf.feature_ids = @("F-001", "F-002")
$leaf.invariant_ids = @("INV-AUD-001", "INV-AUTH-001", "INV-AUTH-002")
$leaf.tests.introduces = @("T-003", "T-004", "T-ENV-004")
$leaf.tests.must_pass = $mustPass
$leaf.tests.regression = @("T-001", "T-002", "T-ENV-001", "T-ENV-002", "T-ENV-003", "T-INT-092", "T-INT-093", "T-INT-137", "T-INT-138")
$leaf.create_paths = $futureOutputs
$leaf.modify_paths = @()
$leaf.allowed_paths = $futureOutputs
$leaf.forbidden_paths = @("**/*.db", "**/*.key", "**/*.pem", "**/*.sqlite", "**/*.sqlite3", ".env", ".env.*", ".runtime/DEV/**", ".runtime/STAGING/**", "config/**", "credentials/**", "data/**", "db/**", "migrations/**", "requirements.lock", "src/**")
$leaf.commands = @()
$leaf.interfaces = @()
$leaf.evidence = $evidence
$leaf.in_scope = @(
    "Define one future local-only CCS-01 foundation gate attempt and its exact four output paths.",
    "Produce fresh T-003 binary identity evidence instead of trusting untracked VC-02 observations.",
    "Introduce T-003, T-004 and T-ENV-004 and regress the nine prerequisite-owned tests.",
    "Keep T-ENV-005 and full T-ENV-006 deferred and explicitly NOT CLAIMED."
)
$leaf.out_of_scope = @(
    "Product source configuration dependency lockfile migration and existing-test changes",
    "DEV STAGING runtime or production database access",
    "Credentials secret stores provider accounts network listeners media processing and external effects",
    "Repairing prerequisite defects within the gate attempt",
    "T-ENV-005 and full T-ENV-006 completion",
    "Any path not listed in allowed_paths"
)
$leaf.authorization_requirements = @(
    "A separate ACTIVE attempt must bind exact r13 and repository commit before any gate output is created.",
    "The attempt must record a pre-existing dirty-state manifest and fresh hash-bound T-003 toolchain identity.",
    "Only synthetic inputs, pytest tmp_path and the exact four output paths are permitted."
)
$leaf.error_contracts = @("EVIDENCE_MISSING", "PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE")
$leaf.transaction_requirements = @(
    "Gate tests may write only to pytest tmp_path or a separately authorized ignored TEST root.",
    "No product or runtime database transaction and no external side effect is authorized.",
    "A failed prerequisite is reported to its owning leaf and is not repaired in this gate."
)
$leaf.stop_conditions = @(
    [ordered]@{code="SPEC_DIGEST_MISMATCH"; condition="The r13 specification package binding differs."},
    [ordered]@{code="EVIDENCE_MISSING"; condition="A bound prerequisite report is absent, or its digest or repository baseline differs."},
    [ordered]@{code="PREREQUISITE_NOT_ACCEPTED"; condition="A required local prerequisite test or explicit CCS-01-004 revalidation fails."},
    [ordered]@{code="TASK_ENVELOPE_INCOMPLETE"; condition="The ACTIVE packet omits exact paths, tests, evidence, dirty-state baseline or authority."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Work requires an unlisted write, runtime database, credential, provider, network, media, deployment or publication effect."}
)
$leaf.recovery = [ordered]@{checkpoint_path=$null; resume_requirements=@("Revalidate r13, repository commit, prerequisite hashes and pre-existing dirty state.", "Confirm the exact four future outputs remain absent before authorization."); rollback=@()}
$leaf.gate_receipts = @([ordered]@{gate_id="VC-02"; receipt_digest=$null; receipt_id=$null; status="MISSING"})

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") { throw "Cannot resolve HEAD" }
$registry.registry_id = "vc01b-local-20260907-r13"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-008"
$registry.context.next_recommendation.candidate_slice_id = "IMP-013"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CCS-01-008 ownership, tests, evidence and four-path local gate envelope are resolved; separate ACTIVE attempt authorization remains required."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-008_GATE_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$discovery = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-01-008 Immutable Gate Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / GATE NOT AUTHORIZED
Date: 2026-09-08

## Outcome

r13 preserves r12 byte-for-byte and resolves only the CCS-01-008 local foundation gate envelope.
The corrected order remains CCS-01-007 -> CCS-01-009 -> CCS-01-010 -> CCS-01-008, with parent
IMP-013 and predecessor CCS-01-010. The registry remains DRAFT, NOT_EVALUATED and
implementation_authorized=false.

## Immutable bindings

- r12 file SHA-256: $r12Hash
- r12 registry digest: 708573fd62546a5eb284e7a9aba5c6112d086fabf8f5ab85be85a167dfe52184
- refreshed discovery SHA-256: $discoveryHash
- specification package digest: $packageHash
- repository commit at generation: $currentCommit

## Resolved ownership

- Owner: orchestration.gates.ccs01_foundation
- Features consumed: F-001, F-002
- Invariants regressed: INV-AUD-001, INV-AUTH-001, INV-AUTH-002
- Introduces: T-003, T-004, T-ENV-004
- Must pass: $($mustPass -join ", ")
- Regression evidence: T-001, T-002, T-ENV-001, T-ENV-002, T-ENV-003, T-INT-092, T-INT-093, T-INT-137, T-INT-138
- T-ENV-005 and full T-ENV-006 remain downstream and NOT CLAIMED.

## Exact future outputs

1. .codex/ccs/local_work_packets/CCS-01-008-attempt-001.md
2. .codex/ccs/local_decisions/LD00-CCS-01-008-attempt-001.md
3. tests/gates/test_ccs01_gate.py
4. reports/IMP-013_CCS-01-008_GATE_EVIDENCE.md

There are no modify paths. This r13 generation created none of the four future outputs. It did not
run gate code, FFmpeg/FFprobe, product tests, media processing, credentials, providers, network,
runtime databases, deployment or publication. The missing VC-02 receipt is not promoted; a later
ACTIVE attempt must produce fresh local T-003 identity evidence.

## Registry state

- Tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $discovery DISCOVERY_REQUIRED
- Decision: NOT_EVALUATED
- Implementation authority: false
- Next action: separately authorize an ACTIVE CCS-01-008 attempt bound to exact r13 and commit.

## Reproduction

Run .codex/ccs/tools/New-R13CCS01008GateEnvelope.ps1. The generator validates r12 and discovery
hashes, strict specification sync, test/feature/invariant ownership, prerequisite evidence and the
absence of all four future outputs, then refuses overwrite.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.Directory]::CreateDirectory($r13Dir) | Out-Null
[IO.File]::WriteAllText($r13Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r13Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r13Path, ($registry | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$verified = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r13Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $verified -ne $digest) { throw "Embedded digest verification failed: $verified" }
if ((Get-FileHash $r12Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedR12) { throw "r12 changed" }

[pscustomobject]@{
    r12_sha256 = $r12Hash
    r13_path = $r13Path
    r13_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    exact_future_outputs = $futureOutputs.Count
    resolved = $resolved
    discovery_required = $discovery
    implementation_authorized = $registry.implementation_authorized
} | Format-List
