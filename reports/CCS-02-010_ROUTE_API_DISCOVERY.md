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
