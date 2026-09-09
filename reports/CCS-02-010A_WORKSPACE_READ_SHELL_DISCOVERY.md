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
