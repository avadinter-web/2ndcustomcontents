# CCS-01-008 Local Gate Work Packet — attempt-001

Status: ACTIVE / LOCAL-ONLY / EXACT-SCOPE
Date: 2026-09-08
Leaf: CCS-01-008
Parent: IMP-013
Predecessor: CCS-01-010
Repository commit: 44df95d8be33a277c7a689cf9acd56e66904b5d6
Registry: vc01b-local-20260907-r13
Registry file SHA-256: 437e2e138299f0af078937da085f5b08ad32b513dd1beecb76ca88519da7a4a5
Registry digest: 906fdbe838f1733013581afa2e0bf4e1143116a686bc51b949fb71d5403f0eb4
Specification package digest: 89efb68b94955e8863f50814aeb9f71827e2722e1395dc3cd14899321c5d4278

## Authority and exact outputs

The user's standing authorization for local leaf implementation authorizes this one attempt. It
does not authorize external, credential, deployment, publication, DEV/STAGING/runtime database or
production actions. The only repository outputs are:

1. `.codex/ccs/local_work_packets/CCS-01-008-attempt-001.md`
2. `.codex/ccs/local_decisions/LD00-CCS-01-008-attempt-001.md`
3. `tests/gates/test_ccs01_gate.py`
4. `reports/IMP-013_CCS-01-008_GATE_EVIDENCE.md`

There are no existing-file modify paths. Pre-existing unrelated dirty files are preserved and
excluded from the result.

## Test ownership

- Introduces: T-003, T-004, T-ENV-004.
- Must pass: T-001, T-002, T-003, T-004, T-ENV-001, T-ENV-002, T-ENV-003,
  T-ENV-004, T-INT-092, T-INT-093, T-INT-137, T-INT-138.
- Gate regression set: T-001, T-002, T-ENV-001, T-ENV-002, T-ENV-003, T-INT-092,
  T-INT-093, T-INT-137, T-INT-138.
- T-ENV-005 and the complete T-ENV-006 remain downstream and are not claimed.

## Permitted execution

- Hash-read the exact local Python, requirements lock, FFmpeg and FFprobe identities.
- Run `tests/gates/test_ccs01_gate.py`, the bound prerequisite tests and full local pytest.
- Run Ruff format-check/lint and mypy without applying source changes.
- Tests may create disposable state only under pytest `tmp_path`.

## Stops

Stop with the canonical r13 code if a bound digest changes, prerequisite evidence fails, any
unlisted repository write is required, or execution would touch credentials, providers, network,
media, runtime databases, deployment or publication. Do not repair a prerequisite inside this
gate attempt.
