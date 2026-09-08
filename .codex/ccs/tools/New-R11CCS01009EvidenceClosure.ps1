param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR10Sha256 = "d4e3e20f3ea00d24748b9ba8738eb23bee354f71ef592df1625847e83dbe30be"
$expectedDiscoverySha256 = "61524aaca77abe3d485169e3309f90b837b5cbcee15fcf90649000a1cbe05e3f"
$expectedImplementationCommit = "c2b03c6e90ef51d3d1fa9d22cd1a90a1664865ad"
$expectedHashes = [ordered]@{
    "IMPLEMENTATION_REGISTRY.json" = "143a41bab166f50adeb888d6eee74de81aa18ba54559f6e0601a23c77f354d83"
    "FEATURE_REGISTRY.json" = "7951745edd3cb77d9dce94560fbd3dc16727356effd02b1685e8a5e922accbb7"
    "INVARIANT_REGISTRY.json" = "45e944a07ff5aa0ad1bf2e61007414201eb17dff76eb84dc4dce2a16d8ccf0ac"
    "TEST_CATALOG.json" = "ddf6d2960b546f7643011953e03f1917fa87a434b0872b50cfd7e60b0d1fedd9"
    "09_SHARED_SPEC\AUTH_SESSION_CONTRACT.md" = "4585bedfb91c34745cf26241684a15fa17c0b69fbcf8414bdbcdb8101282a1dc"
}
$artifactHashes = [ordered]@{
    "reports/IMP-012_CCS-01-006_IMPLEMENTATION.md" = "454866fe515a7e29a10caf795d7ad039a83845a1157859adfe6187d2736d720c"
    "src/custom_content_studio/application/services/sessions.py" = "11e452d052eaeafed085e0f0ebc82c3c161f8207ca1fc488b099a4fb4ca4f601"
    "src/custom_content_studio/domain/security/models.py" = "724f422d0e0448c43f506b5321fc96908a520e647ef288b069beb3dfe41de59a"
    "src/custom_content_studio/application/ports/session_repository.py" = "0cae1be5c7bb57103dc7dbbf9500c5340d43a58fe403b09d4feb1c665e93e354"
    "src/custom_content_studio/infrastructure/sqlite/repositories/sessions.py" = "943ebbe32fb9aa6206f5a1c6a2e8d186009c5ca85a9d374e8000ef7ef6a3bb7c"
    "migrations/0001_initial_v2_2.sql" = "2b532c6fbe5b45241f2cd815b6de4947d0a056b32754165fd06c1e9c12a2980f"
}
$artifactHashes["tests/repository/test_session_repository.py"] = "ec92df483f8cbc47b30de7684721ebab567730993889cf0308448ad2ba7a947b"
$artifactHashes["tests/integration/test_session_service.py"] = "2cd27a63be167b26ec9e77e217e10ab17a35e65a26feda9bbbace0278efa3e72"

$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r10Path = Join-Path $revisionRoot "vc01b-local-20260907-r10\task-registry.json"
$r11Dir = Join-Path $revisionRoot "vc01b-local-20260907-r11"
$r11Path = Join-Path $r11Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-01-009_DISCOVERY_WORK_PACKET.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01-009_EVIDENCE_CLOSURE.md"

function Assert-Sha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required evidence: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) {
        throw "Unexpected SHA-256 for $Path`: $actual"
    }
    return $actual
}

foreach ($target in @($r11Dir, $reportPath)) {
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite immutable r11 output: $target"
    }
}

$r10Sha256 = Assert-Sha256 $r10Path $expectedR10Sha256
$discoverySha256 = Assert-Sha256 $discoveryPath $expectedDiscoverySha256
foreach ($relativePath in $expectedHashes.Keys) {
    Assert-Sha256 (Join-Path $SpecRoot $relativePath) $expectedHashes[$relativePath] | Out-Null
}
foreach ($relativePath in $artifactHashes.Keys) {
    Assert-Sha256 (Join-Path $repoRoot $relativePath) $artifactHashes[$relativePath] | Out-Null
}
$resolvedImplementationCommit = (& git -C $repoRoot rev-parse $expectedImplementationCommit).Trim()
if ($LASTEXITCODE -ne 0 -or $resolvedImplementationCommit -ne $expectedImplementationCommit) {
    throw "Cannot resolve exact CCS-01-006 implementation commit"
}

$featureRegistry = Get-Content -LiteralPath (Join-Path $SpecRoot "FEATURE_REGISTRY.json") -Raw | ConvertFrom-Json
$feature = @($featureRegistry.features | Where-Object { $_.feature_id -eq "F-059" })
if ($feature.Count -ne 1 -or $feature[0].name -ne "Hash-only app sessions and one-way revocation" -or
    @($feature[0].tests).Count -ne 1 -or $feature[0].tests[0] -ne "T-INT-137") {
    throw "Normative F-059 binding changed"
}
$invariantRegistry = Get-Content -LiteralPath (Join-Path $SpecRoot "INVARIANT_REGISTRY.json") -Raw | ConvertFrom-Json
$invariant = @($invariantRegistry.invariants | Where-Object { $_.invariant_id -eq "INV-AUTH-001" })
if ($invariant.Count -ne 1 -or @($invariant[0].tests).Count -ne 1 -or
    $invariant[0].tests[0] -ne "T-INT-137") {
    throw "Normative INV-AUTH-001 binding changed"
}
$testCatalog = Get-Content -LiteralPath (Join-Path $SpecRoot "TEST_CATALOG.json") -Raw | ConvertFrom-Json
$test = @($testCatalog.tests | Where-Object { $_.test_id -eq "T-INT-137" })
if ($test.Count -ne 1 -or $test[0].name -ne "Session token identity immutable and revocation one-way") {
    throw "Normative T-INT-137 binding changed"
}

$registry = Get-Content -LiteralPath $r10Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r10" -or
    $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized -ne $false) {
    throw "r10 must remain the expected DRAFT unauthorized source"
}
$leaves = @($registry.tasks | Where-Object { $_.leaf_task_id -eq "CCS-01-009" })
if ($leaves.Count -ne 1) {
    throw "Expected exactly one CCS-01-009 leaf"
}
$leaf = $leaves[0]
if ($leaf.parent_work_package_id -ne "IMP-012" -or @($leaf.depends_on).Count -ne 1 -or
    $leaf.depends_on[0] -ne "CCS-01-007" -or $leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") {
    throw "Unexpected CCS-01-009 r10 baseline"
}
if (@($leaf.allowed_paths).Count -ne 0 -or @($leaf.create_paths).Count -ne 0 -or
    @($leaf.modify_paths).Count -ne 0 -or @($leaf.forbidden_paths).Count -ne 1 -or
    $leaf.forbidden_paths[0] -ne "**") {
    throw "CCS-01-009 r10 baseline must be deny-all"
}

$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "orchestration.evidence"
$leaf.feature_ids = @("F-059")
$leaf.invariant_ids = @("INV-AUTH-001")
$leaf.tests.introduces = @("T-INT-137")
$leaf.tests.must_pass = @("T-INT-137")
$leaf.tests.regression = @()
$leaf.allowed_paths = @()
$leaf.create_paths = @()
$leaf.modify_paths = @()
$leaf.forbidden_paths = @("**")
$leaf.commands = @()
$leaf.interfaces = @()
$leaf.migration_policy = "FORBIDDEN"
$leaf.in_scope = @(
    "Canonical evidence ownership for F-059, INV-AUTH-001 and T-INT-137.",
    "Historical implementation provenance at commit c2b03c6e90ef51d3d1fa9d22cd1a90a1664865ad and the exact bound artifact hashes.",
    "Zero-write closure of CCS-01-009 as already satisfied by completed CCS-01-006 session security evidence."
)
$leaf.out_of_scope = @(
    "Any duplicate source, migration or test implementation",
    "CCS-01-010 ServiceAccount credential reference and rotation audit",
    "Transport authentication, external identity providers, credentials, runtime databases, deployment and publication"
)
$leaf.authorization_requirements = @(
    "No implementation packet is permitted for this evidence-only leaf.",
    "Closure requires immutable hashes and single traceability ownership to remain valid."
)
$leaf.error_contracts = @("EVIDENCE_STALE", "TASK_ENVELOPE_INCOMPLETE", "REDUNDANT_IMPLEMENTATION_ATTEMPT")
$leaf.transaction_requirements = @("No transaction, product mutation or external effect is authorized.")
$leaf.stop_conditions = @(
    [ordered]@{code="EVIDENCE_MISSING"; condition="Any bound implementation, test or normative evidence hash changes."},
    [ordered]@{code="SCOPE_DEVIATION"; condition="Any product source, migration or test change is proposed for CCS-01-009."}
)
$leaf.recovery = [ordered]@{
    checkpoint_path = $null
    resume_requirements = @("Revalidate r10, discovery and historical implementation hashes before closure review.")
    rollback = @()
}
$leaf.evidence = @(
    [ordered]@{evidence_id="EV-CCS-01-009-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-01-009_DISCOVERY_WORK_PACKET.md"; expected_sha256=$discoverySha256; sensitivity="INTERNAL"; redaction_required=$false},
    [ordered]@{evidence_id="EV-CCS-01-009-IMPLEMENTATION"; kind="FILE"; required=$true; path="reports/IMP-012_CCS-01-006_IMPLEMENTATION.md"; expected_sha256=$artifactHashes["reports/IMP-012_CCS-01-006_IMPLEMENTATION.md"]; sensitivity="INTERNAL"; redaction_required=$false},
    [ordered]@{evidence_id="EV-CCS-01-009-REPOSITORY-TEST"; kind="TEST_REPORT"; required=$true; path="tests/repository/test_session_repository.py"; expected_sha256=$artifactHashes["tests/repository/test_session_repository.py"]; sensitivity="INTERNAL"; redaction_required=$false},
    [ordered]@{evidence_id="EV-CCS-01-009-INTEGRATION-TEST"; kind="TEST_REPORT"; required=$true; path="tests/integration/test_session_service.py"; expected_sha256=$artifactHashes["tests/integration/test_session_service.py"]; sensitivity="INTERNAL"; redaction_required=$false}
)

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Cannot resolve current repository commit"
}
$registry.registry_id = "vc01b-local-20260907-r11"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-010"
$registry.context.next_recommendation.candidate_slice_id = "IMP-012"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CCS-01-009 is closed by immutable CCS-01-006 evidence; discover exact CCS-01-010 ServiceAccount credential-rotation boundaries before implementation."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-009_EVIDENCE_CLOSURE.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolvedCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "RESOLVED" }).Count
$discoveryCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "DISCOVERY_REQUIRED" }).Count
$report = @"
# CCS-01-009 Immutable Evidence Closure

Status: ``DRAFT / EVIDENCE BOUND / IMPLEMENTATION NOT AUTHORIZED``
Date: 2026-09-08

## Outcome

Immutable successor r11 re-scopes ``CCS-01-009`` as a zero-write evidence-closure leaf. The
canonical requirement owns ``F-059``, ``INV-AUTH-001`` and ``T-INT-137`` exactly once, while the
actual implementation event remains attributable to completed ``CCS-01-006`` commit
``$expectedImplementationCommit``.

No source, migration or test is duplicated. The leaf remains non-executable and r11 remains
``DRAFT / NOT_EVALUATED`` with ``implementation_authorized=false``.

## Immutable sources

| Evidence | SHA-256 |
|---|---|
| r10 registry | ``$r10Sha256`` |
| CCS-01-009 discovery packet | ``$discoverySha256`` |
| CCS-01-006 implementation report | ``$($artifactHashes["reports/IMP-012_CCS-01-006_IMPLEMENTATION.md"])`` |
| repository session test | ``$($artifactHashes["tests/repository/test_session_repository.py"])`` |
| integration session test | ``$($artifactHashes["tests/integration/test_session_service.py"])`` |
| implementation commit | ``$resolvedImplementationCommit`` |
| repository commit at generation | ``$currentCommit`` |

## Exact r11 binding

- parent/dependency: ``IMP-012`` / ``CCS-01-007``;
- feature/invariant/test: ``F-059`` / ``INV-AUTH-001`` / ``T-INT-137``;
- test role: ``T-INT-137`` is both introduced and required by ``CCS-01-009``;
- implementation provenance: exact CCS-01-006 artifacts and commit;
- path resolution: ``RESOLVED`` as an exact empty product-write set;
- allowed/create/modify paths and commands: empty;
- forbidden paths: ``**``;
- directly executable: false;
- external effects and migrations: forbidden.

The registry now contains $($registry.tasks.Count) tasks: $resolvedCount ``RESOLVED`` and
$discoveryCount ``DISCOVERY_REQUIRED``.

## Preserved boundaries

- r10 remains byte-identical and digest-bound.
- CCS-01-006 remains the historical implementation provenance but does not duplicate canonical
  ownership of ``F-059``, ``INV-AUTH-001`` or ``T-INT-137``.
- CCS-01-010 remains the sole next owner of ServiceAccount credential-reference rotation audit.
- No code, test, schema, migration, credential, runtime database, provider, deployment or
  publication action is changed or authorized.
- r11 cannot authorize an implementation attempt or the CCS-01 gate.

## Next controlled action

Discover ``CCS-01-010`` under ``IMP-012`` and bind exact ServiceAccount credential-reference,
ADMIN authorization, rotation metadata and audit boundaries. Do not treat app-session evidence
as ServiceAccount credential evidence.

## Reproduction

Run ``.codex/ccs/tools/New-R11CCS01009EvidenceClosure.ps1``. The generator checks all normative,
discovery and historical implementation hashes, refuses overwrite, and rechecks r10 immutability.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd([char[]]"`r`n") + "`n", [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()

[IO.Directory]::CreateDirectory($r11Dir) | Out-Null
[IO.File]::WriteAllText($r11Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r11Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") {
    throw "Bad registry digest output: $digest"
}
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r11Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))

$r10Sha256After = (Get-FileHash -LiteralPath $r10Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r10Sha256After -ne $expectedR10Sha256) {
    throw "Immutable r10 changed during r11 generation"
}

[pscustomobject]@{
    source_r10_sha256 = $r10Sha256
    discovery_sha256 = $discoverySha256
    implementation_commit = $resolvedImplementationCommit
    r11_path = $r11Path
    r11_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    resolved = $resolvedCount
    discovery_required = $discoveryCount
    implementation_authorized = $registry.implementation_authorized
} | Format-List
