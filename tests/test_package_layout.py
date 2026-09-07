from importlib.util import find_spec
from pathlib import Path

import pytest

PACKAGE_ROOT = Path(__file__).resolve().parents[1] / "src" / "custom_content_studio"
CANONICAL_MODULES = (
    "bootstrap",
    "config",
    "api",
    "ui",
    "workers",
    "scheduler",
    "cli",
)


@pytest.mark.parametrize("module_name", CANONICAL_MODULES)
def test_canonical_module_is_package_with_entrypoint(module_name: str) -> None:
    package_path = PACKAGE_ROOT / module_name
    module_spec = find_spec(f"custom_content_studio.{module_name}")

    assert package_path.is_dir()
    assert (package_path / "__init__.py").is_file()
    assert (package_path / "__main__.py").is_file()
    assert module_spec is not None
    assert module_spec.submodule_search_locations is not None


@pytest.mark.parametrize("module_name", CANONICAL_MODULES)
def test_conflicting_flat_module_is_absent(module_name: str) -> None:
    assert not (PACKAGE_ROOT / f"{module_name}.py").exists()


def test_canonical_internal_modules_exist() -> None:
    expected_paths = (
        PACKAGE_ROOT / "bootstrap" / "composition.py",
        PACKAGE_ROOT / "bootstrap" / "startup.py",
        PACKAGE_ROOT / "config" / "models.py",
        PACKAGE_ROOT / "config" / "loader.py",
        PACKAGE_ROOT / "workers" / "runner.py",
        PACKAGE_ROOT / "scheduler" / "runner.py",
    )

    assert all(path.is_file() for path in expected_paths)
