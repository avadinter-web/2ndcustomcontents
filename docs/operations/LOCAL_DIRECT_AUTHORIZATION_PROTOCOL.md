# Local Direct Authorization Protocol

Status: `APPROVED / LOCAL DEVELOPMENT ONLY`

## Purpose

`LD00_DIRECT_USER_AUTHORIZATION` is the repository-local authorization path selected by the user
for this Codex conversation. It permits one bounded local implementation attempt when the
managed trusted-dispatcher plane is intentionally unavailable. It does not create a trusted-host
receipt and does not alter the immutable task registry.

## Required sequence

1. Astra presents the exact canonical leaf, parent `IMP-*`, allowed paths, excluded actions,
   verification commands, risks and completion criteria.
2. The user explicitly approves that presented leaf in the active conversation.
3. The orchestrator creates a new attempt-scoped local work packet and a local decision record.
   They reference the unchanged frozen registry revision and record the user decision locator.
4. Exactly one implementer writes only the packet allowlist. Before mutation it rechecks LD-00,
   VC-01, VC-01B, VC-02 and the current Git baseline.
5. Astra independently verifies the exact changed paths and required tests. A successful unit is
   committed and pushed to the configured Git remote under the user's standing delivery policy.

## Hard boundaries

- Each decision authorizes one leaf and one attempt only. It never authorizes a successor.
- The label is not `ACTIVE`, `ACCEPTED`, host-injected, signed, MDM-managed, or production-safe.
- It permits only local code, tests, local development data and local media-tool validation.
- It forbids deployment, publishing, remote updates, external transmission, credential/API-key
  changes, billing, production migrations, destructive operations and external provider actions.
- If the frozen registry, required gate evidence, path ownership, work-packet contents or Git
  baseline disagrees with the presented scope, stop with `LOCAL_DEVELOPMENT_GATE_MISMATCH` or
  `TASK_ENVELOPE_INCOMPLETE`; do not infer approval from a prior leaf.

## Re-entry to managed delivery

Before any CI/CD connection, public release, remote update, real content publication, shared
writer workflow, external integration mutation or production deployment, this protocol stops.
The managed deployment handoff and the package's trusted-dispatcher boundary must be reactivated
with their independently verifiable evidence and a separate user approval.
