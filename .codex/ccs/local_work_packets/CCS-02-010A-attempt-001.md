# CCS-02-010A Local Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-09
Leaf: CCS-02-010A
Parent: IMP-021
Predecessor: CCS-02-010
Repository branch: master
Repository baseline: 4362c066d5cc528dc7e13847fd97fadbfce6355c
Registry: vc01b-local-20260907-r22
Registry file SHA-256: 4335979f1bc6868b432ef6da230a8205a5b835a0c21414b313065922233cc04b
Registry digest: 93ac4e5a8768b65a44e67df0d305b8f01750f54f5e9218d15b3eb3e1a23a9e71
Specification package digest: cf9fa040ab51c3086f3ccd43035ad0478d70a33b23401b48085871e1cb7edbae
Change control: CHG-2026-0029
Discovery SHA-256: 548d44ac544928c424ab4c9a5cc64df040c6d6fbbb3d23d47e93818b5640afa1
Change-control SHA-256: 9111c8928034041e3817a0644886e4fef0b948aef45fcb2aa0e6d4d6dfb5d15b

## Authority

This packet authorizes one local, injected-resolver, read-only Workspace API shell attempt against
the exact r22 registry and master baseline above. The r22 registry remains DRAFT; this packet and
the paired LD00 record are the sole ACTIVE local authority. It does not activate r22, add another
route, create a consumer, or authorize direct repository access, persistence, migration, dependency,
external work, deployment, publication, or any aggregate change.

## Exact allowlist

Create exactly these paths:

1. `reports/IMP-021_CCS-02-010A_IMPLEMENTATION.md`
2. `src/custom_content_studio/api/workspace_read_shell.py`
3. `tests/contract/test_workspace_read_shell.py`

Modify exactly this path:

4. `src/custom_content_studio/api/__init__.py`

Any other implementation path is forbidden.

## Exact scope and verification

- Expose only GET `/api/v1/workspaces/{workspace_id}` through one injected resolver. Before that
  resolver runs, URL `workspace_id`, required `X-Workspace-Id`, and existing
  `ActorContext.workspace_id` must be present and byte-for-byte equal, and the existing Workspace
  read policy must pass.
- The shell must neither parse credentials nor change `ActorContext`. `WorkspaceReadResolver` is the
  sole retrieval seam and receives validated identity plus `ActorContext`; it returns only a safe API
  projection or absence. It must not receive or return a repository or aggregate object.
- Missing or mismatched identity, policy denial, cross-Workspace reference, and resolver absence
  must all return the same 404 envelope with code `WORKSPACE_NOT_FOUND`. Do not expose existence,
  label, status, breadcrumb, count, cache, authorization, or timing-derived details, and do not call
  the resolver before preconditions pass.
- Own `F-081`, introduce/run `T-021` under `INV-UI-ROUTE-001`, using only fake-injected contract
  seams. `T-021` must prove same-Workspace retrieval, URL/header/ActorContext agreement, policy
  denial and absence indistinguishability, resolver non-invocation on every failure, and absence of
  mutation or pagination behavior.
- Run `pytest tests/contract/test_workspace_read_shell.py`; then run applicable static and repository
  whitespace/path checks before any commit.

## Absolute prohibitions and stop conditions

- Do not add mutation, list, pagination, cursor, limit, count, search, filter, sort, cache, UI,
  browser/dashboard, Project, Content, or Asset behavior.
- Do not access repository, service, SQLite, UnitOfWork, domain aggregate, persistence, schema,
  migration, dependency, network, provider, credential, deployment, publication, or external system.
- Do not modify `.env`, `.runtime/**`, `credentials/**`, `migrations/**`, `requirements.lock`,
  `src/custom_content_studio/ui/**`, `src/custom_content_studio/application/**`,
  `src/custom_content_studio/infrastructure/**`, `src/custom_content_studio/persistence/**`,
  `src/custom_content_studio/domain/**`, or `tests/gates/**`.
- Stop with the r22 code when the registry/spec/evidence binding drifts, CCS-02-010 acceptance is
  absent, direct retrieval/persistence/migration is needed, the packet becomes incomplete, or scope
  needs an unlisted path.
