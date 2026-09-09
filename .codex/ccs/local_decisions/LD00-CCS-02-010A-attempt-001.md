# LD00 — CCS-02-010A attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL READ-ONLY WORKSPACE API SHELL SCOPE
Date: 2026-09-09
Leaf/parent: CCS-02-010A / IMP-021
Predecessor: CCS-02-010
Repository branch: master
Repository baseline: 4362c066d5cc528dc7e13847fd97fadbfce6355c
Registry: vc01b-local-20260907-r22 (DRAFT; not activated)
Registry file SHA-256: 4335979f1bc6868b432ef6da230a8205a5b835a0c21414b313065922233cc04b
Registry digest: 93ac4e5a8768b65a44e67df0d305b8f01750f54f5e9218d15b3eb3e1a23a9e71
Specification package digest: cf9fa040ab51c3086f3ccd43035ad0478d70a33b23401b48085871e1cb7edbae
Change control: CHG-2026-0029
Discovery SHA-256: 548d44ac544928c424ab4c9a5cc64df040c6d6fbbb3d23d47e93818b5640afa1
Change-control SHA-256: 9111c8928034041e3817a0644886e4fef0b948aef45fcb2aa0e6d4d6dfb5d15b

The serial local authority approves only the four r22 allowlisted paths copied verbatim into
`CCS-02-010A-attempt-001.md`: three creates and one modification. The attempt owns `F-081` and
`T-021` under `INV-UI-ROUTE-001` for the one injected-resolver Workspace read shell.

The URL workspace ID, mandatory `X-Workspace-Id`, and existing `ActorContext.workspace_id` must be
present and exactly equal before the existing Workspace read policy and resolver are reached.
Mismatch, missing header, policy denial, cross-Workspace reference, and resolver absence must use
the indistinguishable 404 `WORKSPACE_NOT_FOUND` envelope, and a resolver must never run on failure.
The resolver accepts validated identity plus `ActorContext` and returns only a safe projection or
absence; no credential parsing, direct repository access, or aggregate data is allowed.

Mutation, list/pagination/query, cache, UI/browser/dashboard, Project/Content/Asset scope,
repository/service/SQLite/UnitOfWork/domain/persistence/schema/migration/dependency changes,
credentials, secrets, network/provider/media operations, deployment, publication, external effects,
and every path outside the exact r22 allowlist are expressly denied. Any registry/spec/evidence
drift, missing CCS-02-010 acceptance, direct retrieval or storage requirement, omitted packet
binding, or scope expansion invalidates this decision and stops the attempt.
