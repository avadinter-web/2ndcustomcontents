# Local Direct Authorization Protocol

Status: `APPROVED / LOCAL DEVELOPMENT ONLY`

## Purpose

`LD00_DIRECT_USER_AUTHORIZATION` is the repository-local authorization path selected by the user
for this Codex conversation. It permits bounded local implementation attempts when the managed
trusted-dispatcher plane is intentionally unavailable. It does not create a trusted-host receipt
and does not alter the immutable task registry.

understood as: the active user decision authorizes serial local leaves that follow the frozen
design order, provided every leaf receives its own attempt-scoped packet, preflight, verification,
commit and push. The authorization excludes all external or production actions listed below.

## Required sequence

1. Astra presents the exact canonical leaf, parent `IMP-*`, allowed paths, excluded actions,
   verification commands, risks and completion criteria.
2. The user explicitly approves either that presented leaf or a bounded serial local-leaf scope in
   the active conversation. A serial scope must name its excluded action classes and the frozen
   design order it follows.
3. The orchestrator creates a new attempt-scoped local work packet and a local decision record.
   They reference the unchanged frozen registry revision and record the user decision locator.
4. Exactly one implementer writes only the packet allowlist. Before mutation it rechecks LD-00,
   VC-01, VC-01B, VC-02 and the current Git baseline.
5. Astra independently verifies the exact changed paths and required tests. A successful unit is
   committed and pushed to the configured Git remote under the user's standing delivery policy.

## Hard boundaries

- A single-leaf decision authorizes one leaf and one attempt only. A serial local-leaf decision
  authorizes only the next eligible leaf in the frozen design order at a time; every attempt must
  still have a fresh packet, preflight, verification, commit and push. It never authorizes a leaf
  outside that order or an action class excluded by the serial decision.
- The label is not `ACTIVE`, `ACCEPTED`, host-injected, signed, MDM-managed, or production-safe.
- It permits only local code, tests, local development data and local media-tool validation.
- It forbids deployment, publishing, remote updates, external transmission, credential/API-key
  changes, billing, production migrations, destructive operations and external provider actions.

## Autonomous delivery continuity

For an active serial local-leaf decision, a leaf completion report is an internal checkpoint, not a
terminal orchestration event. The orchestrator must, in the same active delivery flow:

1. independently verify the exact changed paths, leaf tests, static checks and whitespace;
2. commit and push a passing bounded leaf under the standing delivery policy;
3. dispatch the next frozen-design discovery, successor resolution, packet or implementation step;
4. inspect the dispatched work's actual state before reporting it as running.

The orchestrator must never describe a queued instruction, prepared packet or completed worker as
an active implementation. If a dispatched worker reports no state change across two checks, stop
it, inspect the working tree directly and continue or report the concrete blocker. A final user
message may summarize a completed milestone, but does not end the serial delivery flow.
- If the frozen registry, required gate evidence, path ownership, work-packet contents or Git
  baseline disagrees with the presented scope, stop with `LOCAL_DEVELOPMENT_GATE_MISMATCH` or
  `TASK_ENVELOPE_INCOMPLETE`; do not infer approval from a prior leaf.

## Re-entry to managed delivery

Before any CI/CD connection, public release, remote update, real content publication, shared
writer workflow, external integration mutation or production deployment, this protocol stops.
The managed deployment handoff and the package's trusted-dispatcher boundary must be reactivated
with their independently verifiable evidence and a separate user approval.
