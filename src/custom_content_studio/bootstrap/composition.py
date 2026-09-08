from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path

from ..application.services import (
    AssetService,
    ContentService,
    ServiceAccountCredentialService,
    SessionService,
)
from ..config import Environment, Settings, load_settings
from ..infrastructure.sqlite.repositories import (
    SQLiteAssetRepository,
    SQLiteAuditEventRepository,
    SQLiteContentRepository,
    SQLiteServiceAccountRepository,
    SQLiteSessionRepository,
)
from ..observability import (
    Component,
    HealthStatus,
    LocalStructuredLogger,
    ObservabilityContext,
    configure_local_logging,
    readiness_from_settings,
)
from ..persistence import SQLiteConnectionFactory
from ..runtime_paths import normalize_runtime_paths
from ..scope_guard import ScopeGuardError, validate_runtime_scope


@dataclass(frozen=True)
class LocalSecurityComposition:
    repository: SQLiteSessionRepository
    sessions: SessionService
    service_accounts: SQLiteServiceAccountRepository
    audit_events: SQLiteAuditEventRepository
    service_account_credentials: ServiceAccountCredentialService
    assets: SQLiteAssetRepository
    asset_service: AssetService
    contents: SQLiteContentRepository
    content_service: ContentService


@dataclass(frozen=True)
class LocalObservabilityComposition:
    logger: LocalStructuredLogger
    context: ObservabilityContext


def compose_local_security(
    factory: SQLiteConnectionFactory,
) -> LocalSecurityComposition:
    """Bind local security services without opening or migrating a database."""
    repository = SQLiteSessionRepository()
    service_accounts = SQLiteServiceAccountRepository()
    audit_events = SQLiteAuditEventRepository()
    assets = SQLiteAssetRepository()
    contents = SQLiteContentRepository()
    return LocalSecurityComposition(
        repository=repository,
        sessions=SessionService(factory, repository),
        service_accounts=service_accounts,
        audit_events=audit_events,
        service_account_credentials=ServiceAccountCredentialService(
            factory,
            service_accounts,
            audit_events,
        ),
        assets=assets,
        asset_service=AssetService(factory, assets),
        contents=contents,
        content_service=ContentService(factory, contents),
    )


def compose_local_observability(
    settings: Settings,
    component: Component,
) -> LocalObservabilityComposition:
    """Bind the local stderr logger without opening a file or remote sink."""
    return LocalObservabilityComposition(
        logger=configure_local_logging(settings),
        context=ObservabilityContext(component),
    )


def _emit_not_ready(
    observability: LocalObservabilityComposition,
    diagnostic_code: str,
) -> None:
    context = ObservabilityContext(
        component=observability.context.component,
        error_code=diagnostic_code,
    )
    observability.logger.emit(
        logging.ERROR,
        "startup.not_ready",
        "local startup checks did not pass",
        context,
    )


def bootstrap(
    environment: Environment | str | None = None,
    repository_root: Path | None = None,
    *,
    component: Component = Component.BOOTSTRAP,
) -> Settings:
    settings = load_settings(environment, repository_root)
    observability = compose_local_observability(settings, component)
    try:
        validate_runtime_scope(settings.repository_root, (settings.runtime_root,))
    except (OSError, ScopeGuardError, ValueError):
        _emit_not_ready(observability, "SCOPE_INVALID")
        raise
    try:
        normalize_runtime_paths(settings.runtime_root)
    except (OSError, ValueError):
        _emit_not_ready(observability, "RUNTIME_PATHS_INVALID")
        raise
    health = readiness_from_settings(settings, component)
    if health.status is not HealthStatus.READY:
        _emit_not_ready(observability, "STARTUP_NOT_READY")
        raise RuntimeError("STARTUP_NOT_READY: local startup checks did not pass")
    observability.logger.emit(
        logging.INFO,
        "startup.ready",
        "local startup checks passed",
        observability.context,
    )
    return settings
