from __future__ import annotations

from datetime import UTC, datetime, timedelta, timezone

import pytest

from custom_content_studio.domain.security import (
    ROLE_ACTIONS,
    Action,
    ActorContext,
    ActorType,
    Role,
    SecretReference,
    SecurityError,
    is_action_allowed,
    mask_sensitive,
    require_action,
)

NOW = datetime(2026, 9, 8, tzinfo=UTC)


def _actor(
    actor_type: ActorType,
    roles: frozenset[Role],
    scopes: frozenset[str] = frozenset(),
) -> ActorContext:
    return ActorContext(actor_type, "actor-1", "auth-1", "workspace-1", roles, scopes, NOW)


def test_closed_role_action_matrix() -> None:
    read = {
        Action.WORKSPACE_READ,
        Action.RENDER_READ,
        Action.PUBLICATION_READ,
        Action.ANALYTICS_READ,
    }
    assert ROLE_ACTIONS == {
        Role.ADMIN: frozenset(Action),
        Role.EDITOR: frozenset(
            read
            | {
                Action.CONTENT_EDIT,
                Action.BENCHMARK_EDIT,
                Action.GENERATION_REQUEST,
                Action.DESIGN_EDIT,
                Action.RENDER_REQUEST,
            }
        ),
        Role.REVIEWER: frozenset(read | {Action.REVIEW_DECIDE}),
        Role.VIEWER: frozenset(read),
    }
    for role in Role:
        actor = _actor(ActorType.USER, frozenset({role}))
        for action in Action:
            assert is_action_allowed(actor, action) is (action in ROLE_ACTIONS[role])


def test_workspace_mismatch_and_disallowed_action_have_safe_error() -> None:
    actor = _actor(ActorType.USER, frozenset({Role.VIEWER}))
    for workspace, action in (
        ("another-workspace", Action.WORKSPACE_READ),
        ("workspace-1", Action.CONTENT_EDIT),
    ):
        with pytest.raises(SecurityError) as caught:
            require_action(actor, workspace, action)
        assert caught.value.code == "WORKSPACE_ACCESS_DENIED"
        assert dict(caught.value.details) == {"action": action.value}
        rendered = f"{caught.value!r} {caught.value} {caught.value.details}"
        assert "another-workspace" not in rendered
        assert "actor-1" not in rendered


def test_user_scopes_narrow_and_service_roles_never_broaden() -> None:
    user = _actor(
        ActorType.USER,
        frozenset({Role.ADMIN}),
        frozenset({Action.WORKSPACE_READ.value.casefold()}),
    )
    assert is_action_allowed(user, Action.WORKSPACE_READ)
    assert not is_action_allowed(user, Action.WORKSPACE_ADMIN)

    service = _actor(
        ActorType.SERVICE_ACCOUNT,
        frozenset({Role.ADMIN}),
        frozenset({Action.ANALYTICS_READ.value.casefold()}),
    )
    assert is_action_allowed(service, Action.ANALYTICS_READ)
    assert not is_action_allowed(service, Action.WORKSPACE_ADMIN)


@pytest.mark.parametrize("field", ["actor_id", "authentication_id", "workspace_id"])
def test_actor_context_rejects_invalid_identifier(field: str) -> None:
    values = {
        "actor_type": ActorType.USER,
        "actor_id": "actor",
        "authentication_id": "authentication",
        "workspace_id": "workspace",
        "roles": frozenset({Role.VIEWER}),
        "scopes": frozenset(),
        "authenticated_at_utc": NOW,
    }
    values[field] = " "
    with pytest.raises(ValueError):
        ActorContext(**values)  # type: ignore[arg-type]


def test_actor_context_requires_utc_and_representation_has_no_bearer_material() -> None:
    with pytest.raises(ValueError, match="timezone-aware"):
        ActorContext(
            ActorType.USER,
            "actor",
            "authentication",
            "workspace",
            frozenset(),
            frozenset(),
            NOW.replace(tzinfo=None),
        )
    with pytest.raises(ValueError, match="must be UTC"):
        ActorContext(
            ActorType.USER,
            "actor",
            "authentication",
            "workspace",
            frozenset(),
            frozenset(),
            datetime(2026, 9, 8, tzinfo=timezone(timedelta(hours=9))),
        )
    actor = _actor(ActorType.USER, frozenset({Role.VIEWER}))
    assert "token" not in repr(actor).casefold()
    assert "cookie" not in repr(actor).casefold()


def test_secret_reference_and_nested_masking_do_not_leak() -> None:
    locator = "synthetic://test-only/reference"
    raw = "SYNTHETIC_RAW_SECRET_NEVER_LOG"
    reference = SecretReference(locator)
    assert str(reference) == "[SECRET_REF]"
    assert locator not in repr(reference)
    payload = {
        "nested": [{"Api-Key": raw}, {"safe": "visible"}],
        "refreshToken": raw,
        "tuple": ({"credential_id": raw},),
    }
    masked = mask_sensitive(payload)
    assert raw not in repr(masked)
    assert masked["nested"][1]["safe"] == "visible"
    assert payload["nested"][0]["Api-Key"] == raw


@pytest.mark.parametrize("locator", ["", " leading", "trailing ", "line\nbreak", "nul\0"])
def test_secret_reference_rejects_invalid_locator(locator: str) -> None:
    with pytest.raises(ValueError):
        SecretReference(locator)
