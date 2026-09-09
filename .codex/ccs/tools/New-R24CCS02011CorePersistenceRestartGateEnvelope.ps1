param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "E:\Custom_Contents_APP\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r23Path = Join-Path $revisions "vc01b-local-20260907-r23\task-registry.json"
$r24Dir = Join-Path $revisions "vc01b-local-20260907-r24"
$r24Path = Join-Path $r24Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-011_CORE_PERSISTENCE_RESTART_GATE_DISCOVERY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-011_CORE_PERSISTENCE_RESTART_GATE_ENVELOPE_RESOLUTION.md"
$changeRelative = "12_CHANGE_CONTROL/CHG-2026-0031_CCS_02_011_CORE_PERSISTENCE_RESTART_GATE.md"
$changePath = Join-Path $SpecRoot $changeRelative

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-Utf8([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string]$Path, $Value) { Write-Utf8 $Path ($Value | ConvertTo-Json -Depth 100) }
function Append-Once([string]$Path, [string]$Marker, [string]$Text) {
    $current = Get-Content -Raw -LiteralPath $Path
    if ($current -notmatch [regex]::Escape($Marker)) { Write-Utf8 $Path ($current.TrimEnd() + "`n`n" + $Text) }
}

foreach ($target in @($r24Dir, $discoveryPath, $reportPath, $changePath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r24 output: $target" }
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python not found: $Python" }

$r23Hash = Get-Sha256 $r23Path
$registry = Get-Content -Raw -LiteralPath $r23Path | ConvertFrom-Json -Depth 100
if ($registry.registry_id -ne "vc01b-local-20260907-r23" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r23 source" }
$r23Digest = $registry.registry_digest
$old = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-011")
if ($old.Count -ne 1 -or $old[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-011 baseline" }

$discovery = @'
# CCS-02-011 Core Persistence Restart Gate Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Parent: CCS-02 under IMP-022
Dependency: CCS-02-010; semantic predecessors CCS-02-003/004/005/006

The smallest closure leaf is one gate test and one implementation report. It must use only a fresh
temporary SQLite database, execute the existing migration path, seed a legal two-Workspace fixture,
commit, construct a new SQLiteConnectionFactory and reopen the database. The gate proves durable
Workspace/Project/Asset/Content/ContentVersion/head/status/row-version state, database FK/unique
constraints, stale CAS rollback with no partial/orphan write, exact Content state edges, version
deletion rejection, and concealed cross-Workspace access.

It cannot amend application, domain, repository, persistence, migration or configuration code. It
does not own pure helper validation, API/UI behavior, provider/network, credentials, runtime
database, dependency, deployment or publication behavior.
'@
Write-Utf8 $discoveryPath $discovery

$change = @'
# CHG-2026-0031 — CCS-02-011 core persistence/restart gate

Status: ACCEPTED / NORMATIVE / PRODUCT IMPLEMENTATION PENDING
Date: 2026-09-09
Scope: CCS-02-011 under IMP-022; dependent on CCS-02-010 and revalidating CCS-02-003/004/005/006
Traceability: F-003, F-004, F-005, F-006 / T-011, T-013, T-014, T-015, T-016, T-017, T-INT-031, T-INT-050 / INV-WS-001, INV-IMM-001

## Gate contract

The leaf creates exactly one gate test and one implementation report. The test creates a fresh
temporary SQLite database, runs the already-present migration path, seeds a legal two-Workspace
fixture, commits, creates a new SQLiteConnectionFactory, and reopens the same database. It proves
that Workspace, Project, Asset, Content, ContentVersion, authoring head, status and row-version
persist across that restart boundary.

The gate must also prove database FK and unique integrity, exact stale-CAS rejection with no partial
or orphan rows, Content state limited to IDEA/ACTIVE/ARCHIVED with only activate, archive and
submit-review edges, blocked ContentVersion deletion, and concealed/denied cross-Workspace access.

## Boundary and verification

Create only `tests/gates/test_ccs02_gate.py` and
`reports/IMP-022_CCS-02-011_IMPLEMENTATION.md`. Existing repository and integration tests are
regression command inputs only and are not edited. No source, schema, migration, configuration or
dependency modification is authorized. No runtime database, API/UI, network/provider, credential,
deployment, publication or external effect is authorized.

This gate owns F-003/F-004/F-005/F-006 and the listed tests/invariants only. F-079/F-080 and
T-019/T-020 remain pure-helper ownership and are excluded.
'@
Write-Utf8 $changePath $change

$featurePath = Join-Path $SpecRoot "FEATURE_REGISTRY.json"
$features = Get-Content -Raw $featurePath | ConvertFrom-Json -Depth 100
foreach ($id in @("F-003", "F-004", "F-005", "F-006")) {
    $feature = @($features.features | Where-Object feature_id -eq $id)
    if ($feature.Count -ne 1) { throw "Missing feature: $id" }
    $feature[0].specs = @($feature[0].specs + $changeRelative | Select-Object -Unique)
}
Write-Json $featurePath $features

$implementationPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$implementation = Get-Content -Raw $implementationPath | ConvertFrom-Json -Depth 100
$slice = @($implementation.slices | Where-Object slice_id -eq "IMP-022")
if ($slice.Count -ne 1) { throw "IMP-022 missing" }
$slice[0].deliverables = @($slice[0].deliverables + "CCS-02 fresh SQLite persistence/restart gate" | Select-Object -Unique)
$slice[0].acceptance_evidence = @($slice[0].acceptance_evidence + "fresh SQLite migration/restart persistence, CAS rollback, immutability and Workspace isolation gate" | Select-Object -Unique)
Write-Json $implementationPath $implementation

$tracePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md"
$trace = Get-Content -Raw $tracePath
foreach ($id in @("F-003", "F-004", "F-005", "F-006")) {
    $line = ($trace -split "`r?`n" | Where-Object { $_ -like "| $id |*" })
    if (@($line).Count -ne 1) { throw "Traceability row missing: $id" }
    if ($line -notmatch [regex]::Escape($changeRelative)) { $trace = $trace.Replace($line, $line.Replace(" | T-", ", $changeRelative | T-")) }
}
Write-Utf8 $tracePath $trace
Append-Once (Join-Path $SpecRoot "12_CHANGE_CONTROL\DECISIONS.md") "ADR-0053" @'
## ADR-0053 — CCS-02 closure gate is restart-bound and read-only to product code
- Date: 2026-09-09
- Status: ACCEPTED IMPLEMENTATION CONTRACT; PRODUCT IMPLEMENTATION PENDING
- Decision: CCS-02-011 proves core persistence only through a fresh temporary SQLite migration and
  a new factory/reopen boundary; stale CAS, immutability and Workspace concealment are gate facts.
- Consequence: no implementation code, migration or runtime database change may be smuggled into a
  verification leaf; a failed gate requires a separately bounded corrective leaf.
'@
Append-Once (Join-Path $SpecRoot "12_CHANGE_CONTROL\CHANGELOG.md") "CHG-2026-0031" @'
## CHG-2026-0031 — CCS-02-011 core persistence/restart gate
- Date: 2026-09-09
- F-003/F-004/F-005/F-006 closure gate under IMP-022.
- Fresh SQLite migration/restart, durable core rows, constraints, CAS rollback, version immutability,
  exact state boundary and Workspace isolation are frozen with no product-code modification.
'@

& $Python -I -B (Join-Path $SpecRoot "tools\update_package_index.py")
if ($LASTEXITCODE -ne 0) { throw "Package index refresh failed" }
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$create = @("reports/IMP-022_CCS-02-011_IMPLEMENTATION.md", "tests/gates/test_ccs02_gate.py")
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create exists: $path" } }
$discoveryHash = Get-Sha256 $discoveryPath
$changeHash = Get-Sha256 $changePath
$packageHash = Get-Sha256 (Join-Path $SpecRoot "PACKAGE_INDEX.json")
$child = [pscustomobject]@{
    allowed_paths = @($create | Sort-Object); authorization_requirements = @("Separate ACTIVE packet binds r24/change/repository commit.", "Fresh temporary SQLite only; existing repository/integration tests are regression inputs and are not edited.", "No product code, migration, runtime DB or external operation."); commands = @(); create_paths = $create; depends_on = @("CCS-02-010"); directly_executable = $false
    error_contracts = @("PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE")
    evidence = @([pscustomobject]@{ evidence_id="EV-CCS-02-011-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-011_CORE_PERSISTENCE_RESTART_GATE_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false }, [pscustomobject]@{ evidence_id="EV-CCS-02-011-CHANGE"; kind="FILE"; required=$true; path=$changeRelative; expected_sha256=$changeHash; sensitivity="INTERNAL"; redaction_required=$false })
    external_side_effect_policy = "FORBIDDEN"; feature_ids = @("F-003", "F-004", "F-005", "F-006"); forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/**", "config/**", "tests/repository/**", "tests/integration/**", "tests/contract/**")
    gate_receipts = @([pscustomobject]@{ gate_id="VC-02"; receipt_digest=$null; receipt_id=$null; status="MISSING" }); implementation_authority_source = "SEPARATE_ACTIVE_AUTHORIZATION_AND_APPROVED_WORK_PACKET"
    in_scope = @("Fresh temporary SQLite migration/restart verification only.", "Durable core rows, FK/unique constraints, stale-CAS no-partial-write, exact state boundary, version deletion rejection and concealed cross-Workspace access.")
    interfaces = @([pscustomobject]@{ kind="SQLITE_RESTART_GATE"; name="ccs02_core_persistence_restart_gate"; contract_root="SPEC_ROOT"; contract_path=$changeRelative; direction="IN_PROCESS" })
    invariant_ids = @("INV-WS-001", "INV-IMM-001"); leaf_definition_digest = $zero; leaf_task_id = "CCS-02-011"; migration_policy = "FORBIDDEN"; modify_paths = @()
    out_of_scope = @("Product source/schema/migration/configuration/dependency edits; runtime DB; API/UI; helpers F-079/F-080; provider/network/credentials/deployment/publication and unlisted paths")
    owner_module = "tests.gates.test_ccs02_gate"; parent_work_package_id = "IMP-022"; path_resolution_status = "RESOLVED"
    recovery = [pscustomobject]@{ checkpoint_path=$null; resume_requirements=@("Revalidate r24/change/discovery/repository and CCS-02-010 acceptance.", "Confirm both creates are absent and a temporary SQLite path is used."); rollback=@() }
    stage = "CCS-02"; status = "PLANNED"
    stop_conditions = @([pscustomobject]@{ code="SPEC_DIGEST_MISMATCH"; condition="r24/change/discovery/package differs." }, [pscustomobject]@{ code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-010 or semantic predecessor acceptance is absent." }, [pscustomobject]@{ code="TASK_ENVELOPE_INCOMPLETE"; condition="Packet lacks exact paths, F/T/INV and SQLite restart interface." }, [pscustomobject]@{ code="SCOPE_DEVIATION"; condition="Any product edit, non-temporary DB, helper/API/UI/external or unlisted work is required." })
    tests = [pscustomobject]@{ introduces=@("T-011", "T-013", "T-014", "T-015", "T-016", "T-017", "T-INT-031", "T-INT-050"); must_pass=@("T-011", "T-013", "T-014", "T-015", "T-016", "T-017", "T-INT-031", "T-INT-050"); regression=@("tests/repository/test_asset_repository.py", "tests/repository/test_content_repository.py", "tests/repository/test_content_version_repository.py", "tests/repository/test_content_state_transition_repository.py", "tests/integration/test_content_state_transition_service.py") }
    transaction_requirements = @("Gate creates and closes only its own temporary SQLite connections; no runtime DB or external transaction.")
}
$registry.tasks = @($registry.tasks | Where-Object leaf_task_id -ne "CCS-02-011") + @($child)
$currentCommit = (& git -c safe.directory=E:/Custom_Contents_APP -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "Repository HEAD unavailable" }
$registry.registry_id = "vc01b-local-20260907-r24"; $registry.registry_status = "DRAFT"; $registry.registry_digest = $zero; $registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit; $registry.context.spec_package_digest = $packageHash; $registry.context.implementation_plan_digest = $zero; $registry.context.leaf_task_id = $null; $registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-011"; $registry.context.next_recommendation.candidate_slice_id = "IMP-022"; $registry.context.next_recommendation.authorized = $false; $registry.context.next_recommendation.requires_new_authorization = $true; $registry.context.next_recommendation.reason = "CHG-2026-0031 freezes a two-create fresh SQLite closure gate; separate ACTIVE packet required."
$registry.readiness.graph_validated = $false; $registry.readiness.owner_path_test_ownership_validated = $false; $registry.readiness.gate_closure_validated = $false; $registry.readiness.final_closure_leaf_id = $null; $registry.readiness.final_closure_complete = $false; $registry.readiness.report_path = "reports/CCS-02-011_CORE_PERSISTENCE_RESTART_GATE_ENVELOPE_RESOLUTION.md"; $registry.readiness.decision = "NOT_EVALUATED"
$report = @"
# CCS-02-011 Immutable Core Persistence/Restart Gate Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
r24 preserves r23 and resolves only CCS-02-011 under IMP-022: F-003/F-004/F-005/F-006;
T-011/T-013/T-014/T-015/T-016/T-017/T-INT-031/T-INT-050; INV-WS-001/INV-IMM-001.
- r23 SHA-256: $r23Hash
- r23 registry digest: $r23Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0031 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit

The exact two-create envelope owns only a fresh temporary SQLite migration/reopen gate and report.
It cannot modify product code or migrations, touch a runtime database, or perform API/UI/external work.
"@
Write-Utf8 $reportPath $report
$registry.readiness.report_sha256 = Get-Sha256 $reportPath
[IO.Directory]::CreateDirectory($r24Dir) | Out-Null
Write-Json $r24Path $registry
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r24Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest; $registry.context.implementation_plan_digest = $digest
Write-Json $r24Path $registry
if ((& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r24Path --profile task-registry).Trim() -ne $digest) { throw "Embedded digest verification failed" }
[pscustomobject]@{ r24_path=$r24Path; registry_digest=$digest; discovery_sha256=$discoveryHash; change_sha256=$changeHash; package_sha256=$packageHash; implementation_authorized=$registry.implementation_authorized; allowlist=@($child.allowed_paths) } | Format-List
