$ErrorActionPreference="Stop"
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path;$ccs=Join-Path $repo ".codex\ccs";$spec="E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2";$py=Join-Path $repo ".venv\Scripts\python.exe"
$r21=Join-Path $ccs "task_registries\local-dev-20260907\vc01b-local-20260907-r21\task-registry.json";$dir=Join-Path $ccs "task_registries\local-dev-20260907\vc01b-local-20260907-r22";$out=Join-Path $dir "task-registry.json";$disc=Join-Path $repo "reports\CCS-02-010A_WORKSPACE_READ_SHELL_DISCOVERY.md";$report=Join-Path $repo "reports\CCS-02-010A_WORKSPACE_READ_SHELL_ENVELOPE_RESOLUTION.md";$rel="12_CHANGE_CONTROL/CHG-2026-0029_CCS_02_010A_WORKSPACE_READ_SHELL.md";$change=Join-Path $spec $rel;$zero="0"*64
function Get-Sha($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()};function W($p,$s){[IO.File]::WriteAllText($p,$s.TrimEnd()+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))};function J($p,$o){W $p ($o|ConvertTo-Json -Depth 100)};function N($p){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing $p"}}
foreach($p in @($dir,$report)){if(Test-Path -LiteralPath $p){throw "Immutable output exists $p"}};N $r21;N $py
$base=Get-Content -Raw $r21|ConvertFrom-Json;if($base.registry_id-ne"vc01b-local-20260907-r21" -or $base.implementation_authorized){throw "Unexpected r21"};$r21h=Get-Sha $r21;$r21d=$base.registry_digest
if(@($base.tasks|Where-Object leaf_task_id -eq "CCS-02-010").Count-ne 1 -or @($base.tasks|Where-Object leaf_task_id -eq "CCS-02-010A").Count){throw "Unexpected task baseline"}
if(-not(Test-Path -LiteralPath $disc)){W $disc @'
# CCS-02-010A Workspace API Read-shell Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Parent: CCS-02-010 under IMP-021

The first bounded runtime child owns only GET /api/v1/workspaces/{workspace_id}. Before an injected
resolver runs, URL workspace_id, mandatory X-Workspace-Id, and existing
custom_content_studio.domain.security.ActorContext.workspace_id must be present and exactly equal.
ActorContext remains the sole actor seam. The shell never parses credentials, constructs an actor,
accesses repository/SQLite/UnitOfWork/service locator, or loads an aggregate directly.

The injected WorkspaceReadResolver accepts validated Workspace identity plus ActorContext and returns a
safe projection or absence. Mismatch, missing header, policy denial, cross-Workspace identity and
absence use one indistinguishable 404 WORKSPACE_NOT_FOUND envelope. The resolver is never called on a
failed precondition; no metadata, label, status, breadcrumb, count, cache, authorization or timing
detail leaks.

No mutation, list, cursor, pagination, count, search, filter, sort, cache, UI, browser/dashboard,
Project/Content/Asset retrieval, repository, persistence, migration, dependency or external behavior
is authorized. Smallest future allowlist: one API shell, API registration, one contract test, report.
'@}
if(-not(Test-Path -LiteralPath $change)){W $change @'
# CHG-2026-0029 - CCS-02-010A Workspace API read-shell contract

Status: ACCEPTED / NORMATIVE / PRODUCT IMPLEMENTATION PENDING
Date: 2026-09-09
Scope: CCS-02-010A under IMP-021; successor of CCS-02-010
Traceability: F-081 / T-021 / INV-UI-ROUTE-001

## Contract

Expose exactly GET /api/v1/workspaces/{workspace_id}. URL workspace_id, required X-Workspace-Id and
existing ActorContext.workspace_id must be present and byte-for-byte equal before metadata is loaded.
The shell receives existing custom_content_studio.domain.security.ActorContext and requires existing
Workspace read policy before its injected resolver runs. It neither parses credentials nor changes
ActorContext.

WorkspaceReadResolver is the sole retrieval seam: it receives validated identity and ActorContext and
returns a safe API projection or absence. The shell owns no direct repository, SQLite, UnitOfWork or
aggregate access and cannot return raw repository/aggregate data.

Mismatch, missing header, policy denial, cross-Workspace reference and resolver absence return the
same 404 error envelope with code WORKSPACE_NOT_FOUND, without existence, label, status, breadcrumb,
count, cache, authorization or timing-derived details. Resolver invocation is forbidden before
identity agreement and policy pass.

## Exclusions and envelope

Read-only only: no mutation, pagination, cursor, limit, count, search, filter, sort, list, cache, UI,
browser/dashboard, Project/Content/Asset read, repository, service, persistence, transaction, schema,
migration, dependency, external call, credential, deployment or publication behavior.

Create only src/custom_content_studio/api/workspace_read_shell.py,
tests/contract/test_workspace_read_shell.py and reports/IMP-021_CCS-02-010A_IMPLEMENTATION.md.
Modify only src/custom_content_studio/api/__init__.py for one GET registration and injected resolver
composition. T-021 proves same-Workspace retrieval, URL/header/ActorContext agreement, policy denial
and absence indistinguishability, resolver non-invocation on failures, and no mutation/pagination.
'@}
$fpath=Join-Path $spec "FEATURE_REGISTRY.json";$ipath=Join-Path $spec "INVARIANT_REGISTRY.json";$mpath=Join-Path $spec "IMPLEMENTATION_REGISTRY.json";$features=Get-Content -Raw $fpath|ConvertFrom-Json;$f=@($features.features|Where-Object feature_id -eq "F-081");if($f.Count-ne 1){throw "F-081 missing"};$f[0].specs=@($f[0].specs+$rel|Select-Object -Unique);$f[0].code_paths=@($f[0].code_paths+"src/custom_content_studio/api/workspace_read_shell.py"|Select-Object -Unique);J $fpath $features
$inv=Get-Content -Raw $ipath|ConvertFrom-Json;$i=@($inv.invariants|Where-Object invariant_id -eq "INV-UI-ROUTE-001");if($i.Count-ne 1){throw "Invariant missing"};$i[0].enforcement=@($i[0].enforcement+"API_READ_SHELL"|Select-Object -Unique);J $ipath $inv
$impl=Get-Content -Raw $mpath|ConvertFrom-Json;$s=@($impl.slices|Where-Object slice_id -eq "IMP-021");if($s.Count-ne 1){throw "IMP-021 missing"};$s[0].deliverables=@($s[0].deliverables+"Workspace API read shell"|Select-Object -Unique);$s[0].acceptance_evidence=@($s[0].acceptance_evidence+"hidden-resource read-shell isolation"|Select-Object -Unique);J $mpath $impl
$tpath=Join-Path $spec "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md";$t=Get-Content -Raw $tpath;$old="12_CHANGE_CONTROL/CHG-2026-0028_CCS_02_010_ROUTE_API_CONTRACT_FREEZE.md, 09_SHARED_SPEC/UI_WORKFLOW_AND_ROUTE_CONTRACT.md";if($t.Contains($old)){W $tpath $t.Replace($old,"12_CHANGE_CONTROL/CHG-2026-0028_CCS_02_010_ROUTE_API_CONTRACT_FREEZE.md, $rel, 09_SHARED_SPEC/UI_WORKFLOW_AND_ROUTE_CONTRACT.md").Replace("| T-021 | (planned) | PLANNED |","| T-021 | src/custom_content_studio/api/workspace_read_shell.py (planned) | PLANNED |")}elseif(-not $t.Contains($rel)){throw "Trace baseline missing"}
$dpath=Join-Path $spec "12_CHANGE_CONTROL\DECISIONS.md";$d=Get-Content -Raw $dpath;if($d-match"ADR-0051"){throw "ADR-0051 exists"};W $dpath ($d+"

## ADR-0051 — Workspace read shell fails closed before resolution
- Date: 2026-09-09
- Status: ACCEPTED IMPLEMENTATION CONTRACT; PRODUCT IMPLEMENTATION PENDING
- Decision: CCS-02-010A binds URL Workspace ID, required header and existing ActorContext before an
  injected API-safe resolver can run. Every scope or absence failure uses one hidden 404 envelope.
- Consequence: no cross-Workspace existence oracle or implicit list/cache/UI/persistence behavior.
")
$cpath=Join-Path $spec "12_CHANGE_CONTROL\CHANGELOG.md";$c=Get-Content -Raw $cpath;if($c-match"CHG-2026-0029"){throw "Change exists"};W $cpath ("## CHG-2026-0029 — CCS-02-010A Workspace API read shell
- Date: 2026-09-09
- F-081 / T-021 / INV-UI-ROUTE-001 first bounded runtime child under IMP-021.
- Frozen URL/header/ActorContext agreement, policy-before-resolver and hidden-resource 404.
- Excluded mutations, list/pagination/query, UI, repositories, migrations and external effects.

"+$c)
& $py -I -B (Join-Path $spec "tools\update_package_index.py");if($LASTEXITCODE-ne 0){throw "Package index failed"};& $py -I -B (Join-Path $spec "tools\spec_sync_check.py") --strict --verify-package-index;if($LASTEXITCODE-ne 0){throw "Strict sync failed"}
$create=@("reports/IMP-021_CCS-02-010A_IMPLEMENTATION.md","src/custom_content_studio/api/workspace_read_shell.py","tests/contract/test_workspace_read_shell.py");$modify=@("src/custom_content_studio/api/__init__.py");foreach($p in $create){if(Test-Path -LiteralPath(Join-Path $repo $p)){throw "Create exists $p"}};foreach($p in $modify){N(Join-Path $repo $p)}
$ph=Get-Sha (Join-Path $spec "PACKAGE_INDEX.json");$ch=Get-Sha $change;$dh=Get-Sha $disc
$child=[pscustomobject]@{allowed_paths=@($create+$modify|Sort-Object -Unique);authorization_requirements=@("Separate ACTIVE packet binds r22/change/repository commit.","Only fake-injected contract tests; no direct repository.","No mutation/pagination/UI/migration/external operation.");commands=@();create_paths=$create;depends_on=@("CCS-02-010");directly_executable=$false;error_contracts=@("WORKSPACE_NOT_FOUND","PREREQUISITE_NOT_ACCEPTED","SCOPE_DEVIATION","SPEC_DIGEST_MISMATCH","TASK_ENVELOPE_INCOMPLETE");evidence=@([pscustomobject]@{evidence_id="EV-CCS-02-010A-DISCOVERY";kind="FILE";required=$true;path="reports/CCS-02-010A_WORKSPACE_READ_SHELL_DISCOVERY.md";expected_sha256=$dh;sensitivity="INTERNAL";redaction_required=$false},[pscustomobject]@{evidence_id="EV-CCS-02-010A-CHANGE";kind="FILE";required=$true;path=$rel;expected_sha256=$ch;sensitivity="INTERNAL";redaction_required=$false});external_side_effect_policy="FORBIDDEN";feature_ids=@("F-081");forbidden_paths=@(".env",".env.*",".runtime/**","credentials/**","migrations/**","requirements.lock","src/custom_content_studio/ui/**","src/custom_content_studio/application/**","src/custom_content_studio/infrastructure/**","src/custom_content_studio/persistence/**","src/custom_content_studio/domain/**","tests/gates/**");gate_receipts=@([pscustomobject]@{gate_id="VC-02";receipt_digest=$null;receipt_id=$null;status="MISSING"});implementation_authority_source="SEPARATE_ACTIVE_AUTHORIZATION_AND_APPROVED_WORK_PACKET";in_scope=@("Only one injected-resolver GET Workspace read shell and contract tests.","Require URL/header/ActorContext equality plus Workspace read policy before resolver.","One indistinguishable WORKSPACE_NOT_FOUND 404 for mismatch, denial, cross-Workspace and absence.");interfaces=@([pscustomobject]@{kind="API_READ_SHELL";name="workspace_read_shell";contract_root="SPEC_ROOT";contract_path=$rel;direction="IN_PROCESS"},[pscustomobject]@{kind="ACTOR_CONTEXT";name="custom_content_studio.domain.security.ActorContext";contract_root="REPOSITORY";contract_path="src/custom_content_studio/domain/security/models.py";direction="IN_PROCESS"});invariant_ids=@("INV-UI-ROUTE-001");leaf_definition_digest=$zero;leaf_task_id="CCS-02-010A";migration_policy="FORBIDDEN";modify_paths=$modify;out_of_scope=@("Mutation/list/pagination/cursor/limit/count/search/filter/sort/cache/UI/browser/dashboard/Project/Content/Asset behavior","Repository/service/SQLite/UnitOfWork/domain/persistence/schema/migration/dependency changes","Network/provider/credential/deployment/publication and unlisted paths");owner_module="custom_content_studio.api.workspace_read_shell";parent_work_package_id="IMP-021";path_resolution_status="RESOLVED";recovery=[pscustomobject]@{checkpoint_path=$null;resume_requirements=@("Revalidate r22/change/discovery/repository/CCS-02-010.","Confirm creates absent and api init baseline.");rollback=@()};stage="CCS-02";status="PLANNED";stop_conditions=@([pscustomobject]@{code="SPEC_DIGEST_MISMATCH";condition="r22/change/discovery/package differs."},[pscustomobject]@{code="PREREQUISITE_NOT_ACCEPTED";condition="CCS-02-010 absent."},[pscustomobject]@{code="TASK_ENVELOPE_INCOMPLETE";condition="Packet lacks paths/F-081/T-021/INV-UI-ROUTE-001/interface."},[pscustomobject]@{code="SCOPE_DEVIATION";condition="Mutation/pagination/UI/repository/persistence/migration/external/unlisted work required."});tests=[pscustomobject]@{introduces=@("T-021");must_pass=@("T-021");regression=@()};transaction_requirements=@("No transaction, persistence/cache mutation, direct repository or external effect.")}
$base.tasks=@($base.tasks+$child);$head=(&git -c safe.directory=E:/Custom_Contents_APP -C $repo rev-parse HEAD).Trim();if($LASTEXITCODE-ne 0){throw "No HEAD"};$base.registry_id="vc01b-local-20260907-r22";$base.registry_status="DRAFT";$base.registry_digest=$zero;$base.implementation_authorized=$false;$base.context.repository.current_commit=$head;$base.context.spec_package_digest=$ph;$base.context.implementation_plan_digest=$zero;$base.context.leaf_task_id=$null;$base.context.slice_id=$null;$base.context.next_recommendation.candidate_leaf_task_id="CCS-02-010A";$base.context.next_recommendation.candidate_slice_id="IMP-021";$base.context.next_recommendation.authorized=$false;$base.context.next_recommendation.requires_new_authorization=$true;$base.context.next_recommendation.reason="CHG-2026-0029 freezes the one read-only Workspace API shell; separate ACTIVE packet required.";$base.readiness.graph_validated=$false;$base.readiness.owner_path_test_ownership_validated=$false;$base.readiness.gate_closure_validated=$false;$base.readiness.final_closure_leaf_id=$null;$base.readiness.final_closure_complete=$false;$base.readiness.report_path="reports/CCS-02-010A_WORKSPACE_READ_SHELL_ENVELOPE_RESOLUTION.md";$base.readiness.report_sha256=$null;$base.readiness.decision="NOT_EVALUATED"
W $report "# CCS-02-010A Immutable Workspace API Read-shell Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
r22 preserves r21 and adds only CCS-02-010A under IMP-021: F-081 / T-021 / INV-UI-ROUTE-001.
- r21 SHA-256: $r21h
- r21 registry digest: $r21d
- discovery SHA-256: $dh
- CHG-2026-0029 SHA-256: $ch
- specification package digest: $ph
- repository commit: $head
The 3-create/1-modify envelope is one GET Workspace read shell. URL/header/ActorContext agreement and
policy precede injected resolution; all denied or absent states use identical WORKSPACE_NOT_FOUND 404.
Mutations, pagination/listing, UI, repository/persistence and external behavior are forbidden."
$base.readiness.report_sha256=Get-Sha $report;[IO.Directory]::CreateDirectory($dir)|Out-Null;J $out $base;$digest=(& $py -I -B (Join-Path $spec "tools\artifact_digest.py") $out --profile task-registry).Trim();if($LASTEXITCODE-ne 0 -or $digest-notmatch"^[0-9a-f]{64}$"){throw "Bad digest"};$base.registry_digest=$digest;$base.context.implementation_plan_digest=$digest;J $out $base;$verify=(& $py -I -B (Join-Path $spec "tools\artifact_digest.py") $out --profile task-registry).Trim();if($verify-ne$digest){throw "Digest mismatch"};[pscustomobject]@{r22_path=$out;registry_digest=$digest;discovery_path=$disc;change_path=$change;report_path=$report;allowlist=@($create+$modify);implementation_authorized=$base.implementation_authorized}|Format-List
