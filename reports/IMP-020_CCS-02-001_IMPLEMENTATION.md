# IMP-020 / CCS-02-001 Implementation

Status: `IMPLEMENTED / LOCAL VERIFICATION PENDING`

## Scope

Implemented the immutable Workspace domain model, repository port, and SQLite adapter over the
existing `workspaces` table. The adapter uses only caller-owned connections and never commits or
rolls back. No schema, migration, provider, network, runtime database, or external-service change
was made.

## Behavior

- Validates trimmed identity/name, IANA timezone, JSON-object settings, UTC timestamps, and a
  positive row version.
- Supports create, get-by-id, deterministic active listing, row-version CAS update, and archive.
- Excludes archived rows from active listing and rejects later update/archive operations.
- Maps duplicate, missing, stale, and archived outcomes to typed repository errors.

## Verification

Pending final command results.

## Known risks

The repository intentionally exposes no automatic retry or transaction ownership. Callers must
choose transaction boundaries and provide deterministic UTC timestamps.
