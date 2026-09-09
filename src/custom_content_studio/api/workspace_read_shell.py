from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from types import MappingProxyType

from fastapi import Request
from starlette.responses import JSONResponse, Response

from ..domain.security import Action, ActorContext, SecurityError, require_action

type JsonValue = None | bool | int | float | str | list[JsonValue] | dict[str, JsonValue]
type WorkspaceReadResolver = Callable[[str, ActorContext], WorkspaceReadProjection | None]
type ActorContextProvider = Callable[[Request], ActorContext | None]

_WORKSPACE_NOT_FOUND_BODY: Mapping[str, str] = MappingProxyType({"code": "WORKSPACE_NOT_FOUND"})


@dataclass(frozen=True)
class WorkspaceReadProjection:
    """The resolver-owned, serializable projection allowed to cross the API seam."""

    workspace_id: str
    fields: Mapping[str, JsonValue]

    def __post_init__(self) -> None:
        if not isinstance(self.workspace_id, str) or not self.workspace_id:
            raise ValueError("workspace_id must be a non-empty string")
        if not isinstance(self.fields, Mapping) or "workspace_id" in self.fields:
            raise ValueError("fields must be a mapping without workspace_id")
        object.__setattr__(self, "fields", MappingProxyType(dict(self.fields)))

    def as_response_body(self) -> dict[str, JsonValue]:
        return {"workspace_id": self.workspace_id, **self.fields}


def workspace_not_found_response() -> JSONResponse:
    """Use one existence-safe response for all denied and absent read states."""
    return JSONResponse(status_code=404, content=dict(_WORKSPACE_NOT_FOUND_BODY))


@dataclass(frozen=True)
class WorkspaceReadShell:
    resolver: WorkspaceReadResolver

    def read(
        self,
        workspace_id: str,
        header_workspace_id: str | None,
        actor_context: ActorContext | None,
    ) -> Response:
        if (
            not isinstance(workspace_id, str)
            or not workspace_id
            or header_workspace_id is None
            or actor_context is None
            or workspace_id != header_workspace_id
            or workspace_id != actor_context.workspace_id
        ):
            return workspace_not_found_response()

        try:
            require_action(actor_context, workspace_id, Action.WORKSPACE_READ)
        except SecurityError:
            return workspace_not_found_response()

        projection = self.resolver(workspace_id, actor_context)
        if projection is None or projection.workspace_id != workspace_id:
            return workspace_not_found_response()
        return JSONResponse(content=projection.as_response_body())
