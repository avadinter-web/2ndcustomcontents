# IMP-021 — CCS-02-010B Standalone UI Route Shell

Status: IMPLEMENTED / LOCAL-ONLY / DECLARATIVE
Date: 2026-09-09
Traceability: F-081 / T-021 / INV-UI-ROUTE-001

The route-shell catalog defines only four immutable, standalone canonical destinations: Dashboard,
Projects, Content, and Assets. Every descriptor has a unique page key, exact template, and a true
standalone flag.

The one shared bounded-layout policy keeps header, navigation, and current action context in the
viewport. Exactly one internal work area may scroll or paginate; browser-document long-form
scrolling is forbidden.

No route registration or selection, URL formatting or inspection, UI runtime or rendering, request
or session state, API/data access, identity, authorization, mutation, persistence, migration, or
external behavior is included. `tests/contract/test_standalone_ui_route_shell.py` verifies the
declarative contract and import boundary.
