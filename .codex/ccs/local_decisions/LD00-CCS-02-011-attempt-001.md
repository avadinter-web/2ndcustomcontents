# LD00 — CCS-02-011 attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL FRESH-TEMPORARY-SQLITE CORE PERSISTENCE/RESTART GATE SCOPE
Date: 2026-09-09
Leaf/parent: CCS-02-011 / IMP-022
Predecessors: CCS-02-010; semantic predecessors CCS-02-003/004/005/006
Repository branch: master
Repository baseline: 43fdada076d1af4b7e36296a35571298a66ba051
Registry: vc01b-local-20260907-r24 (DRAFT; not activated)
Registry file SHA-256: 218d23f6304f988d788a185af4815b9935bd70dfe9941ff20b5a3dc82c9f3fc0
Registry digest: 21335f0440ded952ad0a8b5e538908eda599146dace7485eb47e7dbed233568a
Specification package digest: 000ae438fdb6dfd15e0ac302e36196d5e4322ef5f8cd18ad015aec79b1cefa0a
Change control: CHG-2026-0031
Discovery SHA-256: 4237c2bd3c0a83b90b5aa9e0fa23a26e48739cf66e7960e1fdc7357d3690c118
Change-control SHA-256: edd8a3172e8a5b95ac201ad858e7bbd59461a2f351b0221249f91602d84a16e5

The serial local authority approves only these two r24 allowlisted creates:
`reports/IMP-022_CCS-02-011_IMPLEMENTATION.md` and `tests/gates/test_ccs02_gate.py`.
The attempt owns `F-003`/`F-004`/`F-005`/`F-006` and
`T-011`/`T-013`/`T-014`/`T-015`/`T-016`/`T-017`/`T-INT-031`/`T-INT-050` under
`INV-WS-001` and `INV-IMM-001` for a fresh-temporary-SQLite restart-bound gate.

The gate alone may create a fresh temporary SQLite database, run the existing migration path, seed
a legal two-Workspace fixture, commit, create a new `SQLiteConnectionFactory`, and reopen that same
database. It must prove durable Workspace, Project, Asset, Content, ContentVersion, authoring
head, status and row-version state; FK and unique integrity; stale-CAS rejection with no partial or
orphan rows; the exact Content-state boundary; rejected ContentVersion deletion; and concealed or
denied cross-Workspace access.

Product source, schema, migration, configuration, dependency, runtime database, API/UI, F-079/F-080
helpers, provider/network, credentials, deployment, publication, external effects and every path
outside the exact r24 allowlist are expressly denied. Any registry/spec/evidence drift, missing
CCS-02-010 or semantic predecessor acceptance, need for a product edit or non-temporary database,
omitted packet binding or scope expansion invalidates this decision and stops the attempt.
