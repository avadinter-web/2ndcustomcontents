# IMP-021 / CCS-02-003 Asset Registry Implementation

Status: `IMPLEMENTED / LEAF TESTS PASS`

## Scope

Implemented the metadata-only Asset domain model, repository port, application service and SQLite
adapter over the existing frozen `assets` table. No migration or schema file changed. The code
never accesses Asset bytes, local storage, providers, network services, media tools, credentials,
or runtime databases.

## Contract

- Closed Asset type, storage provider and status enums match the frozen schema.
- AVAILABLE assets require a lowercase 64-hex SHA-256; size is nullable and non-negative;
  metadata is a deterministic JSON object.
- Optional Project association is resolved only by `(workspace_id, project_id)` and rejects
  absent, archived or foreign Projects without revealing cross-Workspace records.
- Asset get/list/update SQL always includes Workspace scope. Update uses exact `row_version` CAS
  and increments once.
- The adapter never updates the physical identity fields of an AVAILABLE Asset. Replacement
  requires a new Asset registration.
- Service writes use only the existing `Action.CONTENT_EDIT` authorization contract and a single
  caller-owned SQLite unit of work.

## Verification

```text
pytest -p no:cacheprovider tests/unit/test_asset_model.py \
  tests/repository/test_asset_repository.py tests/integration/test_asset_service.py
23 passed in 9.45s
```

The test run used migrated Python 3.12.14 plus the repository's existing site-packages because
the repository-local virtual environment launcher still points to its pre-migration Python path.

## Residual risk

This leaf registers caller-supplied storage references and checksums but deliberately does not
verify bytes or provider state. Those operations remain owned by later IMP-021 leaves.
