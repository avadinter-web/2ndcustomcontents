# IMP-021 — CCS-02-010A Workspace API Read Shell

Status: IMPLEMENTED / LOCAL-ONLY / READ-ONLY
Date: 2026-09-09
Traceability: F-081 / T-021 / INV-UI-ROUTE-001

The bounded shell exposes only the injected-resolver Workspace read path. URL workspace identity,
the required `X-Workspace-Id`, and the pre-existing `ActorContext.workspace_id` must agree before
the Workspace read policy and resolver execute. The resolver accepts only validated identity plus
the supplied actor and returns `WorkspaceReadProjection` or absence.

Every identity/precondition failure, policy denial, cross-Workspace projection, and absence returns
the identical `404 {"code":"WORKSPACE_NOT_FOUND"}` response. The shell has no mutation, list,
pagination, cache, direct repository, persistence, migration, credential, UI, or external behavior.

Verification is defined by `tests/contract/test_workspace_read_shell.py` (T-021) plus repository
formatting, lint, type and whitespace checks.
