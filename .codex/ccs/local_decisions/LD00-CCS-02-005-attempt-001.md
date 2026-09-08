# LD00 — CCS-02-005 attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL CONTENT-VERSION SCOPE
Date: 2026-09-09
Leaf/parent: CCS-02-005 / IMP-022
Predecessor: CCS-02-004
Repository branch: master
Repository baseline: b094cd590de0abb2b464cb5e74b1353c2101005f
Registry: vc01b-local-20260907-r16
Registry file SHA-256: 7fa3621fd8aeb72a627855eabd8ec288c76f012b14f5daa714e2e11d4b8547d4
Registry digest: 62bd1c4b91fc867786c51797fb983c057edaa3c48149fcc377d06df579160645
Specification package digest: cf7fbc99b83f3a258b5c6794df777c10fba4c945a5fffc76791d5bad951c5e1c
Change control: CHG-2026-0023

The serial local authority approves only the eight create and nine modify paths copied verbatim
into `CCS-02-005-attempt-001.md`. The attempt owns the CHG-2026-0023 F-004/F-005 ContentVersion
subset, INV-IMM-001/INV-WS-001 and T-014/T-INT-031, with T-011/T-017/T-INT-031 regression
ownership exactly as bound by r16. Creation is USER-only. Local tests may create disposable
SQLite data solely under pytest `tmp_path`.

Approval lineage or transitions, Content status transitions, ServiceAccount or null-creator
creation, migration/schema/manifest/trigger/backfill edits, credentials, provider/network/media
operations, runtime or production databases, Asset, API/UI, dependency changes, deployment,
publication and every external effect are expressly denied. A requirement for any denied
operation or any path outside the exact r16 allowlist invalidates this decision and stops the
attempt; it does not authorize scope expansion.
