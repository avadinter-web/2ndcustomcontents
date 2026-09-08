from __future__ import annotations

from copy import deepcopy

import pytest

from custom_content_studio.domain import (
    EffectiveValueCandidate,
    EffectiveValueResolver,
    EffectiveValueSource,
)


def _candidate(value: object, *, present: bool = True) -> EffectiveValueCandidate:
    return EffectiveValueCandidate(present=present, value=value)  # type: ignore[arg-type]


@pytest.mark.parametrize(
    ("candidates", "expected_value", "expected_source"),
    [
        (
            {
                EffectiveValueSource.OVERRIDE: _candidate("human"),
                EffectiveValueSource.AUTO: _candidate("auto"),
                EffectiveValueSource.PROJECT_DEFAULT: _candidate("project"),
                EffectiveValueSource.SYSTEM_DEFAULT: _candidate("system"),
            },
            "human",
            EffectiveValueSource.OVERRIDE,
        ),
        (
            {
                EffectiveValueSource.AUTO: _candidate("auto"),
                EffectiveValueSource.PROJECT_DEFAULT: _candidate("project"),
                EffectiveValueSource.SYSTEM_DEFAULT: _candidate("system"),
            },
            "auto",
            EffectiveValueSource.AUTO,
        ),
        (
            {
                EffectiveValueSource.PROJECT_DEFAULT: _candidate("project"),
                EffectiveValueSource.SYSTEM_DEFAULT: _candidate("system"),
            },
            "project",
            EffectiveValueSource.PROJECT_DEFAULT,
        ),
        (
            {EffectiveValueSource.SYSTEM_DEFAULT: _candidate("system")},
            "system",
            EffectiveValueSource.SYSTEM_DEFAULT,
        ),
    ],
)
def test_resolve_uses_the_exact_four_layer_precedence(
    candidates: dict[EffectiveValueSource, EffectiveValueCandidate],
    expected_value: str,
    expected_source: EffectiveValueSource,
) -> None:
    result = EffectiveValueResolver().resolve(candidates)

    assert result.resolved is True
    assert result.value == expected_value
    assert result.source is expected_source


@pytest.mark.parametrize("value", [None, 0, False, "", [], {}])
def test_present_json_values_win_without_truthiness_fallthrough(value: object) -> None:
    result = EffectiveValueResolver().resolve(
        {
            EffectiveValueSource.OVERRIDE: _candidate(value),
            EffectiveValueSource.AUTO: _candidate("fallback"),
        }
    )

    assert result.resolved is True
    assert result.value == value
    assert result.source is EffectiveValueSource.OVERRIDE


def test_absent_and_explicit_null_are_distinct() -> None:
    resolver = EffectiveValueResolver()

    unresolved = resolver.resolve({EffectiveValueSource.OVERRIDE: _candidate(None, present=False)})
    explicit_null = resolver.resolve({EffectiveValueSource.OVERRIDE: _candidate(None)})

    assert unresolved.resolved is False
    assert unresolved.value is None
    assert unresolved.source is None
    assert explicit_null.resolved is True
    assert explicit_null.value is None
    assert explicit_null.source is EffectiveValueSource.OVERRIDE


def test_reset_to_ai_removes_only_override_and_does_not_mutate_inputs() -> None:
    candidates = {
        EffectiveValueSource.OVERRIDE: _candidate({"label": "human"}),
        EffectiveValueSource.AUTO: _candidate({"label": "auto"}),
        EffectiveValueSource.PROJECT_DEFAULT: _candidate({"label": "project"}),
        EffectiveValueSource.SYSTEM_DEFAULT: _candidate({"label": "system"}),
    }
    before = deepcopy(candidates)

    reset = EffectiveValueResolver().reset_to_ai(candidates)
    result = EffectiveValueResolver().resolve(reset)

    assert candidates == before
    assert EffectiveValueSource.OVERRIDE not in reset
    assert reset[EffectiveValueSource.AUTO] == candidates[EffectiveValueSource.AUTO]
    assert result.value == {"label": "auto"}
    assert result.source is EffectiveValueSource.AUTO


def test_resolve_field_uses_the_callers_field_mapping() -> None:
    result = EffectiveValueResolver().resolve_field(
        {"caption": {EffectiveValueSource.PROJECT_DEFAULT: _candidate("project caption")}},
        "caption",
    )

    missing = EffectiveValueResolver().resolve_field({}, "unknown")

    assert result.value == "project caption"
    assert result.source is EffectiveValueSource.PROJECT_DEFAULT
    assert missing.resolved is False


def test_candidate_presence_must_be_boolean() -> None:
    with pytest.raises(TypeError, match="present must be a bool"):
        EffectiveValueCandidate(present=1, value="invalid")  # type: ignore[arg-type]
