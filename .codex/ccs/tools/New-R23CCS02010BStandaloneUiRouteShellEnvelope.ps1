param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "E:\Custom_Contents_APP\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r22Path = Join-Path $revisions "vc01b-local-20260907-r22\task-registry.json"
$r23Dir = Join-Path $revisions "vc01b-local-20260907-r23"
$r23Path = Join-Path $r23Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-010B_STANDALONE_UI_ROUTE_SHELL_DISCOVERY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-010B_STANDALONE_UI_ROUTE_SHELL_ENVELOPE_RESOLUTION.md"
$changeRelative = "12_CHANGE_CONTROL/CHG-2026-0030_CCS_02_010B_STANDALONE_UI_ROUTE_SHELL.md"
$changePath = Join-Path $SpecRoot $changeRelative

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-Utf8([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string]$Path, $Value) { Write-Utf8 $Path ($Value | ConvertTo-Json -Depth 100) }
function Append-Once([string]$Path, [string]$Marker, [string]$Text) {
    $current = Get-Content -Raw -LiteralPath $Path
    if ($current -notmatch [regex]::Escape($Marker)) { Write-Utf8 $Path ($current.TrimEnd() + "`n`n" + $Text) }
}

foreach ($target in @($r23Dir, $discoveryPath, $reportPath, $changePath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r23 output: $target" }
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python not found: $Python" }

$r22Hash = Get-Sha256 $r22Path
$registry = Get-Content -Raw -LiteralPath $r22Path | ConvertFrom-Json -Depth 100
if ($registry.registry_id -ne "vc01b-local-20260907-r22" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r22 source" }
$r22Digest = $registry.registry_digest
if (@($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-010A").Count -ne 1 -or @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-010B").Count) { throw "Unexpected CCS-02-010B baseline" }

$discovery = @'
# CCS-02-010B Standalone UI Route-shell Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Parent: CCS-02-010 under IMP-021
Predecessor: CCS-02-010A (API read-shell acceptance)

The smallest presentation-only child is one pure, framework-free route-shell module. It declares
only four standalone canonical destinations: Dashboard `/dashboard`; Projects
`/workspaces/{workspace_id}/projects`; Content
`/workspaces/{workspace_id}/projects/{project_id}/contents`; and Assets
`/workspaces/{workspace_id}/assets`. The content route includes both required ancestors; aliases,
resource details, child routes and every other destination remain outside this leaf.

The route-shell exports immutable descriptors and layout rules only. Each descriptor has a unique
page key, canonical template, standalone destination flag, and a shared viewport rule: header,
navigation and current-action context remain outside exactly one bounded internal work area. It must
not render a browser page, use a UI framework, CSS/DOM selector, session/browser state, request,
ActorContext, API client, resolver, repository, service, persistence, cache or aggregate.

No data is loaded, displayed or inferred. Route formatting/validation, identity authorization,
deep-link restoration, page selection, mutation, pagination, filter/sort/search, color/theme,
accessibility rendering, workflow actions and external behavior require later separately bounded
leaves. Smallest future allowlist: route-shell module, UI package export, one pure contract test,
and implementation report.
'@
Write-Utf8 $discoveryPath $discovery

$change = @'
# CHG-2026-0030 - CCS-02-010B standalone UI route-shell contract

Status: ACCEPTED / NORMATIVE / PRODUCT IMPLEMENTATION PENDING
Date: 2026-09-09
Scope: CCS-02-010B under IMP-021; successor of CCS-02-010 and independent presentation sibling of CCS-02-010A
Traceability: F-081 / T-021 / INV-UI-ROUTE-001

## Presentation-only contract

Create one framework-free, immutable route-shell catalog. It declares exactly these standalone
canonical destination templates:

1. Dashboard: `/dashboard`
2. Projects: `/workspaces/{workspace_id}/projects`
3. Content: `/workspaces/{workspace_id}/projects/{project_id}/contents`
4. Assets: `/workspaces/{workspace_id}/assets`

Each descriptor has a unique page key, its exact canonical template and `standalone=true`. The shell
also declares one shared bounded-layout policy: header, navigation and current action context remain
in the viewport; exactly one internal work area may scroll or paginate; browser-document long-form
scrolling is forbidden. The catalog is declarative only and does not format URLs, inspect path
parameters, select a route, load data or render a page.

## Boundary and verification

Create only `src/custom_content_studio/ui/route_shell.py`,
`tests/contract/test_standalone_ui_route_shell.py` and
`reports/IMP-021_CCS-02-010B_IMPLEMENTATION.md`. Modify only
`src/custom_content_studio/ui/__init__.py` to export the declarative catalog. T-021 proves the four
exact templates, unique page keys, standalone flags, and bounded-layout rule without importing UI
frameworks, API modules, request/ActorContext, application, infrastructure, persistence or domain
modules.

No route registration, browser/UI rendering, Streamlit installation or use, CSS/DOM behavior,
session/cache/request state, API client/resolver/repository/service/aggregate access, identity or
authorization check, data/query/list/pagination implementation, mutation, schema, migration,
dependency, network, credential, deployment, publication or external effect is permitted. A later
leaf must bind runtime rendering and identity-safe route resolution independently.
'@
Write-Utf8 $changePath $change

$featurePath = Join-Path $SpecRoot "FEATURE_REGISTRY.json"
$implementationPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$features = Get-Content -Raw $featurePath | ConvertFrom-Json -Depth 100
$feature = @($features.features | Where-Object feature_id -eq "F-081")
if ($feature.Count -ne 1) { throw "F-081 missing" }
$feature[0].specs = @($feature[0].specs + $changeRelative | Select-Object -Unique)
$feature[0].code_paths = @($feature[0].code_paths + "src/custom_content_studio/ui/route_shell.py" | Select-Object -Unique)
Write-Json $featurePath $features
$implementation = Get-Content -Raw $implementationPath | ConvertFrom-Json -Depth 100
$slice = @($implementation.slices | Where-Object slice_id -eq "IMP-021")
if ($slice.Count -ne 1) { throw "IMP-021 missing" }
$slice[0].deliverables = @($slice[0].deliverables + "Standalone UI route-shell catalog" | Select-Object -Unique)
$slice[0].acceptance_evidence = @($slice[0].acceptance_evidence + "four canonical standalone route descriptors and bounded-layout rule" | Select-Object -Unique)
Write-Json $implementationPath $implementation

$tracePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md"
$trace = Get-Content -Raw $tracePath
if ($trace -notmatch [regex]::Escape($changeRelative)) {
    $old = "12_CHANGE_CONTROL/CHG-2026-0028_CCS_02_010_ROUTE_API_CONTRACT_FREEZE.md, 12_CHANGE_CONTROL/CHG-2026-0029_CCS_02_010A_WORKSPACE_READ_SHELL.md, 09_SHARED_SPEC/UI_WORKFLOW_AND_ROUTE_CONTRACT.md"
    $new = "12_CHANGE_CONTROL/CHG-2026-0028_CCS_02_010_ROUTE_API_CONTRACT_FREEZE.md, 12_CHANGE_CONTROL/CHG-2026-0029_CCS_02_010A_WORKSPACE_READ_SHELL.md, $changeRelative, 09_SHARED_SPEC/UI_WORKFLOW_AND_ROUTE_CONTRACT.md"
    if (-not $trace.Contains($old)) { throw "Traceability baseline missing" }
    Write-Utf8 $tracePath $trace.Replace($old, $new).Replace("| T-021 | src/custom_content_studio/api/workspace_read_shell.py (planned) | PLANNED |", "| T-021 | src/custom_content_studio/api/workspace_read_shell.py, src/custom_content_studio/ui/route_shell.py (planned) | PLANNED |")
}
Append-Once (Join-Path $SpecRoot "12_CHANGE_CONTROL\DECISIONS.md") "ADR-0052" @'
## ADR-0052 — Route catalog remains declarative before UI runtime selection
- Date: 2026-09-09
- Status: ACCEPTED IMPLEMENTATION CONTRACT; PRODUCT IMPLEMENTATION PENDING
- Decision: CCS-02-010B owns only four canonical standalone descriptor templates and one bounded
  layout rule. It has no framework, URL parsing, rendering or data seam.
- Consequence: later route resolution and UI runtime leaves must prove their own authorization,
  identity safety, accessibility and rendering evidence.
'@
Append-Once (Join-Path $SpecRoot "12_CHANGE_CONTROL\CHANGELOG.md") "CHG-2026-0030" @'
## CHG-2026-0030 — CCS-02-010B standalone UI route shell
- Date: 2026-09-09
- F-081 / T-021 / INV-UI-ROUTE-001 declarative presentation child under IMP-021.
- Four canonical standalone route templates and the viewport-bounded layout rule are frozen without
  framework, rendering, state, data, identity, API, mutation or external behavior.
'@

& $Python -I -B (Join-Path $SpecRoot "tools\update_package_index.py")
if ($LASTEXITCODE -ne 0) { throw "Package index refresh failed" }
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$create = @("reports/IMP-021_CCS-02-010B_IMPLEMENTATION.md", "src/custom_content_studio/ui/route_shell.py", "tests/contract/test_standalone_ui_route_shell.py")
$modify = @("src/custom_content_studio/ui/__init__.py")
foreach ($path in $create) { if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Create exists: $path" } }
foreach ($path in $modify) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)) { throw "Modify absent: $path" } }

$discoveryHash = Get-Sha256 $discoveryPath
$changeHash = Get-Sha256 $changePath
$packageHash = Get-Sha256 (Join-Path $SpecRoot "PACKAGE_INDEX.json")
$child = [pscustomobject]@{
    allowed_paths = @($create + $modify | Sort-Object -Unique)
    authorization_requirements = @("Separate ACTIVE packet binds r23/change/repository commit.", "Only pure contract tests; no runtime UI framework, direct repository or API access.", "No rendering, state, mutation, migration or external operation.")
    commands = @(); create_paths = $create; depends_on = @("CCS-02-010", "CCS-02-010A"); directly_executable = $false
    error_contracts = @("PREREQUISITE_NOT_ACCEPTED", "SCOPE_DEVIATION", "SPEC_DIGEST_MISMATCH", "TASK_ENVELOPE_INCOMPLETE")
    evidence = @([pscustomobject]@{ evidence_id="EV-CCS-02-010B-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-010B_STANDALONE_UI_ROUTE_SHELL_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false }, [pscustomobject]@{ evidence_id="EV-CCS-02-010B-CHANGE"; kind="FILE"; required=$true; path=$changeRelative; expected_sha256=$changeHash; sensitivity="INTERNAL"; redaction_required=$false })
    external_side_effect_policy = "FORBIDDEN"; feature_ids = @("F-081")
    forbidden_paths = @(".env", ".env.*", ".runtime/**", "credentials/**", "migrations/**", "requirements.lock", "src/custom_content_studio/api/**", "src/custom_content_studio/application/**", "src/custom_content_studio/infrastructure/**", "src/custom_content_studio/persistence/**", "src/custom_content_studio/domain/**", "tests/gates/**")
    gate_receipts = @([pscustomobject]@{ gate_id="VC-02"; receipt_digest=$null; receipt_id=$null; status="MISSING" })
    implementation_authority_source = "SEPARATE_ACTIVE_AUTHORIZATION_AND_APPROVED_WORK_PACKET"
    in_scope = @("Only four framework-free standalone route descriptors and one declarative viewport-bounded layout rule.", "No data, identity, state or rendering seam.", "Dashboard, Projects, Content and Assets templates only.")
    interfaces = @([pscustomobject]@{ kind="UI_ROUTE_CATALOG"; name="standalone_ui_route_shell"; contract_root="SPEC_ROOT"; contract_path=$changeRelative; direction="IN_PROCESS" })
    invariant_ids = @("INV-UI-ROUTE-001"); leaf_definition_digest = $zero; leaf_task_id = "CCS-02-010B"; migration_policy = "FORBIDDEN"; modify_paths = $modify
    out_of_scope = @("Route registration, rendering/framework/CSS/DOM/browser/session/request/cache state, URL formatting/parsing/selection, identity/authorization/deep-link restoration, data/query/list/pagination, mutation and color/accessibility behavior", "API/resolver/repository/service/SQLite/UnitOfWork/domain/persistence/schema/migration/dependency changes", "Network/provider/credential/deployment/publication and unlisted paths")
    owner_module = "custom_content_studio.ui.route_shell"; parent_work_package_id = "IMP-021"; path_resolution_status = "RESOLVED"
    recovery = [pscustomobject]@{ checkpoint_path=$null; resume_requirements=@("Revalidate r23/change/discovery/repository and CCS-02-010/010A acceptance.", "Confirm creates absent and ui init baseline."); rollback=@() }
    stage = "CCS-02"; status = "PLANNED"
    stop_conditions = @([pscustomobject]@{ code="SPEC_DIGEST_MISMATCH"; condition="r23/change/discovery/package differs." }, [pscustomobject]@{ code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-010 or CCS-02-010A acceptance is absent." }, [pscustomobject]@{ code="TASK_ENVELOPE_INCOMPLETE"; condition="Packet lacks paths/F-081/T-021/INV-UI-ROUTE-001/interface." }, [pscustomobject]@{ code="SCOPE_DEVIATION"; condition="Rendering/framework/API/repository/state/mutation/persistence/migration/external/unlisted work is required." })
    tests = [pscustomobject]@{ introduces=@("T-021"); must_pass=@("T-021"); regression=@() }
    transaction_requirements = @("No transaction, persistence/cache mutation, UI runtime state, direct API/repository access or external effect.")
}
$registry.tasks = @($registry.tasks + $child)
$currentCommit = (& git -c safe.directory=E:/Custom_Contents_APP -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "Repository HEAD unavailable" }
$registry.registry_id = "vc01b-local-20260907-r23"; $registry.registry_status = "DRAFT"; $registry.registry_digest = $zero; $registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit; $registry.context.spec_package_digest = $packageHash; $registry.context.implementation_plan_digest = $zero; $registry.context.leaf_task_id = $null; $registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-010B"; $registry.context.next_recommendation.candidate_slice_id = "IMP-021"; $registry.context.next_recommendation.authorized = $false; $registry.context.next_recommendation.requires_new_authorization = $true; $registry.context.next_recommendation.reason = "CHG-2026-0030 freezes the declarative four-route shell; separate ACTIVE packet required."
$registry.readiness.graph_validated = $false; $registry.readiness.owner_path_test_ownership_validated = $false; $registry.readiness.gate_closure_validated = $false; $registry.readiness.final_closure_leaf_id = $null; $registry.readiness.final_closure_complete = $false; $registry.readiness.report_path = "reports/CCS-02-010B_STANDALONE_UI_ROUTE_SHELL_ENVELOPE_RESOLUTION.md"; $registry.readiness.decision = "NOT_EVALUATED"

$report = @"
# CCS-02-010B Immutable Standalone UI Route-shell Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
r23 preserves r22 and adds only CCS-02-010B under IMP-021: F-081 / T-021 / INV-UI-ROUTE-001.
- r22 SHA-256: $r22Hash
- r22 registry digest: $r22Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0030 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit

The 3-create/1-modify envelope declares exactly Dashboard, Projects, Content and Assets standalone
canonical templates and one bounded viewport layout policy. UI runtime/framework, rendering, state,
data/API/repository access, authorization, mutation, pagination implementation, persistence and
external behavior are forbidden.
"@
Write-Utf8 $reportPath $report
$registry.readiness.report_sha256 = Get-Sha256 $reportPath
[IO.Directory]::CreateDirectory($r23Dir) | Out-Null
Write-Json $r23Path $registry
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r23Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest; $registry.context.implementation_plan_digest = $digest
Write-Json $r23Path $registry
if ((& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r23Path --profile task-registry).Trim() -ne $digest) { throw "Embedded digest verification failed" }
[pscustomobject]@{ r23_path=$r23Path; registry_digest=$digest; discovery_sha256=$discoveryHash; change_sha256=$changeHash; package_sha256=$packageHash; implementation_authorized=$registry.implementation_authorized; allowlist=@($child.allowed_paths) } | Format-List
