from pathlib import Path

import pytest

from custom_content_studio.runtime_paths import normalize_runtime_paths


def test_runtime_paths_are_unique_direct_children() -> None:
    runtime_root = (Path(__file__).parent / "fixture-repository" / ".runtime" / "DEV").resolve()

    paths = normalize_runtime_paths(runtime_root)

    assert paths.runtime_root == runtime_root
    assert paths.directories() == tuple(
        runtime_root / name
        for name in (
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
    )
    assert len(set(paths.directories())) == 9


def test_normalization_has_no_filesystem_side_effect(tmp_path: Path) -> None:
    runtime_root = tmp_path / "not-created" / ".runtime" / "STAGING"

    paths = normalize_runtime_paths(runtime_root)

    assert paths.runtime_root == runtime_root
    assert not runtime_root.exists()
    assert all(not directory.exists() for directory in paths.directories())


def test_relative_runtime_root_is_rejected() -> None:
    with pytest.raises(ValueError, match="must be absolute"):
        normalize_runtime_paths(Path(".runtime/DEV"))
