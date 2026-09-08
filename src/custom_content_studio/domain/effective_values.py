from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum

from .workspaces import JsonValue


class EffectiveValueSource(StrEnum):
    OVERRIDE = "OVERRIDE"
    AUTO = "AUTO"
    PROJECT_DEFAULT = "PROJECT_DEFAULT"
    SYSTEM_DEFAULT = "SYSTEM_DEFAULT"


_PRECEDENCE = (
    EffectiveValueSource.OVERRIDE,
    EffectiveValueSource.AUTO,
    EffectiveValueSource.PROJECT_DEFAULT,
    EffectiveValueSource.SYSTEM_DEFAULT,
)


@dataclass(frozen=True)
class EffectiveValueCandidate:
    """A caller-mapped value whose presence is independent from its JSON value."""

    present: bool
    value: JsonValue = None

    def __post_init__(self) -> None:
        if not isinstance(self.present, bool):
            raise TypeError("present must be a bool")


@dataclass(frozen=True)
class EffectiveValueResult:
    """The immutable result of resolving one caller-mapped field."""

    resolved: bool
    value: JsonValue | None = None
    source: EffectiveValueSource | None = None

    def __post_init__(self) -> None:
        if self.resolved:
            if self.source is None:
                raise ValueError("resolved results require source provenance")
            return
        if self.value is not None or self.source is not None:
            raise ValueError("unresolved results carry no value or source")


class EffectiveValueResolver:
    """Resolve caller-supplied candidate envelopes without inspecting or mutating them."""

    def resolve(
        self,
        candidates: Mapping[EffectiveValueSource, EffectiveValueCandidate],
    ) -> EffectiveValueResult:
        for source in _PRECEDENCE:
            candidate = candidates.get(source)
            if candidate is None:
                continue
            if not isinstance(candidate, EffectiveValueCandidate):
                raise TypeError("candidate values must be EffectiveValueCandidate instances")
            if candidate.present:
                return EffectiveValueResult(True, candidate.value, source)
        return EffectiveValueResult(False)

    def resolve_field(
        self,
        field_candidates: Mapping[str, Mapping[EffectiveValueSource, EffectiveValueCandidate]],
        field_name: str,
    ) -> EffectiveValueResult:
        """Resolve one field selected by the caller's storage/API-to-candidate mapping."""
        return self.resolve(field_candidates.get(field_name, {}))

    def reset_to_ai(
        self,
        candidates: Mapping[EffectiveValueSource, EffectiveValueCandidate],
    ) -> dict[EffectiveValueSource, EffectiveValueCandidate]:
        """Return a copy with only the override entry removed."""
        return {
            source: candidate
            for source, candidate in candidates.items()
            if source is not EffectiveValueSource.OVERRIDE
        }
