# CCS-01-007 Discovery Work Packet

Status: `DRAFT / DISCOVERY COMPLETE / IMPLEMENTATION NOT AUTHORIZED BY R7`
Date: 2026-09-08
Canonical leaf: `CCS-01-007`
Canonical parent work package: `IMP-013`
Repository: `E:\\Custom_Contents_APP`
Repository baseline inspected: `c2b03c6e90ef51d3d1fa9d22cd1a90a1664865ad`
Authority profile: `LD00_DIRECT_USER_AUTHORIZATION` (local development only)

## 1. Decision and ownership correction

This packet resolves the local-only implementation boundary for structured process logs,
request correlation, safe startup diagnostics, liveness and readiness. The normative
`IMPLEMENTATION_REGISTRY.json` assigns these responsibilities to `IMP-013`, whose title is
"API, Streamlit UI and process health shells" and whose deliverables expressly include health
readiness endpoints and structured logging. `IMP-013` depends on `IMP-010` and `IMP-012`.

Registry r7 incorrectly assigns `CCS-01-007` to `IMP-012`. `IMP-012` owns authentication,
secret references and `ActorContext`; its implementation concluded at baseline `c2b03c6`. The
r7 entry is a non-executable discovery placeholder with no allowed paths,
`path_resolution_status=DISCOVERY_REQUIRED` and `implementation_authorized=false`. It therefore
cannot authorize implementation and must not override the normative implementation registry.
A successor immutable registry/work-packet revision must bind `CCS-01-007` to `IMP-013` before
code dispatch. r7 remains byte-identical and is not edited by this discovery task.

The existing dependency on `CCS-01-006` is correct. The later `CCS-01-008` gate remains dependent
on this leaf. No dependency edge is otherwise changed by this packet.

## 2. Normative evidence bindings

| Evidence | SHA-256 |
|---|---|
| r7 task registry | `3E9F6DE7301AC9D60E660B5E3BA7802F4A1ABBB07144D7876C7EC00DCC8E51C9` |
| specification `IMPLEMENTATION_REGISTRY.json` | `143A41BAB166F50ADEB888D6EEE74DE81AA18BA54559F6E0601A23C77F354D83` |
| specification `11_CODEX_TASKS/CCS-01_TASKS.md` | `7462E0ECA03F1531F56407AF2F23729C213D8E29CDA0C68B88533E170C1F5509` |
| specification `01_FOUNDATION/CCS-01_FOUNDATION.md` | `CA16AE21C502634A2D56769FBE830E1E36C3807415733A6A211F75A5E2F7D979` |
| specification `08_OPERATIONS/OPERATIONS_OBSERVABILITY_AND_RECOVERY.md` | `3CE1E469D87EBCC102A133CA5612A5E4B27CEC2343397F6C80CA1684110AA992` |

Normative interpretation:

- `CCS-01-007` is the foundation leaf named "Logging and health";
- `IMP-013` owns process health shells, readiness endpoints, structured logging and visible
  request correlation;
- logs carry safe correlation fields and never contain raw authorization headers, cookies,
  tokens, secret values, private media URLs or unbounded content;
- the foundation health surface reports only local process/startup readiness and must not claim
  provider, queue, worker-heartbeat, storage-integrity or business-workflow health;
- no distributed observability infrastructure is introduced.

## 3. Baseline observations

- `Settings` already freezes `log_level`, `log_format` and `environment`; PROD already requires
  JSON log format.
- `runtime_paths.py` already defines a profile-isolated local `logs` path without creating it.
- `domain.security.mask_sensitive` already provides the reusable recursive redaction primitive.
- `bootstrap()` loads the profile and validates repository/runtime scope without starting a
  listener or creating runtime paths.
- `GET /health` currently returns only `{\"status\": \"ok\"}` and proves liveness only.
- CLI `health` currently reports environment/runtime root/status; it does not distinguish live
  from ready or provide component diagnostics.
- API/UI/worker/scheduler entrypoints are deliberately side-effect-free composition shells.
- no observability package, request-correlation middleware, external log sink or metrics backend
  exists at the inspected baseline.

## 4. Exact future implementation allowlist

A future `CCS-01-007` implementation attempt may create exactly these files:

| Path | Sole responsibility |
|---|---|
| `src/custom_content_studio/observability/__init__.py` | Curated exports for local logging, correlation and startup health |
| `src/custom_content_studio/observability/logging.py` | Standard-library structured formatter, bounded context and local stream handler |
| `src/custom_content_studio/observability/health.py` | Immutable health/check models and side-effect-free startup readiness evaluation |
| `tests/unit/test_observability.py` | Formatting, correlation, masking, bounds and handler-isolation tests |
| `tests/integration/test_startup_health.py` | Local liveness/readiness, entrypoint and API/CLI contract tests |
| `reports/IMP-013_CCS-01-007_IMPLEMENTATION.md` | Exact delta, commands, results, hashes and review decision |

It may modify exactly these existing files:

| Path | Permitted change |
|---|---|
| `src/custom_content_studio/bootstrap/composition.py` | Compose health/logging dependencies without opening a listener, database or remote connection |
| `src/custom_content_studio/bootstrap/startup.py` | Return/emit one bounded local startup diagnostic through the composed observability service |
| `src/custom_content_studio/api/__init__.py` | Add generated request/correlation context and `/health/live`, `/health/ready`; preserve `/health` compatibility |
| `src/custom_content_studio/cli/__init__.py` | Make `health` return the common safe health document and nonzero on NOT_READY |
| `src/custom_content_studio/ui/__init__.py` | Identify the UI process to local startup diagnostics only; render no product page |
| `src/custom_content_studio/workers/runner.py` | Identify the worker process to local startup diagnostics only; claim no job |
| `src/custom_content_studio/scheduler/runner.py` | Identify the scheduler process to local startup diagnostics only; schedule no job |
| `tests/test_bootstrap.py` | Replace the minimal health assertion with shared entrypoint compatibility assertions |

`src/custom_content_studio/worker.py` remains an unchanged compatibility alias. Configuration
profiles, runtime path definitions, database/schema/migrations, session/security implementation,
UI pages, operation-event persistence, task registries and the specification package are not
writable in this leaf. No dependency or lockfile change is allowed.

## 5. Closed local observability contract

### 5.1 Correlation context

The implementation defines an immutable context with optional bounded identifiers:

```text
component: api | ui | worker | scheduler | cli | bootstrap
request_id: generated UUID string or None
correlation_id: generated UUID string or None
workspace_id: trusted ActorContext workspace or None
operation_id: trusted application-service operation ID or None
attempt: positive integer or None
error_code: stable safe code or None
```

The API generates a fresh `request_id` and `correlation_id` for every request at its trust
boundary. This leaf does not trust caller-supplied correlation headers. Both IDs are visible on
the response as bounded opaque identifiers and in the corresponding local log context. Later
authenticated application services may replace `workspace_id=None` only from `ActorContext`,
never from request JSON or an untrusted header.

Identifiers are printable, trimmed and bounded to 128 characters before entering a log record.
Arbitrary extra keys, arbitrary `LogRecord` attributes and unbounded payloads are rejected. A
context is passed explicitly; no mutable global/thread-local request identity is introduced.

### 5.2 Structured local logging

The logger uses only Python 3.12 standard-library `logging`. Configuration is idempotent for the
named `custom_content_studio` logger, installs exactly one owned `StreamHandler`, sets
`propagate=False`, applies the profile level/format and does not mutate unrelated/root handlers.
Its sink is process stderr (or an injected in-memory stream in tests). JSON mode emits one JSON
object per line; console mode emits one bounded key/value line. Both carry:

```text
timestamp_utc, level, environment, component, event, message,
request_id?, correlation_id?, workspace_id?, operation_id?, attempt, error_code?
```

Timestamps are timezone-aware UTC. Output ordering is deterministic for tests. `event` is a
bounded machine-readable name; `message` is a bounded safe summary, not an arbitrary exception,
request body, content document or provider response.

Every structured field passes through `domain.security.mask_sensitive` before formatting.
Fields whose names indicate authorization, cookie, token, secret, password, credential, API key,
access key, refresh or PKCE material are rendered `[REDACTED]`. The logger API does not accept raw
headers, cookies, request bodies, exception tracebacks or secret-store values. Formatting
failure emits a fixed safe fallback and never interpolates the rejected value.

No file/network/syslog/HTTP/OTLP/cloud handler, log shipper, telemetry SDK, metrics exporter or
external callback is created. Runtime `logs` directory creation, rotation, retention and CCS-12
search/indexing remain later operational work.

### 5.3 Startup health

Health has two distinct meanings:

- `LIVE`: the local process can serve the health function. It performs no file, database,
  provider, worker, scheduler or network probe.
- `READY`: configuration loaded, repository/runtime scope validation passed and normalized
  runtime paths remain inside the selected profile root.

The common immutable health document contains only:

```text
service = custom_content_studio
component
environment
status = LIVE | READY | NOT_READY
checks = [{name, status, diagnostic_code?}]
request_id? / correlation_id?
```

Check names are fixed to `configuration`, `scope` and `runtime_paths`. The public document never
contains repository/runtime paths, configuration values, exception text, traceback, secret
reference, user/account identifiers or resource existence details. Failures use bounded local
diagnostic codes `CONFIGURATION_INVALID`, `SCOPE_INVALID` or `RUNTIME_PATHS_INVALID`; the safe
document does not add or replace a domain error-catalog contract.

`GET /health/live` returns HTTP 200 and `LIVE`. `GET /health/ready` returns HTTP 200 for `READY`
and HTTP 503 for `NOT_READY`. Existing `GET /health` remains a compatibility alias of the safe
readiness document. CLI `health` prints the same JSON schema, exits 0 for READY and nonzero for
NOT_READY. API imports and route registration remain free of startup writes; readiness evaluates
only the local pure checks above.

A successful process-shell startup emits one `startup.ready` local record. A failed safe check
may emit one `startup.not_ready` record with its diagnostic code before returning/raising through
the existing process contract. Repeated health requests do not accumulate handlers.

## 6. Explicit exclusions

This leaf does not:

- open, create, migrate or mutate the application/runtime database;
- inspect or mutate real credentials, `.env`, account permissions or OS credential stores;
- call providers, external identity systems, webhooks or any non-loopback service;
- start an API/UI listener, worker claim loop, scheduler or publishing/rendering action in tests;
- implement Worker/Queue/Provider/Storage health, operation events, audit persistence, metrics,
  Control Center, Action Inbox, restore-safe mode, retry/reconcile/cancel actions or log retention;
- claim `GET /operations/health` or any CCS-12 acceptance scenario;
- persist request/correlation context as authoritative business state;
- accept external log shipping, telemetry, tracing or monitoring SDKs.

External log shipping is `FORBIDDEN`, not merely unconfigured. A future external sink requires a
separate adapter contract, data-classification review, credential authority and explicit leaf.

## 7. Exact owned tests and traceability

`tests/unit/test_observability.py` must prove:
