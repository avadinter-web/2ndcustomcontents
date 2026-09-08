from pathlib import Path

import pytest

from custom_content_studio.config import REPOSITORY_ROOT, Environment, Settings, load_settings


@pytest.mark.parametrize("environment", list(Environment))
def test_profile_runtime_is_repository_scoped(environment: Environment) -> None:
    repository_root = REPOSITORY_ROOT

    settings = load_settings(environment, repository_root)

    assert settings.repository_root == repository_root
    assert settings.runtime_root == repository_root / ".runtime" / environment.value


def test_runtime_outside_profile_path_is_rejected() -> None:
    repository_root = Path(__file__).parent.resolve()

    with pytest.raises(ValueError, match="repository profile path"):
        Settings(
            environment=Environment.DEV,
            repository_root=repository_root,
            runtime_root=repository_root / "elsewhere" / "DEV",
        )
