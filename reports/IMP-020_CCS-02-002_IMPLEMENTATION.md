# IMP-020 / CCS-02-002 Implementation

Status: `IMPLEMENTED / LEAF TESTS PASS`

Implemented the frozen Project model, repository port, and SQLite adapter over the existing
`projects` table. Every read and write accepts and constrains the owning Workspace ID. Cross-
Workspace reads and mutations are returned as missing, without falling back to an unscoped query.

The model validates immutable identifiers, trimmed optional text, closed status values, UTC
timestamps, positive row versions, and a deterministic tuple-backed JSON platform array. The
repository provides create, scoped get/list, CAS update, and archive operations with typed
duplicate, missing, stale, and archived errors. It uses only caller-owned connections and never
commits or rolls back.

No schema, migration, external service, runtime database, provider, credential, deployment, or
publication change was made.

## Verification

Using the migrated Python 3.12.14 runtime with the repository's existing site-packages:

```text
pytest -p no:cacheprovider tests/unit/test_project_model.py \
  tests/repository/test_project_repository.py
18 passed in 1.95s
```

The repository-local virtual environment launcher still points to its pre-migration Python path,
so the equivalent command without an interpreter override cannot start. No environment file was
modified in this leaf.

## Known risk

Transaction boundaries and UTC clock values remain caller responsibilities by design.
