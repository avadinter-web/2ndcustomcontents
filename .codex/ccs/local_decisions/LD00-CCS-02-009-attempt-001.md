# LD00 — CCS-02-009 attempt-001 Local Execution Decision

Decision: APPROVED FOR EXACT LOCAL LOSSLESS EDITABLE-TEXT SAFETY-POLICY SCOPE
Date: 2026-09-09
Leaf/parent: CCS-02-009 / IMP-022
Predecessor: CCS-02-008
Repository branch: master
Repository baseline: 1c623fbd89a2bde71d8b745250c665a821c4cc08
Registry: vc01b-local-20260907-r20 (DRAFT; not activated)
Registry file SHA-256: 4464a89837c7969694eb07777a135c9771b825bcbf4976af5b4e059e7a103c4d
Registry digest: 23fb0bd64445ef7e93f1656a75ff0f47631dd017362902973efd5e3505ff789a
Specification package digest: bc94e6ef58920ea575e7e2d8e7cfac9b8c4289b96bdc447bd6a851da59957197
Change control: CHG-2026-0027
Discovery SHA-256: 4fe7108d235537eb5b43dada69ba24ac633f67a611e9c885f37c1c64d21abe7a
Change-control SHA-256: cb289af891d9acc6684ce60404790635f39da3d88df3bde413c37d10bb40973e

The serial local authority approves only the four r20 allowlisted paths copied verbatim into
`CCS-02-009-attempt-001.md`: three creates and one modification. The attempt owns `F-080` and
`T-020` under `INV-TEXT-001` for the pure lossless `normalize_editable_text` policy.

The policy must preserve None/empty distinction, valid Unicode, and original LF/CR/CRLF exactly;
it must not perform normalization-form, case, whitespace, escaping, sanitization, or line-ending
rewrites. It may accept no more than 10,000 Python code points and must use the stable
`DOMAIN_VALIDATION_FAILED` contract for non-string non-None values, lone surrogates, disallowed
controls, and oversized inputs.

CCS-07 remains a future consumer and is denied ownership transfer. Review persistence, aggregates,
Content/ContentVersion mutation, rendering, HTML sanitization, serialization, storage, migrations,
database work, API/UI, credentials, secrets, providers, network/media operations, dependencies,
deployment, publication, external effects, and every path outside the exact r20 allowlist are
expressly denied. Any registry/spec/evidence drift, missing CCS-02-008 acceptance, storage or
migration requirement, omitted packet binding, text-rewrite requirement, or scope expansion
invalidates this decision and stops the attempt.
