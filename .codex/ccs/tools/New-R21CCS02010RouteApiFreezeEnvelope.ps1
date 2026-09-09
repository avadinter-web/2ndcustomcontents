param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "E:\Custom_Contents_APP\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r20Path = Join-Path $revisions "vc01b-local-20260907-r20\task-registry.json"
$r21Dir = Join-Path $revisions "vc01b-local-20260907-r21"
$r21Path = Join-Path $r21Dir "task-registry.json"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-010_ROUTE_API_DISCOVERY.md"
$reportPath = Join-Path $repoRoot "reports\CCS-02-010_ROUTE_API_ENVELOPE_RESOLUTION.md"
$changeRelative = "12_CHANGE_CONTROL/CHG-2026-0028_CCS_02_010_ROUTE_API_CONTRACT_FREEZE.md"
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

foreach ($target in @($r21Dir, $discoveryPath, $reportPath, $changePath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r21 output: $target" }
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python not found: $Python" }

$r20Hash = Get-Sha256 $r20Path
$registry = Get-Content -Raw -LiteralPath $r20Path | ConvertFrom-Json -Depth 100
if ($registry.registry_id -ne "vc01b-local-20260907-r20" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r20 source" }
$baselineDigest = $registry.registry_digest
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-010")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-009" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-010 baseline" }

$discovery = @'
# CCS-02-010 Core UI/API Route Contract Discovery

Status: DISCOVERY COMPLETE / CONTROL-LEAF SUCCESSOR REQUIRED / PRODUCT IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository baseline: 4362c066d5cc528dc7e13847fd97fadbfce6355c
Registry inspected: vc01b-local-20260907-r20
Canonical task: CCS-02-010 - Core UI/API: Dashboard/Projects/Content/Assets

## Decision

The original task mixes four durable resource families, a complete navigation shell, and HTTP/UI
implementation. It is too broad to authorize as one code leaf. The smallest next unit is a control
leaf that freezes only the route/API identity boundary; it creates neither an API endpoint nor a UI
page and authorizes no product source or test path.

Every resource route carries the Workspace identity in its canonical URL. Project and Content routes
also carry their ancestors. The active ActorContext Workspace and `X-Workspace-Id` must equal the URL
Workspace before the server loads or renders metadata. A mismatched, unauthorized, or cross-workspace
resource is hidden with the configured hidden-resource response and must not reveal existence,
name, status, breadcrumb, count, or cached data. A Workspace switch invalidates incompatible
Project/Content/Asset selections and cached query data.

Major Dashboard, Projects, Content and Assets destinations remain standalone, bounded-page contracts:
they are not one long combined page; the shell keeps header/navigation/action context in the viewport;
only the designated work area may scroll or paginate. This establishes interface safety only. It does
not select Streamlit routing mechanics, create an HTTP handler, add a route, render a page, persist
state, install dependencies, or define the later resource query schemas.

## Successor boundary

The successor is documentation-only under IMP-021 and binds F-081/T-021/INV-UI-ROUTE-001. A later,
separately discovered and authorized implementation leaf must choose exact source/test paths after
the actual presentation and API runtime are inspected. It may not infer permission from this control
leaf. Database, migration, API, UI, external-provider, deployment, credential, or publication work
remains forbidden.
'@
Write-Utf8 $discoveryPath $discovery

$change = @'
# CHG-2026-0028 - CCS-02-010 route/API identity contract freeze

Status: ACCEPTED / NORMATIVE / CONTROL LEAF ONLY / PRODUCT IMPLEMENTATION PENDING
Date: 2026-09-09
Scope: CCS-02-010 under IMP-021
Introduced feature/test/invariant: F-081 / T-021 / INV-UI-ROUTE-001

## Frozen route and scope contract

This change freezes the identity boundary for the future Dashboard, Projects, Content and Assets
presentation/API work. It does not authorize a product implementation path.

1. Canonical resource URLs contain `workspace_id`; Project and Content URLs include their Workspace
   and Project ancestors. The Dashboard is Workspace-resolved server-side and never trusts a stale
   browser/session selection as durable authority.
2. For every Workspace-scoped read or mutation, URL `workspace_id`, request `X-Workspace-Id`, and
   ActorContext Workspace scope must agree before resource metadata is read or rendered. A mismatch,
   absent membership, or cross-Workspace identifier fails closed with the configured hidden-resource
   behavior. It must not leak resource existence, labels, status, breadcrumbs, counts, query cache,
   or timing-derived substitute data.
3. Workspace changes clear incompatible Project, Content and Asset selection plus cached query data.
   URL refresh/back/deep link reconstructs context only from canonical identity and server-authorized
   durable state.
4. Dashboard, Projects, Content and Assets are standalone bounded destinations. The page shell keeps
   header/navigation/current action context in the viewport; browser-document long-form scrolling is
   forbidden. Lists and detailed work use pagination or one explicitly bounded internal work area.
   This page rule never replaces accessibility, dirty-buffer, authorization, or API-only UI rules.

## Non-authorization and later work

F-081 is a route/API contract freeze, not an implementation feature flag. No source/test path is
approved here. No handler, route registration, UI page, router, request model, response schema,
database query, migration, persistence, cache, browser state, dependency, network listener, external
call, credential, deployment, publication, or mock is authorized. A later leaf must separately pin
runtime capability, exact URL-to-handler mapping, resource query contracts, error representation,
source/test paths, and acceptance evidence without weakening this invariant.
'@
Write-Utf8 $changePath $change

$featurePath = Join-Path $SpecRoot "FEATURE_REGISTRY.json"
$invariantPath = Join-Path $SpecRoot "INVARIANT_REGISTRY.json"
$testPath = Join-Path $SpecRoot "TEST_CATALOG.json"
$implementationPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$features = Get-Content -Raw $featurePath | ConvertFrom-Json -Depth 100
if (-not @($features.features | Where-Object feature_id -eq "F-081").Count) {
    $features.features += [pscustomobject]@{ feature_id="F-081"; phase="CCS-02"; name="Workspace-safe route/API identity freeze"; specs=@($changeRelative,"09_SHARED_SPEC/UI_WORKFLOW_AND_ROUTE_CONTRACT.md","09_SHARED_SPEC/UI_VISUAL_AND_PAGE_LAYOUT.md","09_SHARED_SPEC/API_CONTRACTS.md"); tests=@("T-021"); code_paths=@(); status="PLANNED" }
    Write-Json $featurePath $features
}
$invariants = Get-Content -Raw $invariantPath | ConvertFrom-Json -Depth 100
if (-not @($invariants.invariants | Where-Object invariant_id -eq "INV-UI-ROUTE-001").Count) {
    $invariants.invariants += [pscustomobject]@{ invariant_id="INV-UI-ROUTE-001"; name="canonical workspace route identity fails closed without cross-workspace UI/API leakage"; enforcement=@("ROUTE_CONTRACT","API_SCOPE_CHECK","PRESENTATION_CONTEXT"); tests=@("T-021") }
    Write-Json $invariantPath $invariants
}
$tests = Get-Content -Raw $testPath | ConvertFrom-Json -Depth 100
if (-not @($tests.tests | Where-Object test_id -eq "T-021").Count) {
    $tests.tests += [pscustomobject]@{ test_id="T-021"; name="Canonical workspace route/API identity and hidden-resource isolation"; phase="CCS-02" }
    Write-Json $testPath $tests
}
$implementation = Get-Content -Raw $implementationPath | ConvertFrom-Json -Depth 100
$slice = @($implementation.slices | Where-Object slice_id -eq "IMP-021")
if ($slice.Count -ne 1) { throw "IMP-021 missing" }
if (-not (@($slice[0].feature_ids) -contains "F-081")) { $slice[0].feature_ids = @($slice[0].feature_ids + "F-081"); Write-Json $implementationPath $implementation }

$uiPath = Join-Path $SpecRoot "09_SHARED_SPEC\UI_WORKFLOW_AND_ROUTE_CONTRACT.md"
Append-Once $uiPath "CHG-2026-0028" @'
## 12. CCS-02-010 pre-implementation route/API freeze (CHG-2026-0028)

F-081 freezes the canonical Workspace identity boundary before any Dashboard, Projects, Content or
Assets implementation. URL `workspace_id`, request Workspace scope and ActorContext membership must
agree before metadata is loaded or rendered. Cross-workspace or unauthorized targets use hidden-resource
behavior and expose no resource existence or stale cached context. These destinations remain standalone,
viewport-bounded pages; this section grants no router, API, UI, persistence or implementation authority.
'@
$apiPath = Join-Path $SpecRoot "09_SHARED_SPEC\API_CONTRACTS.md"
Append-Once $apiPath "F-081 route/API identity freeze" @'
## F-081 route/API identity freeze (pre-implementation)

Before any Dashboard, Projects, Content or Assets endpoint/page is implemented, the canonical URL
Workspace identity, `X-Workspace-Id`, and ActorContext scope must agree. A cross-workspace identifier
is hidden rather than resolved and then filtered. This is a contract-only rule; it adds no endpoint,
request/response schema, handler, or route registration.
'@
$tracePath = Join-Path $SpecRoot "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md"
$trace = Get-Content -Raw $tracePath
if ($trace -notmatch '\| F-081 \|') {
    $anchor = "| F-080 | CCS-02 | Lossless editable-text safety policy | 12_CHANGE_CONTROL/CHG-2026-0027_CCS_02_009_EDITABLE_TEXT_SAFETY.md, 01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md, 04_REVIEW_RENDER/CCS-07_HUMAN_REVIEW.md | T-020 | (planned) | PLANNED |"
    $line = "| F-081 | CCS-02 | Workspace-safe route/API identity freeze | $changeRelative, 09_SHARED_SPEC/UI_WORKFLOW_AND_ROUTE_CONTRACT.md, 09_SHARED_SPEC/UI_VISUAL_AND_PAGE_LAYOUT.md, 09_SHARED_SPEC/API_CONTRACTS.md | T-021 | (planned) | PLANNED |"
    if ($trace.Contains($anchor)) { $trace = $trace.Replace($anchor, $anchor + "`n" + $line) } else { $trace = $trace.TrimEnd() + "`n" + $line }
    Write-Utf8 $tracePath $trace
}
$decisionsPath = Join-Path $SpecRoot "12_CHANGE_CONTROL\DECISIONS.md"
Append-Once $decisionsPath "ADR-0050" @'
## ADR-0050 - Route identity is a Workspace authorization boundary
- Date: 2026-09-09
- Status: ACCEPTED IMPLEMENTATION CONTRACT; PRODUCT IMPLEMENTATION PENDING
- Decision: canonical resource URLs include Workspace identity; URL scope, request scope and
  ActorContext must agree before load/render, and cross-Workspace targets fail closed without leakage.
- Consequence: page shell and route implementation need a later separately authorized runtime leaf.
'@
$changelogPath = Join-Path $SpecRoot "12_CHANGE_CONTROL\CHANGELOG.md"
Append-Once $changelogPath "CHG-2026-0028" @'
## CHG-2026-0028 - CCS-02 route/API identity contract freeze
- Date: 2026-09-09
- F-081 / T-021 / INV-UI-ROUTE-001 added under IMP-021.
- Canonical Workspace route identity, hidden-resource behavior and standalone bounded-page rules are
  frozen without authorizing product routes, API handlers, UI, source paths or tests.
'@

& $Python -I -B (Join-Path $SpecRoot "tools\update_package_index.py")
if ($LASTEXITCODE -ne 0) { throw "Package index refresh failed" }
$sync = & $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index
if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }

$discoveryHash = Get-Sha256 $discoveryPath
$changeHash = Get-Sha256 $changePath
$packageHash = Get-Sha256 (Join-Path $SpecRoot "PACKAGE_INDEX.json")
$leaf = $leaf[0]
$leaf.parent_work_package_id = "IMP-021"
$leaf.path_resolution_status = "RESOLVED"
$leaf.owner_module = "contract.freeze.ccs02.route_api"
$leaf.feature_ids = @("F-081")
$leaf.invariant_ids = @("INV-UI-ROUTE-001")
$leaf.tests.introduces = @("T-021")
$leaf.tests.must_pass = @("T-021")
$leaf.tests.regression = @()
$leaf.create_paths = @()
$leaf.modify_paths = @()
$leaf.allowed_paths = @()
$leaf.forbidden_paths = @("**")
$leaf.interfaces = @([ordered]@{ kind="CONTRACT_FREEZE"; name="workspace_route_api_identity"; contract_root="SPEC_ROOT"; contract_path=$changeRelative; direction="DESIGN_ONLY" })
$leaf.migration_policy = "FORBIDDEN"
$leaf.external_side_effect_policy = "FORBIDDEN"
$leaf.in_scope = @("Freeze only the canonical Workspace route/API identity and standalone bounded-page contract.","Authorize no product source or test path; a later runtime discovery is mandatory.","Bind Workspace URL identity, ActorContext/request scope agreement, hidden-resource behavior, cache invalidation and bounded page rules.")
$leaf.out_of_scope = @("All product source and test writes, API/UI/router/page/handler registration, HTTP listener, schema/query model, persistence, migration, cache implementation and dependency changes","Database, network, media, provider, credential, deployment, publication and every unlisted path")
$leaf.authorization_requirements = @("A separate later ACTIVE work packet must bind an independently discovered implementation envelope.","This r21 control leaf authorizes no product source/test path or product mutation.")
$leaf.error_contracts = @("PREREQUISITE_NOT_ACCEPTED","SCOPE_DEVIATION","SPEC_DIGEST_MISMATCH","TASK_ENVELOPE_INCOMPLETE")
$leaf.transaction_requirements = @("No transaction, persistence mutation, cache mutation, HTTP listener or external effect is authorized by this control leaf.")
$leaf.stop_conditions = @([ordered]@{ code="SPEC_DIGEST_MISMATCH"; condition="The r21 change-control, discovery or package binding differs." },[ordered]@{ code="PREREQUISITE_NOT_ACCEPTED"; condition="CCS-02-009 acceptance is absent." },[ordered]@{ code="TASK_ENVELOPE_INCOMPLETE"; condition="A later packet claims product paths without a separate discovery and exact allowlist." },[ordered]@{ code="SCOPE_DEVIATION"; condition="Work creates API/UI/router/page/test/database/migration/cache/dependency/external behavior from this contract-only leaf." })
$leaf.recovery = [ordered]@{ checkpoint_path=$null; resume_requirements=@("Revalidate r21, CHG-2026-0028, discovery, repository commit and CCS-02-009 acceptance.","Require a separate runtime discovery before any product source/test path is proposed."); rollback=@() }
$leaf.evidence = @([ordered]@{ evidence_id="EV-CCS-02-010-DISCOVERY"; kind="FILE"; required=$true; path="reports/CCS-02-010_ROUTE_API_DISCOVERY.md"; expected_sha256=$discoveryHash; sensitivity="INTERNAL"; redaction_required=$false },[ordered]@{ evidence_id="EV-CCS-02-010-CHANGE"; kind="FILE"; required=$true; path=$changeRelative; expected_sha256=$changeHash; sensitivity="INTERNAL"; redaction_required=$false })

$currentCommit = (& git -c safe.directory=E:/Custom_Contents_APP -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -ne "4362c066d5cc528dc7e13847fd97fadbfce6355c") { throw "Unexpected repository HEAD: $currentCommit" }
$registry.registry_id = "vc01b-local-20260907-r21"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.spec_package_digest = $packageHash
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-02-010"
$registry.context.next_recommendation.candidate_slice_id = "IMP-021"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "CHG-2026-0028 freezes route/API scope only; later runtime discovery is required before any product implementation packet."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-02-010_ROUTE_API_ENVELOPE_RESOLUTION.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$resolved = @($registry.tasks | Where-Object path_resolution_status -eq "RESOLVED").Count
$required = @($registry.tasks | Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report = @"
# CCS-02-010 Immutable Route/API Contract Freeze Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r21 preserves r20 and resolves CCS-02-010 only as a documentation-only control leaf. It retains
depends_on=[CCS-02-009], corrects the parent to IMP-021, and binds F-081/T-021 under
INV-UI-ROUTE-001. It deliberately grants no product source or test path.

- r20 SHA-256: $r20Hash
- r20 registry digest: $baselineDigest
- discovery SHA-256: $discoveryHash
- CHG-2026-0028 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: $($registry.tasks.Count) total, $resolved RESOLVED, $required DISCOVERY_REQUIRED

The frozen contract requires canonical Workspace URL identity and exact ActorContext/request scope
agreement before data load or render, hidden-resource behavior without cross-workspace leakage, and
standalone bounded Dashboard/Projects/Content/Assets destinations. r21 remains DRAFT,
NOT_EVALUATED and implementation_authorized=false; no API/UI/router/page/database/source/test path
exists in this envelope.
"@
Write-Utf8 $reportPath $report
$registry.readiness.report_sha256 = Get-Sha256 $reportPath
[IO.Directory]::CreateDirectory($r21Dir) | Out-Null
Write-Json $r21Path $registry
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r21Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") { throw "Bad registry digest: $digest" }
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
Write-Json $r21Path $registry
if ((& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r21Path --profile task-registry).Trim() -ne $digest) { throw "Embedded digest verification failed" }
[pscustomobject]@{ r21_path=$r21Path; registry_digest=$digest; discovery_sha256=$discoveryHash; change_sha256=$changeHash; package_sha256=$packageHash; implementation_authorized=$registry.implementation_authorized; allowlist=@($leaf.allowed_paths) } | Format-List
