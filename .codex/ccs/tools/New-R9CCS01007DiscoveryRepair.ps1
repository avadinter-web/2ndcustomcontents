param(
    [string]$SpecRoot = "E:\\AI_Automation\\related\\custom_content_studio_codex_spec_v1\\custom_content_studio_codex_spec_v2_2",
    [string]$Python = "C:\\Users\\knthr\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
)

$ErrorActionPreference = "Stop"
$zero = "0" * 64
$expectedR8Sha256 = "506186fb89cf36fbda3acac280a1632a5c76cd0c911894da0285e9bf969abbe6"
$expectedOriginalDiscoverySha256 = "dbc4b9f3f1b441223aafdbab58761d5fc3c0de0e9b8f40af90ad50c7d1396601"
$ccsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $ccsRoot)
$revisionRoot = Join-Path $ccsRoot "task_registries\local-dev-20260907"
$r8Path = Join-Path $revisionRoot "vc01b-local-20260907-r8\task-registry.json"
$r9Dir = Join-Path $revisionRoot "vc01b-local-20260907-r9"
$r9Path = Join-Path $r9Dir "task-registry.json"
$originalDiscoveryPath = Join-Path $repoRoot "reports\CCS-01-007_DISCOVERY_WORK_PACKET.md"
$correctedDiscoveryPath = Join-Path $repoRoot "reports\CCS-01-007_DISCOVERY_WORK_PACKET_V2.md"
$reportPath = Join-Path $repoRoot "reports\CCS-01-007_DISCOVERY_REPAIR.md"

if (-not (Test-Path -LiteralPath $r8Path -PathType Leaf)) {
    throw "Missing immutable r8 source: $r8Path"
}
if (-not (Test-Path -LiteralPath $originalDiscoveryPath -PathType Leaf)) {
    throw "Missing original CCS-01-007 discovery packet: $originalDiscoveryPath"
}
foreach ($target in @($r9Dir, $correctedDiscoveryPath, $reportPath)) {
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite immutable repair output: $target"
    }
}

$r8Sha256 = (Get-FileHash -LiteralPath $r8Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r8Sha256 -ne $expectedR8Sha256) {
    throw "Unexpected r8 SHA-256: $r8Sha256"
}
$originalDiscoverySha256 = (Get-FileHash -LiteralPath $originalDiscoveryPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($originalDiscoverySha256 -ne $expectedOriginalDiscoverySha256) {
    throw "Unexpected original discovery SHA-256: $originalDiscoverySha256"
}

$registry = Get-Content -LiteralPath $r8Path -Raw | ConvertFrom-Json
if ($registry.registry_id -ne "vc01b-local-20260907-r8") {
    throw "Unexpected source registry_id: $($registry.registry_id)"
}
if ($registry.registry_status -ne "DRAFT" -or $registry.implementation_authorized -ne $false) {
    throw "r8 must remain DRAFT and unauthorized"
}

$leaves = @($registry.tasks | Where-Object { $_.leaf_task_id -eq "CCS-01-007" })
if ($leaves.Count -ne 1) {
    throw "Expected exactly one CCS-01-007 leaf, found $($leaves.Count)"
}
$leaf = $leaves[0]
if ($leaf.parent_work_package_id -ne "IMP-013") {
    throw "CCS-01-007 must remain assigned to IMP-013"
}
if ($leaf.path_resolution_status -ne "DISCOVERY_REQUIRED") {
    throw "CCS-01-007 must remain DISCOVERY_REQUIRED"
}
if (@($leaf.allowed_paths).Count -ne 0 -or @($leaf.create_paths).Count -ne 0 -or @($leaf.modify_paths).Count -ne 0) {
    throw "CCS-01-007 r8 discovery leaf unexpectedly permits paths"
}
if (@($leaf.forbidden_paths).Count -ne 1 -or $leaf.forbidden_paths[0] -ne "**") {
    throw "CCS-01-007 r8 discovery leaf must remain deny-all"
}

$original = Get-Content -LiteralPath $originalDiscoveryPath -Raw
$cutoff = '`tests/unit/test_observability.py` must prove:'
if (-not $original.TrimEnd([char[]]"`r`n").EndsWith($cutoff)) {
    throw "Original discovery no longer ends at the recorded truncation boundary"
}
$oldStatus = 'Status: `DRAFT / DISCOVERY COMPLETE / IMPLEMENTATION NOT AUTHORIZED BY R7`'
$newStatus = @'
Status: `DRAFT / DISCOVERY COMPLETE / IMPLEMENTATION NOT AUTHORIZED`
Version: `2`
Supersedes: `reports/CCS-01-007_DISCOVERY_WORK_PACKET.md` (truncated evidence retained immutably)
Correction: r8 fixed ownership to `IMP-013`; r9 binds this complete packet without granting implementation authority.
'@
if (-not $original.Contains($oldStatus)) {
    throw "Original discovery status marker was not found"
}
$corrected = $original.Replace($oldStatus, $newStatus.TrimEnd([char[]]"`r`n")).TrimEnd([char[]]"`r`n")
$supplement = @'

- generated request and correlation IDs are distinct valid UUIDs and differ across requests;
- context identifiers reject leading/trailing whitespace, control characters and values over 128 characters;
- `attempt` rejects booleans and non-positive values;
- JSON output is one deterministic object per line, uses UTC and contains only the closed field set;
- console output is one bounded deterministic line;
- repeated configuration leaves exactly one owned stream handler, keeps `propagate=false` and does not mutate unrelated or root handlers;
- unsafe summaries are rejected before logging and formatter failure emits only the fixed safe fallback;
- secret-bearing names and values cannot appear in emitted output;
- only a local stream handler exists; no file, network, syslog, HTTP, OTLP, cloud or telemetry handler is created.

`tests/integration/test_startup_health.py` must prove:

- liveness is available without configuration and returns `LIVE`, `UNKNOWN` and no readiness checks;
- the API boundary ignores caller-provided request/correlation headers and generates fresh UUIDs;
- response headers and the public health document contain the same generated IDs;
- readiness evaluates exactly `configuration`, `scope` and `runtime_paths` in deterministic order;
- successful readiness returns HTTP 200/`READY`, while invalid configuration returns HTTP 503/`NOT_READY` with a bounded diagnostic code;
- `/health` remains a compatibility alias of readiness and `/health/live` remains independent of readiness failure;
- public responses exclude repository/runtime paths, configuration values, tracebacks, secrets and caller identifiers;
- CLI health uses the common document, exits 0 for `READY`, exits nonzero for `NOT_READY` and emits only the safe startup record;
- tests invoke route functions in memory and never bind a listener or call a network.

`tests/test_bootstrap.py` must prove:

- `/health`, `/health/live` and `/health/ready` are registered;
- bootstrap, API, UI, worker, compatibility-worker and scheduler shells retain clean local composition;
- the CLI output remains path-safe and compatible with the common health schema.

Traceability is deliberately bounded to canonical leaf `CCS-01-007`, parent `IMP-013`, legacy row
`11_CODEX_TASKS/CCS-01_TASKS.md#L16` and the `IMP-013` deliverables/acceptance evidence in
`IMPLEMENTATION_REGISTRY.json`. The source package does not bind feature, invariant or canonical
test IDs to this leaf, so this discovery does not invent them and the DRAFT registry arrays remain
empty.

## 8. Required verification commands

Run from `E:\Custom_Contents_APP` with the repository-local CPython 3.12 environment:

```powershell
.\.venv\Scripts\python.exe -m pytest tests/unit/test_observability.py tests/integration/test_startup_health.py tests/test_bootstrap.py
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m ruff check src tests
.\.venv\Scripts\python.exe -m ruff format --check src tests
.\.venv\Scripts\python.exe -m mypy src
git diff --check
```

The leaf test set, full regression suite, lint, format, strict type check and whitespace check must
all pass. Tests must use generated identifiers, in-memory streams and in-memory ASGI calls only.
They must not open the runtime database, create runtime directories, bind sockets, call providers
or install dependencies.

## 9. Completion criteria

The implementation attempt is reviewable only when all of the following are true:

- every changed path is in the exact allowlist in section 4 and no dependency/lockfile changed;
- the closed correlation, logging and startup-health contracts in section 5 are implemented;
- all tests and commands in sections 7 and 8 pass;
- process imports and route registration remain side-effect-free;
- no raw credential, request body, private path, exception text or unbounded content can reach a public health document or log line;
- no external sink, listener, provider, database, migration, job claim, schedule or publication action is activated;
- the implementation report records the exact delta, commands, results, evidence hashes and preserved unrelated worktree state;
- final review confirms that `CCS-01-008` remains a later gate and no later operational feature is claimed complete.

## 10. Stop conditions

Stop the implementation attempt as `LOCAL_DEVELOPMENT_GATE_MISMATCH` if any required change falls
outside section 4, a new dependency is required, an external sink or network/listener is needed,
runtime/database/credential access is requested, caller-supplied correlation must be trusted, or
the public failure contract would expose an unbounded/internal value. Stop as
`TASK_ENVELOPE_INCOMPLETE` if the attempt-scoped authorization, exact mutation allowlist, baseline
or verification evidence is missing.

## 11. Authorization boundary and next controlled action

This discovery packet and r9 are evidence only. They do not authorize repository writes or
execution. A separate attempt-scoped ACTIVE local work packet and local decision must copy the
exact allowlist and exclusions before implementation. Deployment, publication, credential/account
changes, production/runtime database changes and external observability remain separately
prohibited.
'@
$corrected = $corrected + $supplement + "`n"
[IO.File]::WriteAllText($correctedDiscoveryPath, $corrected, [Text.UTF8Encoding]::new($false))
$correctedDiscoverySha256 = (Get-FileHash -LiteralPath $correctedDiscoveryPath -Algorithm SHA256).Hash.ToLowerInvariant()

$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Cannot resolve current repository commit"
}

$registry.registry_id = "vc01b-local-20260907-r9"
$registry.registry_status = "DRAFT"
$registry.registry_digest = $zero
$registry.implementation_authorized = $false
$registry.context.repository.current_commit = $currentCommit
$registry.context.implementation_plan_digest = $zero
$registry.context.leaf_task_id = $null
$registry.context.slice_id = $null
$registry.context.next_recommendation.candidate_leaf_task_id = "CCS-01-007"
$registry.context.next_recommendation.candidate_slice_id = "IMP-013"
$registry.context.next_recommendation.authorized = $false
$registry.context.next_recommendation.requires_new_authorization = $true
$registry.context.next_recommendation.reason = "Complete corrected discovery evidence is bound in reports/CCS-01-007_DISCOVERY_WORK_PACKET_V2.md; issue a separate ACTIVE local work packet under IMP-013 before implementation."
$registry.readiness.graph_validated = $false
$registry.readiness.owner_path_test_ownership_validated = $false
$registry.readiness.gate_closure_validated = $false
$registry.readiness.final_closure_leaf_id = $null
$registry.readiness.final_closure_complete = $false
$registry.readiness.report_path = "reports/CCS-01-007_DISCOVERY_REPAIR.md"
$registry.readiness.report_sha256 = $null
$registry.readiness.decision = "NOT_EVALUATED"

$leaf.in_scope = @(
    "Discovery-only planning for CCS-01-007 from 11_CODEX_TASKS/CCS-01_TASKS.md#L16.",
    "Normative ownership remains IMP-013; the complete local-only paths, interfaces, tests, completion criteria and stop conditions are bound by reports/CCS-01-007_DISCOVERY_WORK_PACKET_V2.md (SHA-256 $correctedDiscoverySha256).",
    "DISCOVERY BLOCKER [CCS-01-007]: issue a separate ACTIVE local work packet; this DRAFT registry grants no write or external observability authority."
)

$resolvedCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "RESOLVED" }).Count
$discoveryCount = @($registry.tasks | Where-Object { $_.path_resolution_status -eq "DISCOVERY_REQUIRED" }).Count
$report = @"
# CCS-01-007 Discovery Truncation Repair

Status: ``DRAFT / NOT AUTHORIZED``
Date: 2026-09-08

## Outcome

The original ``reports/CCS-01-007_DISCOVERY_WORK_PACKET.md`` is retained byte-identically as
historical evidence. It ends immediately after the heading that introduces unit-test obligations,
so its test list, traceability decision, verification commands, completion criteria, stop
conditions and authorization boundary are absent.

The complete successor is ``reports/CCS-01-007_DISCOVERY_WORK_PACKET_V2.md``. Immutable successor
r9 binds its exact digest while preserving the corrected ``IMP-013`` ownership from r8. r9 remains
``DRAFT / NOT_EVALUATED`` and ``implementation_authorized=false``.

| Item | Preserved source | Corrected successor |
|---|---|---|
| Registry | ``vc01b-local-20260907-r8`` | ``vc01b-local-20260907-r9`` |
| Discovery packet | truncated original | complete V2 at a new path |
| Parent | ``IMP-013`` | ``IMP-013`` |
| Leaf status | ``DISCOVERY_REQUIRED`` | ``DISCOVERY_REQUIRED`` |
| Path authority | deny all | deny all |

## Evidence bindings

| Evidence | SHA-256 |
|---|---|
| immutable r8 registry file | ``$r8Sha256`` |
| original truncated discovery packet | ``$originalDiscoverySha256`` |
| complete discovery packet V2 | ``$correctedDiscoverySha256`` |
| repository commit at generation | ``$currentCommit`` |

## Restored sections

- exact unit, integration and bootstrap test obligations;
- explicit non-invention decision for absent feature/invariant/canonical-test IDs;
- required leaf/full test, lint, format, strict type and whitespace verification commands;
- completion criteria for bounded local observability only;
- fail-closed stop conditions and separate ACTIVE authorization boundary.

## Preserved constraints

- r8 and the original truncated packet are never overwritten;
- r9 contains $($registry.tasks.Count) tasks: $resolvedCount ``RESOLVED`` and $discoveryCount ``DISCOVERY_REQUIRED``;
- ``CCS-01-007`` keeps empty allowed/create/modify paths and ``forbidden_paths=["**"]``;
- no product source, product test, dependency, database, migration, credential, listener, provider,
  external log sink, telemetry, deployment or publication action is changed or activated by this repair;
- r9 cannot authorize implementation.

## Reproduction

Run ``.codex/ccs/tools/New-R9CCS01007DiscoveryRepair.ps1`` from any PowerShell working directory.
The generator binds the exact r8 and original discovery SHA-256 values and refuses to overwrite any
V2/r9/repair-report output.
"@
[IO.File]::WriteAllText($reportPath, $report.TrimEnd([char[]]"`r`n") + "`n", [Text.UTF8Encoding]::new($false))
$registry.readiness.report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()

[IO.Directory]::CreateDirectory($r9Dir) | Out-Null
[IO.File]::WriteAllText($r9Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
$digest = (& $Python -I -B (Join-Path $SpecRoot "tools\artifact_digest.py") $r9Path --profile task-registry).Trim()
if ($LASTEXITCODE -ne 0 -or $digest -notmatch "^[0-9a-f]{64}$") {
    throw "Bad registry digest output: $digest"
}
$registry.registry_digest = $digest
$registry.context.implementation_plan_digest = $digest
[IO.File]::WriteAllText($r9Path, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))

$r8Sha256After = (Get-FileHash -LiteralPath $r8Path -Algorithm SHA256).Hash.ToLowerInvariant()
$originalDiscoverySha256After = (Get-FileHash -LiteralPath $originalDiscoveryPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($r8Sha256After -ne $expectedR8Sha256 -or $originalDiscoverySha256After -ne $expectedOriginalDiscoverySha256) {
    throw "Immutable source changed during r9 generation"
}

[pscustomobject]@{
    source_r8_sha256 = $r8Sha256
    original_discovery_sha256 = $originalDiscoverySha256
    corrected_discovery_path = $correctedDiscoveryPath
    corrected_discovery_sha256 = $correctedDiscoverySha256
    r9_path = $r9Path
    r9_registry_digest = $digest
    report_path = $reportPath
    report_sha256 = $registry.readiness.report_sha256
    resolved = $resolvedCount
    discovery_required = $discoveryCount
    implementation_authorized = $registry.implementation_authorized
} | Format-List
