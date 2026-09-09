# CCS-02-010B Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-010B
Parent: IMP-021
Predecessors: CCS-02-010, CCS-02-010A
Repository branch: master
Repository baseline: ec704b19d51ee92b7c51f5a5ff3aa708fa7a079c
Registry: vc01b-local-20260907-r23
Registry file SHA-256: 36876d8399255675b742cbed2c50c89b1020c43e3c56a331cf89c0d0946e75a6
Registry digest: 893d1039773244919b1939034d1b84da89e467fba0bf94ea12388cb9cfc837fd
Specification package digest: 7698bec8681ce5886e9e515c57e9d5e1f0997943460255ed65368fec93d24287
Change control: CHG-2026-0030
Discovery SHA-256: 41bb40297ab96ce40b199c1a21030220ace916db49ad9975d4c552a7ec13f5f0
Change-control SHA-256: 192249e8ff06c51ded5e9297a2799f327905e6a0739d88e88376fd153a63af79

## Authority

This packet authorizes one local, pure, framework-free standalone UI route-shell catalog attempt
against the exact r23 registry and master baseline above. The r23 registry remains DRAFT; this
packet and the paired LD00 record are the sole ACTIVE local authority. It does not activate r23,
register or select a route, render a page, add a UI framework, create a consumer, or authorize
API, repository, persistence, migration, dependency, external work, deployment, publication, or
any aggregate change.

## Exact allowlist

Create exactly these paths:

1. `reports/IMP-021_CCS-02-010B_IMPLEMENTATION.md`
2. `src/custom_content_studio/ui/route_shell.py`
3. `tests/contract/test_standalone_ui_route_shell.py`

Modify exactly this path:

4. `src/custom_content_studio/ui/__init__.py`

Any other implementation path is forbidden.

## Exact scope and verification

- Declare exactly four immutable, standalone route descriptors: Dashboard `/dashboard`; Projects
  `/workspaces/{workspace_id}/projects`; Content
  `/workspaces/{workspace_id}/projects/{project_id}/contents`; and Assets
  `/workspaces/{workspace_id}/assets`.
- Each descriptor must have a unique page key, its exact canonical template and `standalone=true`.
  Declare one shared bounded-layout policy: header, navigation and current action context remain in
  the viewport; exactly one internal work area may scroll or paginate; browser-document long-form
  scrolling is forbidden.
- The catalog is declarative only. It must not format URLs, inspect path parameters, select a route,
  load data, render a page, import a UI framework or API module, or access request/ActorContext,
  application, infrastructure, persistence or domain modules.
- Own `F-081`, introduce/run `T-021` under `INV-UI-ROUTE-001`, using only pure contract seams.
  `T-021` must prove the four exact templates, unique page keys, standalone flags and bounded-layout
  rule, including prohibited imports and absence of runtime/UI/API behavior.
- Run `pytest tests/contract/test_standalone_ui_route_shell.py`; then run applicable static and
  repository whitespace/path checks before any commit.

## Absolute prohibitions and stop conditions

- Do not add route registration, browser/UI rendering, Streamlit installation or use, CSS/DOM
  behavior, session/cache/request state, URL formatting/parsing/selection, identity/authorization,
  deep-link restoration, data/query/list/pagination, mutation, color/accessibility behavior, or
  Project/Content/Asset operations.
- Do not access API/resolver/repository/service/SQLite/UnitOfWork/domain aggregate, persistence,
  schema, migration, dependency, network, provider, credential, deployment, publication, or any
  external system.
- Do not modify `.env`, `.runtime/**`, `credentials/**`, `migrations/**`, `requirements.lock`,
  `src/custom_content_studio/api/**`, `src/custom_content_studio/application/**`,
  `src/custom_content_studio/infrastructure/**`, `src/custom_content_studio/persistence/**`,
  `src/custom_content_studio/domain/**`, or `tests/gates/**`.
- Stop with the r23 code when the registry/spec/evidence binding drifts, CCS-02-010 or CCS-02-010A
  acceptance is absent, runtime rendering/state/API access is needed, the packet becomes incomplete,
  or scope needs an unlisted path.
