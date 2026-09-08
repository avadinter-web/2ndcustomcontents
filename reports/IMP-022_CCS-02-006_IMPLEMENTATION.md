# IMP-022 / CCS-02-006 Implementation Report

## Scope

Implemented only Content `IDEA -> ACTIVE -> ARCHIVED` and ContentVersion
`DRAFT -> REVIEW_REQUIRED`, with USER `CONTENT_EDIT`, Workspace concealment, exact source-state and
row-version CAS, caller-owned transactions, and canonical invalid-transition errors.

Activation requires the exact current DRAFT authoring head. Archive writes matching strictly
advancing update/archive timestamps. Review submission changes only status and row version while
preserving immutable snapshot identity and approval columns.

Approval, revision, rejection, supersession, review/timeline lineage, migrations, dependencies,
runtime databases and external effects remain excluded.

## Verification

- Leaf pytest: 6 passed.
- Ruff check and format check: passed.
- mypy for the four new source modules: passed.
- Git diff whitespace check: passed.
