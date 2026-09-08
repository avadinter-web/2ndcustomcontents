# IMP-022 / CCS-02-005 Implementation Report

## Scope

Implemented the local ContentVersion model, normalized snapshot identity, Workspace-scoped SQLite repository, USER-only creation service, and Content authoring-head compare-and-swap. No approval lineage, status-transition command, service-account authoring, migration, network/provider work, or external side effect was added.

## Contract implementation

- Validates and deeply freezes the registered `ccs.content-version-snapshot` v1 envelope.
- Persists RFC 8785-style canonical JSON projections and hashes the exact Content ID, envelope, and positive version number identity.
- Creates DRAFT versions with the authenticated USER as `created_by`.
- Allocates monotonic per-Content numbers and requires the exact current head as parent.
- Inserts the immutable version and advances `contents.current_version_id` with Workspace, row-version, and prior-head predicates in one caller-owned `BEGIN IMMEDIATE` unit of work.
- Widens the Content read model only enough to load and preserve the linked current head.
- Exposes Workspace-scoped version reads and relies on the existing schema trigger to reject deletion.

## Verification

Leaf unit, repository, and integration tests cover canonical identity, frozen values, scoped reads, monotonic lineage, old-version preservation, USER-only authoring, stale-CAS rollback without orphans, caller-owned commit behavior, and deletion rejection.
