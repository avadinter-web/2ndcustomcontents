# IMP-022 / CCS-02-004 Content Core Implementation

Status: `IMPLEMENTED / LEAF TESTS PASS`

## Scope

Implemented the Content value model, repository port, application service and SQLite adapter over
the existing frozen `contents` table. All reads and writes are scoped by Workspace, and Project
association is checked only as `(workspace_id, project_id)`.

New Content is always created as `IDEA` with `current_version_id` and `archived_at` set to null
and `row_version=1`. The only update operation changes descriptive fields using exact row-version
CAS; it does not change Workspace, Project, status, archive state or current-version linkage.

Service writes use the existing `Action.CONTENT_EDIT` authorization and one caller-owned SQLite
unit of work. Repositories never commit. Missing and foreign Content/Project targets are concealed
behind the same safe Workspace denial at the service boundary.

## Explicit exclusions

No ContentVersion, current-version or approval lineage, state-transition command, migration,
schema, Asset, API/UI, provider, network, media, credential, runtime database, deployment or
publication operation was implemented or executed.

## Verification

```text
pytest -p no:cacheprovider tests/unit/test_content_model.py \
  tests/repository/test_content_repository.py tests/integration/test_content_service.py
20 passed in 2.71s
```

The test run used migrated Python 3.12.14 plus the repository's existing site-packages because
the repository-local virtual environment launcher still points to its pre-migration Python path.

## Residual risk

State transitions and version linkage intentionally remain unavailable until CCS-02-006 and
CCS-02-005 respectively.
