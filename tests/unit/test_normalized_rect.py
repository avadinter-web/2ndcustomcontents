from dataclasses import FrozenInstanceError

import pytest

from custom_content_studio.domain import NormalizedRect


@pytest.mark.parametrize(
    ("x", "y", "width", "height"),
    [(0, 0, 1, 1), (1, 1, 1, 1), (0.5, 0.25, 0.001, 0.75)],
)
def test_normalized_rect_accepts_schema_endpoints(
    x: float, y: float, width: float, height: float
) -> None:
    rect = NormalizedRect(x=x, y=y, width=width, height=height)

    assert (rect.x, rect.y, rect.width, rect.height) == (x, y, width, height)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("x", -0.01),
        ("x", 1.01),
        ("y", -0.01),
        ("y", 1.01),
        ("width", 0),
        ("width", 1.01),
        ("height", 0),
        ("height", 1.01),
    ],
)
def test_normalized_rect_rejects_out_of_range_values(field: str, value: float) -> None:
    values: dict[str, float] = {"x": 0, "y": 0, "width": 1, "height": 1}
    values[field] = value

    with pytest.raises(ValueError, match=field):
        NormalizedRect(**values)


@pytest.mark.parametrize("value", [True, "0", None, complex(0, 0), float("nan"), float("inf")])
def test_normalized_rect_rejects_non_schema_numeric_values(value: object) -> None:
    with pytest.raises(ValueError, match="finite real numbers"):
        NormalizedRect(x=value, y=0, width=1, height=1)  # type: ignore[arg-type]


def test_normalized_rect_is_frozen() -> None:
    rect = NormalizedRect(x=0, y=0, width=1, height=1)

    with pytest.raises(FrozenInstanceError):
        rect.x = 0.5  # type: ignore[misc]


def test_normalized_rect_does_not_impose_unit_square_containment() -> None:
    rect = NormalizedRect(x=1, y=1, width=1, height=1)

    assert rect.width == 1
    assert rect.height == 1
