from __future__ import annotations

from types import MappingProxyType

from .models import Action, ActorContext, ActorType, Role, SecurityError

_READ_ACTIONS = frozenset(
    {
        Action.WORKSPACE_READ,
        Action.RENDER_READ,
        Action.PUBLICATION_READ,
        Action.ANALYTICS_READ,
    }
)

ROLE_ACTIONS = MappingProxyType(
    {
        Role.ADMIN: frozenset(Action),
        Role.EDITOR: _READ_ACTIONS
        | {
            Action.CONTENT_EDIT,
            Action.BENCHMARK_EDIT,
            Action.GENERATION_REQUEST,
            Action.DESIGN_EDIT,
            Action.RENDER_REQUEST,
        },
        Role.REVIEWER: _READ_ACTIONS | {Action.REVIEW_DECIDE},
        Role.VIEWER: _READ_ACTIONS,
    }
)


def is_action_allowed(actor: ActorContext, action: Action) -> bool:
    scope = action.value.casefold()
    if actor.actor_type is ActorType.SERVICE_ACCOUNT:
        return scope in actor.scopes
    allowed_by_role = any(action in ROLE_ACTIONS[role] for role in actor.roles)
    if not allowed_by_role:
        return False
    return not actor.scopes or scope in actor.scopes


def require_action(actor: ActorContext, workspace_id: str, action: Action) -> None:
    if actor.workspace_id != workspace_id or not is_action_allowed(actor, action):
        raise SecurityError(
            "WORKSPACE_ACCESS_DENIED",
            "workspace action is not permitted",
            {"action": action.value},
        )
