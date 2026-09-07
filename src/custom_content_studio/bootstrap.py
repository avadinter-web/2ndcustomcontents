from pathlib import Path

from .config import Environment, Settings, load_settings
from .scope_guard import validate_runtime_scope


def bootstrap(
    environment: Environment = Environment.DEV,
    repository_root: Path | None = None,
) -> Settings:
    settings = load_settings(environment, repository_root)
    validate_runtime_scope(settings.repository_root, (settings.runtime_root,))
    return settings


def main() -> Settings:
    """Validate the shared composition root without external side effects."""
    return bootstrap()


if __name__ == "__main__":
    main()
