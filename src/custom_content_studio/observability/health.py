from __future__ import annotations

import os
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Final

from ..config import ConfigurationError, Environment, Settings, load_settings
from ..runtime_paths import normalize_runtime_paths
from ..scope_guard import ScopeGuardError, validate_runtime_scope
from .logging import Component, ObservabilityContext

_UNKNOWN_ENVIRONMENT: Final = "UNKNOWN"


class HealthStatus(StrEnum):
    LIVE = "LIVE"
    READY = "READY"
    NOT_READY = "NOT_READY"


class HealthCheckName(StrEnum):
    CONFIGURATION = "configuration"
    SCOPE = "scope"
    RUNTIME_PATHS = "runtime_paths"


@dataclass(frozen=True)
class HealthCheck:
    name: HealthCheckName
    status: HealthStatus
    diagnostic_code: str | None = None

    def as_dict(self) -> dict[str, str]:
        result = {"name": self.name.value, "status": self.status.value}
        if self.diagnostic_code is not None:
            result["diagnostic_code"] = self.diagnostic_code
        return result


@dataclass(frozen=True)
class HealthDocument:
    component: Component
    environment: str
    status: HealthStatus
    checks: tuple[HealthCheck, ...]
    request_id: str | None = None
    correlation_id: str | None = None
    service: str = "custom_content_studio"

    def as_dict(self) -> dict[str, object]:
        result: dict[str, object] = {
            "service": self.service,
            "component": self.component.value,
            "environment": self.environment,
            "status": self.status.value,
            "checks": [check.as_dict() for check in self.checks],
        }
        if self.request_id is not None:
            result["request_id"] = self.request_id
        if self.correlation_id is not None:
            result["correlation_id"] = self.correlation_id
        return result


def _environment_label(environment: Environment | str | None) -> str:
    raw = environment if environment is not None else os.environ.get("CCS_ENV")
    if isinstance(raw, Environment):
        return raw.value
    return raw if raw in {item.value for item in Environment} else _UNKNOWN_ENVIRONMENT


def liveness(
    component: Component,
    *,
    environment: Environment | str | None = None,
    context: ObservabilityContext | None = None,
) -> HealthDocument:
    request_context = context or ObservabilityContext(component)
    if request_context.component is not component:
        raise ValueError("health context component must match")
    return HealthDocument(
        component=component,
        environment=_environment_label(environment),
        status=HealthStatus.LIVE,
        checks=(),
        request_id=request_context.request_id,
        correlation_id=request_context.correlation_id,
    )


def readiness_from_settings(
    settings: Settings,
    component: Component,
    *,
    context: ObservabilityContext | None = None,
) -> HealthDocument:
    request_context = context or ObservabilityContext(component)
    if request_context.component is not component:
        raise ValueError("health context component must match")
    checks = [HealthCheck(HealthCheckName.CONFIGURATION, HealthStatus.READY)]
    try:
        validate_runtime_scope(settings.repository_root, (settings.runtime_root,))
    except (OSError, ScopeGuardError, ValueError):
        checks.append(HealthCheck(HealthCheckName.SCOPE, HealthStatus.NOT_READY, "SCOPE_INVALID"))
    else:
        checks.append(HealthCheck(HealthCheckName.SCOPE, HealthStatus.READY))
    try:
        normalize_runtime_paths(settings.runtime_root)
    except (OSError, ValueError):
        checks.append(
            HealthCheck(
                HealthCheckName.RUNTIME_PATHS,
                HealthStatus.NOT_READY,
                "RUNTIME_PATHS_INVALID",
            )
        )
    else:
        checks.append(HealthCheck(HealthCheckName.RUNTIME_PATHS, HealthStatus.READY))
    status = (
        HealthStatus.READY
        if all(check.status is HealthStatus.READY for check in checks)
        else HealthStatus.NOT_READY
    )
    return HealthDocument(
        component=component,
        environment=settings.environment.value,
        status=status,
        checks=tuple(checks),
        request_id=request_context.request_id,
        correlation_id=request_context.correlation_id,
    )


def readiness(
    component: Component,
    *,
    environment: Environment | str | None = None,
    repository_root: Path | None = None,
    context: ObservabilityContext | None = None,
) -> HealthDocument:
    try:
        settings = load_settings(environment, repository_root)
    except (ConfigurationError, OSError, ValueError):
        request_context = context or ObservabilityContext(component)
        if request_context.component is not component:
            raise ValueError("health context component must match") from None
        checks = (
            HealthCheck(
                HealthCheckName.CONFIGURATION,
                HealthStatus.NOT_READY,
                "CONFIGURATION_INVALID",
            ),
            HealthCheck(HealthCheckName.SCOPE, HealthStatus.NOT_READY, "SCOPE_INVALID"),
            HealthCheck(
                HealthCheckName.RUNTIME_PATHS,
                HealthStatus.NOT_READY,
                "RUNTIME_PATHS_INVALID",
            ),
        )
        return HealthDocument(
            component=component,
            environment=_environment_label(environment),
            status=HealthStatus.NOT_READY,
            checks=checks,
            request_id=request_context.request_id,
            correlation_id=request_context.correlation_id,
        )
    return readiness_from_settings(settings, component, context=context)


__all__ = [
    "HealthCheck",
    "HealthCheckName",
    "HealthDocument",
    "HealthStatus",
    "liveness",
    "readiness",
    "readiness_from_settings",
]
