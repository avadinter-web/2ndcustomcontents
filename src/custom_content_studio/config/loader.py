from pathlib import Path

from .models import Environment, Settings

REPOSITORY_ROOT = Path(__file__).resolve().parents[3]


def load_settings(
    environment: Environment = Environment.DEV, repository_root: Path | None = None
) -> Settings:
    root = (repository_root or REPOSITORY_ROOT).resolve()
    runtime = (root / ".runtime" / environment.value).resolve()
    return Settings(environment=environment, repository_root=root, runtime_root=runtime)
