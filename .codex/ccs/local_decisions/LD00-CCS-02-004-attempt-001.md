# LD00 — CCS-02-004 attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL CONTENT-MODEL SCOPE
Date: 2026-09-09
Leaf/parent: CCS-02-004 / IMP-022
Predecessor: CCS-02-003
Repository branch: master
Repository baseline: 2650c55a91ca22b817aa391a0aeefc5b80172d8d
Registry: vc01b-local-20260907-r15
Registry file SHA-256: fdc860cf70849c92252c25b4ca9437131e925205488be987ff6dfb457249ec79
Registry digest: 52bbf26225e2c5e6af52cf035af57facb846b8ac2b0ac6b93cca5ca5af5954a6

The serial local authority approves only the eight create and five modify paths copied verbatim
into `CCS-02-004-attempt-001.md`. The attempt owns the Content subset of F-004, the closed
persisted-state vocabulary subset of F-005, INV-WS-001 and T-015, with T-011/T-017/T-INT-050
regression ownership exactly as bound by r15. Local tests may create disposable SQLite data solely
under pytest `tmp_path`.

ContentVersion/current-version/approval work, transition execution, migration/schema/manifest
edits, credentials, provider/network/media operations, runtime or production databases, Asset,
API/UI, dependency changes, deployment, publication and every external effect are expressly
denied. A requirement for any denied operation invalidates this decision and stops the attempt; it
does not authorize scope expansion.
