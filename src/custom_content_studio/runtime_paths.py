from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Final

_DIRECTORY_NAMES: Final[tuple[str, ...]] = (
    "config",
    "data",
    "db",
    "assets",
    "cache",
    "temp",
    "output",
    "logs",
    "credentials",
)


@dataclass(frozen=True)
class RuntimePaths:
    """Normalized, side-effect-free locations for one runtime profile."""

    runtime_root: Path
    config: Path
    data: Path
    db: Path
    assets: Path
    cache: Path
    temp: Path
    output: Path
    logs: Path
    credentials: Path

    def directories(self) -> tuple[Path, ...]:
        """Return every managed directory in the canonical order."""

        return (
            self.config,
            self.data,
            self.db,
            self.assets,
            self.cache,
            self.temp,
            self.output,
            self.logs,
            self.credentials,
        )


def normalize_runtime_paths(runtime_root: Path) -> RuntimePaths:
    """Derive isolated runtime locations without creating or reading any files."""

    if not runtime_root.is_absolute():
        raise ValueError("runtime root must be absolute")

    root = runtime_root.resolve(strict=False)
    directories = tuple((root / name).resolve(strict=False) for name in _DIRECTORY_NAMES)
    for directory in directories:
        try:
            relative = directory.relative_to(root)
        except ValueError as error:
            raise ValueError("runtime directory must remain inside runtime root") from error
        if relative == Path(".") or len(relative.parts) != 1:
            raise ValueError("runtime directory must be a direct child of runtime root")

    if len(set(directories)) != len(directories):
        raise ValueError("runtime directories must be unique")

    return RuntimePaths(root, *directories)
