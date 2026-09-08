param(
    [string]$SpecRoot = "E:\AI_Automation\related\custom_content_studio_codex_spec_v1\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisions = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r19Path = Join-Path $revisions "vc01b-local-20260907-r19\task-registry.json"
$r20Dir = Join-Path $revisions "vc01b-local-20260907-r20"
$r20Path = Join-Path $r20Dir "task-registry.json"
$reportPath = Join-Path $repoRoot "reports\CCS-02-009_EDITABLE_TEXT_ENVELOPE_RESOLUTION.md"
$discoveryPath = Join-Path $repoRoot "reports\CCS-02-009_EDITABLE_TEXT_DISCOVERY.md"
$changeRelative = "12_CHANGE_CONTROL/CHG-2026-0027_CCS_02_009_EDITABLE_TEXT_SAFETY.md"
$changePath = Join-Path $SpecRoot $changeRelative

function Get-Sha256([string]$Path) { if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }; (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Utf8([string]$Path, [string]$Content) { [IO.File]::WriteAllText($Path, $Content.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false)) }
function Write-Json([string]$Path, $Value) { Write-Utf8 $Path (($Value | ConvertTo-Json -Depth 100)) }

foreach ($target in @($r20Dir, $reportPath)) { if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite immutable r20 output: $target" } }
$r19Hash = Get-Sha256 $r19Path
$registry = Get-Content -Raw $r19Path | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r19" -or $registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized) { throw "Unexpected r19 source" }
$r19Digest = $registry.registry_digest
$leaf = @($registry.tasks | Where-Object leaf_task_id -eq "CCS-02-009")
if ($leaf.Count -ne 1 -or (@($leaf[0].depends_on) -join ",") -ne "CCS-02-008" -or $leaf[0].path_resolution_status -ne "DISCOVERY_REQUIRED") { throw "Unexpected CCS-02-009 baseline" }

$discovery = @"
# CCS-02-009 Editable Text Safety Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR AND NARROW CHANGE CONTROL REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository baseline: `$($registry.context.repository.current_commit)
Registry inspected: vc01b-local-20260907-r19
Canonical task: CCS-02-009 - String normalization: review_note and editable text safety

## Decision

`review_note` and other editable notes are already specified as `str | None`, but the existing
language does not define a safe, lossless boundary. CCS-02-009 is the smallest shared domain
policy, not a review aggregate or persistence feature. Its correct parent is **IMP-022** because
it is a dependency-free Content-side value policy, following CCS-02-008. CCS-07 remains the future
consumer that chooses ReviewSession fields, persistence, lifecycle, authorization, and UI behavior.

The candidate API is `custom_content_studio.domain.editable_text.normalize_editable_text(value)`.
It accepts only `str | None`; `None` remains absence and `""` remains a present empty value. A valid
string is returned byte-for-code-point unchanged: no trim, casefold, whitespace collapse, escaping,
line-ending conversion, or NFC/NFD/NFKC/NFKD conversion occurs. `len(value)` is the binding length
measure and must be at most 10,000 Python code points. U+000A LF, U+000D CR, and an existing CRLF
pair are allowed and preserved exactly. Every other Unicode General Category `Cc` control character
is rejected; lone surrogate code points are also rejected because they are not Unicode scalar values.

This leaf does not introduce review persistence, a ReviewSession field, a schema/migration, API/UI,
repository/service, Content or ContentVersion mutation, sanitization/rendering, or any CCS-07
consumer change. A later consumer may impose its own narrower display or storage constraint only at
its own boundary; it must not reinterpret this policy as permission to transform accepted text.
"@
Write-Utf8 $discoveryPath $discovery

$change = @"
# CHG-2026-0027 - CCS-02-009 lossless editable-text safety boundary

Status: ACCEPTED / NORMATIVE / PRODUCT IMPLEMENTATION PENDING
Date: 2026-09-09
Scope: CCS-02-009 under IMP-022
Introduced feature/test/invariant: F-080 / T-020 / INV-TEXT-001

## Contract

CCS-02-009 owns a pure, dependency-free `normalize_editable_text(value: str | None) -> str | None`
domain policy. The name means validation plus identity preservation; it does **not** perform Unicode
normalization or any other text rewrite. `None` is returned as `None`; `""` is returned as `""` and
is never treated as absence. For accepted strings, the returned sequence of Python code points,
including all Unicode characters and every existing LF, CR, or CRLF sequence, is identical to input.

The maximum is exactly 10,000 Python code points, measured by `len(value)`. Inputs above the limit,
non-`str` non-`None` values, lone surrogate code points, and control characters are rejected with
the stable `DOMAIN_VALIDATION_FAILED` contract. LF (U+000A) and CR (U+000D) are the sole control
character exceptions; every other `Cc` code point is rejected. No NFC, NFD, NFKC, NFKD, case,
whitespace, escaping, sanitization, or line-ending transformation is permitted.

## Ownership and non-change condition

F-080, T-020, and INV-TEXT-001 are CCS-02/IMP-022 ownership. CCS-07 is a future consumer only:
this change does not create or modify ReviewSession, review-note persistence, review decisions,
approval lineage, API/UI, database schema, or any existing aggregate. The policy is deliberately
not a renderer, HTML sanitizer, serializer, or storage adapter. A future CCS-07 consumer must pass
accepted text through unchanged and owns any separately approved persistence/display constraints.

## Implementation envelope

The successor may create only:

1. `src/custom_content_studio/domain/editable_text.py`
2. `tests/unit/test_editable_text.py`
3. `reports/IMP-022_CCS-02-009_IMPLEMENTATION.md`

It may modify only `src/custom_content_studio/domain/__init__.py`. T-020 must prove None/empty
distinction, Unicode and CR/LF/CRLF identity preservation, no normalization-form conversion,
10,000 boundary acceptance and 10,001 rejection, control/surrogate/type rejection, and no I/O.
No migration, API, repository, review persistence, existing aggregate, dependency, deployment,
publication, or external operation is authorized.
"@
Write-Utf8 $changePath $change

$featurePath = Join-Path $SpecRoot "FEATURE_REGISTRY.json"; $invariantPath = Join-Path $SpecRoot "INVARIANT_REGISTRY.json"; $testPath = Join-Path $SpecRoot "TEST_CATALOG.json"; $implementationPath = Join-Path $SpecRoot "IMPLEMENTATION_REGISTRY.json"
$features = Get-Content -Raw $featurePath | ConvertFrom-Json
if (-not @($features.features | Where-Object feature_id -eq "F-080").Count) { $features.features += [pscustomobject]@{feature_id="F-080";phase="CCS-02";name="Lossless editable-text safety policy";specs=@($changeRelative,"01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md","04_REVIEW_RENDER/CCS-07_HUMAN_REVIEW.md");tests=@("T-020");code_paths=@();status="PLANNED"}; Write-Json $featurePath $features }
$invariants = Get-Content -Raw $invariantPath | ConvertFrom-Json
if (-not @($invariants.invariants | Where-Object invariant_id -eq "INV-TEXT-001").Count) { $invariants.invariants += [pscustomobject]@{invariant_id="INV-TEXT-001";name="editable text preserves accepted code points while rejecting unsafe controls and oversize input";enforcement=@("DOMAIN_POLICY");tests=@("T-020")}; Write-Json $invariantPath $invariants }
$tests = Get-Content -Raw $testPath | ConvertFrom-Json
if (-not @($tests.tests | Where-Object test_id -eq "T-020").Count) { $tests.tests += [pscustomobject]@{test_id="T-020";name="Editable text lossless safety and code-point boundary";phase="CCS-02"}; Write-Json $testPath $tests }
$implementation = Get-Content -Raw $implementationPath | ConvertFrom-Json; $slice=@($implementation.slices | Where-Object slice_id -eq "IMP-022")
if ($slice.Count -ne 1) { throw "IMP-022 missing" }; if (-not (@($slice[0].feature_ids) -contains "F-080")) { $slice[0].feature_ids=@($slice[0].feature_ids+"F-080"); Write-Json $implementationPath $implementation }
$foundationPath=Join-Path $SpecRoot "01_FOUNDATION\CCS-02_PROJECT_CONTENT_ASSET.md"; $foundation=Get-Content -Raw $foundationPath; $foundation=$foundation -replace "Editable notes including `review_note` are `str \| None`\.","F-080 owns a lossless `str | None` policy: None and empty string remain distinct; accepted Unicode and CR/LF/CRLF are unchanged; only LF/CR controls are allowed; maximum is 10,000 Python code points."; Write-Utf8 $foundationPath $foundation
$reviewPath=Join-Path $SpecRoot "04_REVIEW_RENDER\CCS-07_HUMAN_REVIEW.md"; $review=Get-Content -Raw $reviewPath; $review=$review -replace "- review_note is string-safe\.","- review_note is a future consumer of F-080; this document does not add persistence or transformation authority."; Write-Utf8 $reviewPath $review
$tracePath=Join-Path $SpecRoot "12_CHANGE_CONTROL\TRACEABILITY_MATRIX.md"; $trace=(Get-Content -Raw $tracePath) -replace "(?m)^\| F-080 \|.*(?:\r?\n)?", ""; Write-Utf8 $tracePath ($trace -replace "(\| F-079 \|[^\r\n]*\r?\n)","`$1| F-080 | CCS-02 | Lossless editable-text safety policy | $changeRelative, 01_FOUNDATION/CCS-02_PROJECT_CONTENT_ASSET.md, 04_REVIEW_RENDER/CCS-07_HUMAN_REVIEW.md | T-020 | `(planned) | PLANNED |`r`n")
$decisionsPath=Join-Path $SpecRoot "12_CHANGE_CONTROL\DECISIONS.md"; if (-not ((Get-Content -Raw $decisionsPath) -match "ADR-0049")) { Write-Utf8 $decisionsPath ((Get-Content -Raw $decisionsPath)+@"

## ADR-0049 - Editable text is validated but never rewritten
- Date: 2026-09-09
- Status: ACCEPTED IMPLEMENTATION CONTRACT; PRODUCT IMPLEMENTATION PENDING
- Decision: F-080 validates `str | None`, exact 10,000 Python-code-point length, scalar safety and
  controls while preserving accepted Unicode and original LF/CR/CRLF exactly. It performs no Unicode
  normalization-form conversion.
- Consequence: CCS-07 consumes this later without persistence or aggregate changes in CCS-02-009.
"@) }
$changelogPath=Join-Path $SpecRoot "12_CHANGE_CONTROL\CHANGELOG.md"; if (-not ((Get-Content -Raw $changelogPath) -match "CHG-2026-0027")) { Write-Utf8 $changelogPath (@"
## CHG-2026-0027 - CCS-02 editable-text safety boundary
- Date: 2026-09-09
- F-080 / T-020 / INV-TEXT-001 added under IMP-022.
- None/empty distinction and accepted Unicode/line-ending identity are frozen; controls except LF/CR,
  invalid scalars, and input above 10,000 Python code points are rejected.
- CCS-07 persistence, ReviewSession and all aggregates remain unchanged.

"@+(Get-Content -Raw $changelogPath)) }

& $Python -I -B (Join-Path $SpecRoot "tools\update_package_index.py"); if ($LASTEXITCODE -ne 0) { throw "Package index refresh failed" }
$sync=& $Python -I -B (Join-Path $SpecRoot "tools\spec_sync_check.py") --strict --verify-package-index; if ($LASTEXITCODE -ne 0 -or ($sync -join "`n") -notmatch "SPEC SYNC: PASS") { throw "Strict spec sync failed" }
$discoveryHash=Get-Sha256 $discoveryPath; $changeHash=Get-Sha256 $changePath; $packageHash=Get-Sha256 (Join-Path $SpecRoot "PACKAGE_INDEX.json")
$create=@("reports/IMP-022_CCS-02-009_IMPLEMENTATION.md","src/custom_content_studio/domain/editable_text.py","tests/unit/test_editable_text.py"); $modify=@("src/custom_content_studio/domain/__init__.py")
foreach($path in $create){if(Test-Path -LiteralPath (Join-Path $repoRoot $path)){throw "Create path exists: $path"}}; foreach($path in $modify){if(-not(Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf)){throw "Modify path missing: $path"}}
$leaf=$leaf[0]; $leaf.parent_work_package_id="IMP-022"; $leaf.path_resolution_status="RESOLVED"; $leaf.owner_module="custom_content_studio.domain.editable_text"; $leaf.feature_ids=@("F-080"); $leaf.invariant_ids=@("INV-TEXT-001"); $leaf.tests.introduces=@("T-020"); $leaf.tests.must_pass=@("T-020"); $leaf.tests.regression=@(); $leaf.create_paths=$create; $leaf.modify_paths=$modify; $leaf.allowed_paths=@($create+$modify|Sort-Object -Unique); $leaf.forbidden_paths=@(".env",".env.*",".runtime/**","credentials/**","migrations/**","requirements.lock","src/custom_content_studio/api/**","src/custom_content_studio/ui/**","src/custom_content_studio/application/**","src/custom_content_studio/infrastructure/**","tests/gates/**")
$leaf.interfaces=@([ordered]@{kind="DOMAIN_POLICY";name="normalize_editable_text";contract_root="SPEC_ROOT";contract_path=$changeRelative;direction="IN_PROCESS"}); $leaf.migration_policy="FORBIDDEN"; $leaf.external_side_effect_policy="FORBIDDEN"; $leaf.in_scope=@("Implement only the pure lossless editable-text safety policy and exact unit tests.","Preserve None/empty distinction, valid Unicode and CR/LF/CRLF; reject unsafe controls, invalid scalars and more than 10,000 Python code points.","Do not perform any Unicode normalization-form or line-ending conversion; CCS-07 is a future unchanged consumer."); $leaf.out_of_scope=@("ReviewSession/review persistence/review decision/approval lineage and existing aggregate changes","Text rendering HTML sanitization serialization storage API UI repositories application services bootstrap","Migration persistence media network provider credentials dependencies deployment publication and every unlisted path"); $leaf.authorization_requirements=@("A separate ACTIVE local work packet must bind exact r20 and repository commit before mutation.","Only pure synthetic unit tests are permitted.","No migration, external operation or CCS-07 consumer change is authorized."); $leaf.error_contracts=@("DOMAIN_VALIDATION_FAILED","MIGRATION_DECISION_REQUIRED","PREREQUISITE_NOT_ACCEPTED","SCOPE_DEVIATION","SPEC_DIGEST_MISMATCH","TASK_ENVELOPE_INCOMPLETE"); $leaf.transaction_requirements=@("The policy is pure and performs no transaction, persistence mutation, external effect or caller-input mutation."); $leaf.stop_conditions=@([ordered]@{code="SPEC_DIGEST_MISMATCH";condition="The r20 change-control, discovery or package binding differs."},[ordered]@{code="PREREQUISITE_NOT_ACCEPTED";condition="CCS-02-008 acceptance is absent."},[ordered]@{code="MIGRATION_DECISION_REQUIRED";condition="Implementation needs database storage, migration, SQL, manifest, trigger or backfill."},[ordered]@{code="TASK_ENVELOPE_INCOMPLETE";condition="The ACTIVE packet omits exact paths, T-020, F-080, INV-TEXT-001 or authority."},[ordered]@{code="SCOPE_DEVIATION";condition="Work requires review persistence/aggregate change, text rewriting, API/UI/media/external work or an unlisted path."}); $leaf.recovery=[ordered]@{checkpoint_path=$null;resume_requirements=@("Revalidate r20, CHG-2026-0027, discovery, repository commit and CCS-02-008 acceptance.","Confirm create paths remain absent and the sole modify path matches the ACTIVE baseline.");rollback=@()}; $leaf.evidence=@([ordered]@{evidence_id="EV-CCS-02-009-DISCOVERY";kind="FILE";required=$true;path="reports/CCS-02-009_EDITABLE_TEXT_DISCOVERY.md";expected_sha256=$discoveryHash;sensitivity="INTERNAL";redaction_required=$false},[ordered]@{evidence_id="EV-CCS-02-009-CHANGE";kind="FILE";required=$true;path=$changeRelative;expected_sha256=$changeHash;sensitivity="INTERNAL";redaction_required=$false})
$currentCommit=(& git -c safe.directory=E:/Custom_Contents_APP -C $repoRoot rev-parse HEAD).Trim(); if($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$"){throw "Cannot resolve HEAD"}; $registry.registry_id="vc01b-local-20260907-r20"; $registry.registry_status="DRAFT"; $registry.registry_digest=$zero; $registry.implementation_authorized=$false; $registry.context.repository.current_commit=$currentCommit; $registry.context.spec_package_digest=$packageHash; $registry.context.implementation_plan_digest=$zero; $registry.context.leaf_task_id=$null; $registry.context.slice_id=$null; $registry.context.next_recommendation.candidate_leaf_task_id="CCS-02-009"; $registry.context.next_recommendation.candidate_slice_id="IMP-022"; $registry.context.next_recommendation.authorized=$false; $registry.context.next_recommendation.requires_new_authorization=$true; $registry.context.next_recommendation.reason="CHG-2026-0027 closes the exact lossless CCS-02-009 text boundary; a separate ACTIVE local work packet remains required."; $registry.readiness.graph_validated=$false; $registry.readiness.owner_path_test_ownership_validated=$false; $registry.readiness.gate_closure_validated=$false; $registry.readiness.final_closure_leaf_id=$null; $registry.readiness.final_closure_complete=$false; $registry.readiness.report_path="reports/CCS-02-009_EDITABLE_TEXT_ENVELOPE_RESOLUTION.md"; $registry.readiness.report_sha256=$null; $registry.readiness.decision="NOT_EVALUATED"
$resolved=@($registry.tasks|Where-Object path_resolution_status -eq "RESOLVED").Count; $discoveryCount=@($registry.tasks|Where-Object path_resolution_status -eq "DISCOVERY_REQUIRED").Count
$report=@"
# CCS-02-009 Immutable Editable Text Envelope Resolution

Status: DRAFT / ENVELOPE RESOLVED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09

r20 preserves r19 and resolves CCS-02-009 only. It corrects the parent to IMP-022, retains
depends_on=[CCS-02-008], and binds F-080/T-020 under INV-TEXT-001. CCS-07 is an unchanged future
consumer: no review persistence, aggregate, API/UI or review-lifecycle work is authorized.

- r19 SHA-256: $r19Hash
- r19 registry digest: $r19Digest
- discovery SHA-256: $discoveryHash
- CHG-2026-0027 SHA-256: $changeHash
- specification package digest: $packageHash
- repository commit: $currentCommit
- registry tasks: `$($registry.tasks.Count) total, $resolved RESOLVED, $discoveryCount DISCOVERY_REQUIRED

The pure policy keeps None distinct from empty string, preserves valid Unicode and original LF/CR/CRLF
without any normalization-form or line-ending conversion, accepts at most 10,000 Python code points,
and rejects non-string values, invalid scalar surrogates, and controls other than LF/CR. The exact
future implementation envelope has 3 create and 1 modify path. No product code or test is created
here; r20 remains DRAFT, NOT_EVALUATED and implementation_authorized=false.
"@; Write-Utf8 $reportPath $report; $registry.readiness.report_sha256=Get-Sha256 $reportPath; [IO.Directory]::CreateDirectory($r20Dir)|Out-Null; Write-Json $r20Path $registry
$digest=(& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r20Path --profile task-registry).Trim(); if($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$"){throw "Bad registry digest: $digest"}; $registry.registry_digest=$digest; $registry.context.implementation_plan_digest=$digest; Write-Json $r20Path $registry; if((& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r20Path --profile task-registry).Trim() -ne $digest){throw "Embedded digest verification failed"}; [pscustomobject]@{r20_path=$r20Path;registry_digest=$digest;report_path=$reportPath;discovery_path=$discoveryPath;change_path=$changePath;allowlist=@($create+$modify);implementation_authorized=$registry.implementation_authorized}|Format-List
