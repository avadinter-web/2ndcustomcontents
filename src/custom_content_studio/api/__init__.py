from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response

from ..bootstrap import bootstrap
from ..config import ConfigurationError, Settings, load_settings
from ..observability import (
    Component,
    HealthDocument,
    HealthStatus,
    ObservabilityContext,
    configure_local_logging,
    liveness,
    new_request_context,
    readiness,
)
from .workspace_read_shell import (
    ActorContextProvider,
    WorkspaceReadResolver,
    WorkspaceReadShell,
    workspace_not_found_response,
)

app = FastAPI(title="Custom Content Studio")
_workspace_read_shell: WorkspaceReadShell | None = None
_actor_context_provider: ActorContextProvider | None = None


def configure_workspace_read_shell(
    resolver: WorkspaceReadResolver | None,
    actor_context_provider: ActorContextProvider | None,
) -> None:
    """Compose the local read shell from injected retrieval and existing actor context seams."""
    global _workspace_read_shell, _actor_context_provider
    _workspace_read_shell = WorkspaceReadShell(resolver) if resolver is not None else None
    _actor_context_provider = actor_context_provider


@app.get("/api/v1/workspaces/{workspace_id}")
def workspace_read(request: Request, workspace_id: str) -> Response:
    if _workspace_read_shell is None or _actor_context_provider is None:
        return workspace_not_found_response()
    actor_context = _actor_context_provider(request)
    return _workspace_read_shell.read(
        workspace_id,
        request.headers.get("X-Workspace-Id"),
        actor_context,
    )


def _request_context(request: Request) -> ObservabilityContext:
    context = getattr(request.state, "ccs_observability_context", None)
    if not isinstance(context, ObservabilityContext):
        raise RuntimeError("request observability context is unavailable")
    return context


def _health_response(document: HealthDocument, response: Response) -> dict[str, object]:
    if document.status is HealthStatus.NOT_READY:
        response.status_code = 503
    return document.as_dict()


@app.middleware("http")
async def correlate_request(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    context = new_request_context(Component.API)
    request.state.ccs_observability_context = context
    response = await call_next(request)
    response.headers["X-Request-ID"] = context.request_id or ""
    response.headers["X-Correlation-ID"] = context.correlation_id or ""
    try:
        settings = load_settings()
    except (ConfigurationError, OSError, ValueError):
        return response
    configure_local_logging(settings).emit(
        logging.INFO,
        "request.completed",
        "local request completed",
        context,
    )
    return response


@app.get("/health/live")
def health_live(request: Request, response: Response) -> dict[str, object]:
    document = liveness(Component.API, context=_request_context(request))
    return _health_response(document, response)


@app.get("/health/ready")
def health_ready(request: Request, response: Response) -> dict[str, object]:
    document = readiness(Component.API, context=_request_context(request))
    return _health_response(document, response)


@app.get("/health")
def health(request: Request, response: Response) -> dict[str, object]:
    """Compatibility alias for the safe readiness document."""
    document = readiness(Component.API, context=_request_context(request))
    return _health_response(document, response)


def main() -> Settings:
    """Validate the API composition root without starting a server."""
    return bootstrap(component=Component.API)


__all__ = [
    "app",
    "configure_workspace_read_shell",
    "health",
    "health_live",
    "health_ready",
    "main",
    "workspace_read",
]
