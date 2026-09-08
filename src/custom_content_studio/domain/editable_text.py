"""Lossless validation policy for human-editable domain text."""

from __future__ import annotations

import unicodedata

_MAX_EDITABLE_TEXT_CODE_POINTS = 10_000
_VALIDATION_MESSAGE = "DOMAIN_VALIDATION_FAILED: editable text is invalid"


def _validation_error() -> ValueError:
    return ValueError(_VALIDATION_MESSAGE)


def normalize_editable_text(value: str | None) -> str | None:
    """Validate editable text without changing any accepted code point."""

    if value is None:
        return None
    if not isinstance(value, str) or len(value) > _MAX_EDITABLE_TEXT_CODE_POINTS:
        raise _validation_error()

    for character in value:
        code_point = ord(character)
        if 0xD800 <= code_point <= 0xDFFF:
            raise _validation_error()
        if unicodedata.category(character) == "Cc" and character not in {"\n", "\r"}:
            raise _validation_error()

    return value
