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
