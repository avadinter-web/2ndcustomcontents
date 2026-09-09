from __future__ import annotations

import json
from datetime import UTC, datetime

import pytest
from fastapi import Request
from starlette.responses import Response

from custom_content_studio.api import configure_workspace_read_shell, workspace_read
from custom_content_studio.api.workspace_read_shell import (
    WorkspaceReadProjection,
    WorkspaceReadShell,
)
from custom_content_studio.domain.security import ActorContext, ActorType, Role

NOW = datetime(2026, 9, 9, tzinfo=UTC)


def _actor(
    workspace_id: str = "workspace-1", roles: frozenset[Role] = frozenset({Role.VIEWER})
) -> ActorContext:
    return ActorContext(
        ActorType.USER,
        "actor-1",
        "authentication-1",
        workspace_id,
        roles,
        frozenset(),
        NOW,
    )


def _body(response: Response) -> dict[str, object]:
    payload = json.loads(response.body)
    assert isinstance(payload, dict)
    return payload


def _request(header_workspace_id: str) -> Request:
    return Request(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "GET",
            "scheme": "http",
            "path": "/api/v1/workspaces/workspace-1",
            "raw_path": b"/api/v1/workspaces/workspace-1",
            "query_string": b"",
            "headers": [(b"x-workspace-id", header_workspace_id.encode())],
            "client": ("127.0.0.1", 50000),
            "server": ("127.0.0.1", 8000),
        }
    )


def test_get_route_uses_only_injected_resolver_and_existing_actor_context() -> None:
    actor = _actor()

    def resolver(workspace_id: str, resolved_actor: ActorContext) -> WorkspaceReadProjection:
        assert resolved_actor is actor
        return WorkspaceReadProjection(workspace_id, {})

    configure_workspace_read_shell(resolver, lambda _: actor)
    try:
        response = workspace_read(_request("workspace-1"), "workspace-1")
    finally:
        configure_workspace_read_shell(None, None)

    assert response.status_code == 200
    assert _body(response) == {"workspace_id": "workspace-1"}


def test_same_workspace_read_passes_validated_identity_to_injected_resolver() -> None:
    calls: list[tuple[str, ActorContext]] = []

    def resolver(workspace_id: str, actor: ActorContext) -> WorkspaceReadProjection:
        calls.append((workspace_id, actor))
        return WorkspaceReadProjection(workspace_id, {"name": "safe workspace"})

    actor = _actor()
    response = WorkspaceReadShell(resolver).read("workspace-1", "workspace-1", actor)

    assert response.status_code == 200
    assert _body(response) == {"workspace_id": "workspace-1", "name": "safe workspace"}
    assert calls == [("workspace-1", actor)]


@pytest.mark.parametrize(
    ("workspace_id", "header_workspace_id", "actor", "roles"),
    [
        ("workspace-1", None, _actor(), frozenset({Role.VIEWER})),
        ("workspace-1", "workspace-2", _actor(), frozenset({Role.VIEWER})),
        ("workspace-1", "workspace-1", _actor("workspace-2"), frozenset({Role.VIEWER})),
        ("workspace-1", "workspace-1", _actor(roles=frozenset()), frozenset()),
    ],
)
def test_failed_identity_or_policy_never_invokes_resolver(
    workspace_id: str,
    header_workspace_id: str | None,
    actor: ActorContext,
    roles: frozenset[Role],
) -> None:
    del roles
    calls: list[str] = []

    def resolver(resolved_workspace_id: str, _: ActorContext) -> WorkspaceReadProjection:
        calls.append(resolved_workspace_id)
        return WorkspaceReadProjection(resolved_workspace_id, {})

    response = WorkspaceReadShell(resolver).read(workspace_id, header_workspace_id, actor)

    assert response.status_code == 404
    assert _body(response) == {"code": "WORKSPACE_NOT_FOUND"}
    assert calls == []


def test_absence_and_cross_workspace_projection_are_indistinguishable() -> None:
    actor = _actor()

    def absent(_: str, __: ActorContext) -> None:
        return None

    def cross_scope(_: str, __: ActorContext) -> WorkspaceReadProjection:
        return WorkspaceReadProjection("workspace-2", {})

    absent_response = WorkspaceReadShell(absent).read("workspace-1", "workspace-1", actor)
    cross_scope_response = WorkspaceReadShell(cross_scope).read("workspace-1", "workspace-1", actor)

    assert absent_response.status_code == cross_scope_response.status_code == 404
    assert absent_response.body == cross_scope_response.body == b'{"code":"WORKSPACE_NOT_FOUND"}'


def test_shell_has_no_mutation_or_pagination_surface() -> None:
    public_methods = {name for name in vars(WorkspaceReadShell) if not name.startswith("_")}

    assert public_methods == {"read"}
    assert "limit" not in WorkspaceReadShell.read.__annotations__
    assert "cursor" not in WorkspaceReadShell.read.__annotations__
    assert "page" not in WorkspaceReadShell.read.__annotations__


def test_request_annotation_keeps_actor_context_injected_not_credential_parsed() -> None:
    assert Request not in WorkspaceReadShell.read.__annotations__.values()
