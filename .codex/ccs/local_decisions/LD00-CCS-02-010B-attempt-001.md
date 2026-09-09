# LD00 — CCS-02-010B attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL DECLARATIVE STANDALONE UI ROUTE-SHELL SCOPE
Date: 2026-09-09
Leaf/parent: CCS-02-010B / IMP-021
Predecessors: CCS-02-010, CCS-02-010A
Repository branch: master
Repository baseline: ec704b19d51ee92b7c51f5a5ff3aa708fa7a079c
Registry: vc01b-local-20260907-r23 (DRAFT; not activated)
Registry file SHA-256: 36876d8399255675b742cbed2c50c89b1020c43e3c56a331cf89c0d0946e75a6
Registry digest: 893d1039773244919b1939034d1b84da89e467fba0bf94ea12388cb9cfc837fd
Specification package digest: 7698bec8681ce5886e9e515c57e9d5e1f0997943460255ed65368fec93d24287
Change control: CHG-2026-0030
Discovery SHA-256: 41bb40297ab96ce40b199c1a21030220ace916db49ad9975d4c552a7ec13f5f0
Change-control SHA-256: 192249e8ff06c51ded5e9297a2799f327905e6a0739d88e88376fd153a63af79

The serial local authority approves only the four r23 allowlisted paths copied verbatim into
`CCS-02-010B-attempt-001.md`: three creates and one modification. The attempt owns `F-081` and
`T-021` under `INV-UI-ROUTE-001` for the pure, declarative standalone UI route-shell catalog.

The catalog declares exactly Dashboard `/dashboard`, Projects
`/workspaces/{workspace_id}/projects`, Content
`/workspaces/{workspace_id}/projects/{project_id}/contents`, and Assets
`/workspaces/{workspace_id}/assets`. Every descriptor has a unique page key, exact canonical
template and `standalone=true`. One shared bounded-layout policy keeps header, navigation and
current action context in the viewport while exactly one internal work area may scroll or paginate;
browser-document long-form scrolling is forbidden.

The catalog does not format URLs, inspect path parameters, select routes, load data or render
pages. UI runtime/framework, CSS/DOM, browser/session/request/cache state, API/resolver,
repository/service/aggregate access, identity/authorization, query/pagination, mutation,
persistence/schema/migration/dependency changes, credentials, secrets, network/provider/media
operations, deployment, publication, external effects and every path outside the exact r23
allowlist are expressly denied. Any registry/spec/evidence drift, missing CCS-02-010 or
CCS-02-010A acceptance, runtime rendering/state/API requirement, omitted packet binding or scope
expansion invalidates this decision and stops the attempt.
