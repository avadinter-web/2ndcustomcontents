from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import StrEnum
from types import MappingProxyType
from typing import Any


class ActorType(StrEnum):
    USER = "USER"
    SERVICE_ACCOUNT = "SERVICE_ACCOUNT"


class Role(StrEnum):
    ADMIN = "ADMIN"
    EDITOR = "EDITOR"
    REVIEWER = "REVIEWER"
    VIEWER = "VIEWER"


class Action(StrEnum):
    WORKSPACE_READ = "WORKSPACE_READ"
    WORKSPACE_ADMIN = "WORKSPACE_ADMIN"
    INTEGRATION_MANAGE = "INTEGRATION_MANAGE"
    SECRET_REFERENCE_MANAGE = "SECRET_REFERENCE_MANAGE"
    WORKER_MANAGE = "WORKER_MANAGE"
    KILL_SWITCH_MANAGE = "KILL_SWITCH_MANAGE"
    CONTENT_EDIT = "CONTENT_EDIT"
    BENCHMARK_EDIT = "BENCHMARK_EDIT"
    GENERATION_REQUEST = "GENERATION_REQUEST"
    DESIGN_EDIT = "DESIGN_EDIT"
    RENDER_REQUEST = "RENDER_REQUEST"
    REVIEW_DECIDE = "REVIEW_DECIDE"
    RENDER_READ = "RENDER_READ"
    PUBLICATION_READ = "PUBLICATION_READ"
    ANALYTICS_READ = "ANALYTICS_READ"


class SecurityError(RuntimeError):
    def __init__(
        self,
        code: str,
        message: str,
        details: Mapping[str, str] | None = None,
    ) -> None:
        self.code = code
        self.details = MappingProxyType(dict(details or {}))
        super().__init__(f"{code}: {message}")


def _validated_identifier(value: str, name: str) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")
    return value


@dataclass(frozen=True)
class SecretReference:
    _locator: str = field(repr=False)

    def __post_init__(self) -> None:
        locator = _validated_identifier(self._locator, "secret reference")
        if any(ord(character) < 32 or ord(character) == 127 for character in locator):
            raise ValueError("secret reference must not contain ASCII control characters")

    def __str__(self) -> str:
        return "[SECRET_REF]"

    def __repr__(self) -> str:
        return "SecretReference([SECRET_REF])"

    def locator_for_storage(self) -> str:
        """Return the opaque locator only at an internal persistence boundary."""
        return self._locator


@dataclass(frozen=True)
class ActorContext:
    actor_type: ActorType
    actor_id: str
    authentication_id: str
    workspace_id: str
    roles: frozenset[Role]
    scopes: frozenset[str]
    authenticated_at_utc: datetime

    def __post_init__(self) -> None:
        if not isinstance(self.actor_type, ActorType):
            raise TypeError("actor_type must be an ActorType")
        _validated_identifier(self.actor_id, "actor_id")
        _validated_identifier(self.authentication_id, "authentication_id")
        _validated_identifier(self.workspace_id, "workspace_id")
        if not isinstance(self.roles, frozenset) or any(
            not isinstance(role, Role) for role in self.roles
        ):
            raise TypeError("roles must be a frozenset of Role values")
        if not isinstance(self.scopes, frozenset) or any(
            not isinstance(scope, str) for scope in self.scopes
        ):
            raise TypeError("scopes must be a frozenset of strings")
        if self.authenticated_at_utc.tzinfo is None:
            raise ValueError("authenticated_at_utc must be timezone-aware UTC")
        if self.authenticated_at_utc.utcoffset() != timedelta(0):
            raise ValueError("authenticated_at_utc must be UTC")
        if any(not scope or scope != scope.strip() for scope in self.scopes):
            raise ValueError("scopes must contain non-empty trimmed strings")


@dataclass(frozen=True)
class StoredSession:
    session_id: str
    user_id: str
    session_token_hash: str = field(repr=False)
    session_family_id: str
    rotated_from_session_id: str | None
    created_at: datetime
    expires_at: datetime
    revoked_at: datetime | None = None
    revocation_reason: str | None = None
    client_fingerprint_hash: str | None = field(default=None, repr=False)
    user_agent_hash: str | None = field(default=None, repr=False)


@dataclass(frozen=True)
class IssuedSession:
    session_id: str
    session_family_id: str
    raw_token_once: str = field(repr=False)
    expires_at: datetime


_SENSITIVE_KEY_FRAGMENTS = (
    "authorization",
    "cookie",
    "token",
    "secret",
    "password",
    "credential",
    "api_key",
    "access_key",
    "refresh",
    "pkce",
)


def _sensitive_key(key: object) -> bool:
    normalized = str(key).casefold().replace("-", "_")
    return any(fragment in normalized for fragment in _SENSITIVE_KEY_FRAGMENTS)


def mask_sensitive(value: Any) -> Any:
    """Return a recursively redacted copy suitable for diagnostic fields."""
    if isinstance(value, Mapping):
        return {
            key: "[REDACTED]" if _sensitive_key(key) else mask_sensitive(item)
            for key, item in value.items()
        }
    if isinstance(value, tuple):
        return tuple(mask_sensitive(item) for item in value)
    if isinstance(value, list):
        return [mask_sensitive(item) for item in value]
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return [mask_sensitive(item) for item in value]
    return value
