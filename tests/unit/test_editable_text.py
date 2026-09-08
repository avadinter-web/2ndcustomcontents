import builtins
import unicodedata

import pytest

from custom_content_studio.domain import normalize_editable_text


def test_normalize_editable_text_preserves_none_and_empty_as_distinct_values() -> None:
    assert normalize_editable_text(None) is None
    assert normalize_editable_text("") == ""


def test_normalize_editable_text_preserves_unicode_and_line_endings_by_identity() -> None:
    value = "\uac00\U0001f642\rplain\ntext\r\nend"

    assert normalize_editable_text(value) is value


def test_normalize_editable_text_does_not_normalize_unicode_forms() -> None:
    decomposed = "e\u0301"
    composed = unicodedata.normalize("NFC", decomposed)

    result = normalize_editable_text(decomposed)

    assert result is decomposed
    assert result != composed


def test_normalize_editable_text_accepts_exact_code_point_limit() -> None:
    value = "a" * 10_000

    assert normalize_editable_text(value) is value


def test_normalize_editable_text_rejects_input_above_code_point_limit() -> None:
    with pytest.raises(ValueError, match="^DOMAIN_VALIDATION_FAILED:"):
        normalize_editable_text("a" * 10_001)


@pytest.mark.parametrize("value", [0, True, b"text", object()])
def test_normalize_editable_text_rejects_non_string_non_none_values(value: object) -> None:
    with pytest.raises(ValueError, match="^DOMAIN_VALIDATION_FAILED:"):
        normalize_editable_text(value)  # type: ignore[arg-type]


@pytest.mark.parametrize("value", ["before\x00after", "\x1f", "\x7f", "\ud800"])
def test_normalize_editable_text_rejects_controls_and_lone_surrogates(value: str) -> None:
    with pytest.raises(ValueError, match="^DOMAIN_VALIDATION_FAILED:"):
        normalize_editable_text(value)


def test_normalize_editable_text_performs_no_io(monkeypatch: pytest.MonkeyPatch) -> None:
    def fail_open(*args: object, **kwargs: object) -> object:
        raise AssertionError("editable text validation must not perform I/O")

    monkeypatch.setattr(builtins, "open", fail_open)

    assert normalize_editable_text("in-memory") == "in-memory"
