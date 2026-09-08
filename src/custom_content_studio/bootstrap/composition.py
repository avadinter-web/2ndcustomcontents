from dataclasses import dataclass
from pathlib import Path

from ..application.services import SessionService
from ..config import Environment, Settings, load_settings
from ..infrastructure.sqlite.repositories import SQLiteSessionRepository
from ..persistence import SQLiteConnectionFactory
from ..scope_guard import validate_runtime_scope


@dataclass(frozen=True)
class LocalSecurityComposition:
    repository: SQLiteSessionRepository
    sessions: SessionService


def compose_local_security(
    factory: SQLiteConnectionFactory,
) -> LocalSecurityComposition:
    """Bind local security services without opening or migrating a database."""
    repository = SQLiteSessionRepository()
    return LocalSecurityComposition(repository, SessionService(factory, repository))


def bootstrap(
    environment: Environment | str | None = None,
    repository_root: Path | None = None,
) -> Settings:
    settings = load_settings(environment, repository_root)
    validate_runtime_scope(settings.repository_root, (settings.runtime_root,))
    return settings
