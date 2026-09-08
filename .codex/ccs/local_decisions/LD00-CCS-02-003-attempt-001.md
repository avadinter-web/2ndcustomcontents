# LD00 — CCS-02-003 attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL ASSET-REGISTRY SCOPE
Date: 2026-09-08
Leaf/parent: CCS-02-003 / IMP-021
Predecessor: CCS-02-002
Repository baseline: 6fc416aecdc814117eb916e87f46a728d089c8a9
Registry: vc01b-local-20260907-r14
Registry digest: 7a6bd34d414ff31db8d815726ac91cd2817cd65f92b84f268b08c4dfc9a38a9b

The serial local authority approves only the eight create and five modify paths copied verbatim
into `CCS-02-003-attempt-001.md`. Local tests may create disposable SQLite data solely under
pytest `tmp_path`.

Migration/schema edits, provider/network/storage/media operations, credentials, runtime or
production databases, API/UI work, dependency changes, deployment, publication and every external
effect are expressly denied. A requirement for any denied operation invalidates this decision
and stops the attempt; it does not authorize scope expansion.
