# IMP-022 / CCS-02-007 Implementation Evidence

## Scope

Implemented the pure `EffectiveValueResolver` for `F-078` / `T-018` under
`INV-EFFECTIVE-001`. It accepts caller-mapped candidates and never reads or writes
Project, Content, storage, configuration, environment, API, UI, network or media state.

## Contract evidence

- Precedence is `OVERRIDE`, `AUTO`, `PROJECT_DEFAULT`, then `SYSTEM_DEFAULT`.
- Each candidate has an explicit boolean `present`; a present JSON `null` is resolved.
- Resolved results contain a value and `EffectiveValueSource`; all absent candidates produce
  `resolved=False` with no value or provenance.
- `reset_to_ai` returns a new mapping without `OVERRIDE`; it preserves AUTO and both defaults
  and does not mutate the caller mapping or its values.

## Exclusions

No persistence, migration, Content/ContentVersion mutation, Design override/preset feature,
timeline, API/UI, provider, network, credential, dependency, deployment or publication work is included.
