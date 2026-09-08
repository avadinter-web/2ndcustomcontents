"""Pure normalized-rectangle domain value."""

from __future__ import annotations

import math
from dataclasses import dataclass
from numbers import Real


def _require_coordinate(value: object, name: str, *, positive: bool) -> float:
    if isinstance(value, bool) or not isinstance(value, Real):
        raise ValueError("normalized rectangle values must be finite real numbers")
    coordinate = float(value)
    if not math.isfinite(coordinate):
        raise ValueError("normalized rectangle values must be finite real numbers")
    if coordinate > 1 or (coordinate <= 0 if positive else coordinate < 0):
        raise ValueError(f"{name} must be within its normalized range")
    return coordinate


@dataclass(frozen=True, slots=True)
class NormalizedRect:
    """A schema-compatible rectangle without caller-specific containment policy."""

    x: float
    y: float
    width: float
    height: float

    def __post_init__(self) -> None:
        object.__setattr__(self, "x", _require_coordinate(self.x, "x", positive=False))
        object.__setattr__(self, "y", _require_coordinate(self.y, "y", positive=False))
        object.__setattr__(self, "width", _require_coordinate(self.width, "width", positive=True))
        object.__setattr__(
            self, "height", _require_coordinate(self.height, "height", positive=True)
        )
