from __future__ import annotations

import secrets
import sqlite3
from datetime import datetime, timedelta
from uuid import uuid4

from ...domain.security import (
    ActorContext,
    ActorType,
    IssuedSession,
    SecurityError,
    StoredSession,
)
from ...persistence import SQLiteConnectionFactory, SQLiteUnitOfWork
from ..ports import SessionRepositoryPort


def _require_utc(value: datetime, name: str) -> None:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise ValueError(f"{name} must be timezone-aware UTC")


def _require_identifier(value: str, name: str) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"{name} must be a non-empty trimmed string")
    return value


class SessionService:
    def __init__(
        self,
        factory: SQLiteConnectionFactory,
        repository: SessionRepositoryPort,
    ) -> None:
        self._factory = factory
        self._repository = repository

    def issue(
        self,
        user_id: str,
        now_utc: datetime,
        expires_at: datetime,
        client_fingerprint_hash: str | None = None,
        user_agent_hash: str | None = None,
    ) -> IssuedSession:
        _require_identifier(user_id, "user_id")
        self._validate_interval(now_utc, expires_at)
        with SQLiteUnitOfWork(self._factory) as uow:
            if not self._repository.user_is_active(uow.connection, user_id):
                raise SecurityError("SESSION_EXPIRED", "user is not active")
            issued = self._new_session(
                user_id=user_id,
                now_utc=now_utc,
                expires_at=expires_at,
                session_family_id=None,
                rotated_from_session_id=None,
                client_fingerprint_hash=client_fingerprint_hash,
                user_agent_hash=user_agent_hash,
            )
            self._repository.add(uow.connection, issued[1], issued[0].raw_token_once)
            uow.commit()
            return issued[0]

    def authenticate(
        self,
        raw_token: str,
        workspace_id: str,
        now_utc: datetime,
    ) -> ActorContext:
        _require_identifier(workspace_id, "workspace_id")
        _require_utc(now_utc, "now_utc")
        with SQLiteUnitOfWork(self._factory) as uow:
            session = self._authenticate_session(uow.connection, raw_token, now_utc)
            role = self._repository.role_for_workspace(
                uow.connection, session.user_id, workspace_id
            )
            if role is None:
                raise SecurityError("WORKSPACE_ACCESS_DENIED", "workspace access is not permitted")
            self._repository.mark_seen(uow.connection, session.session_id, now_utc)
            actor = ActorContext(
                actor_type=ActorType.USER,
                actor_id=session.user_id,
                authentication_id=session.session_id,
                workspace_id=workspace_id,
                roles=frozenset({role}),
                scopes=frozenset(),
                authenticated_at_utc=now_utc,
            )
            uow.commit()
            return actor

    def rotate(
        self,
        raw_token: str,
        now_utc: datetime,
        expires_at: datetime,
    ) -> IssuedSession:
        self._validate_interval(now_utc, expires_at)
        with SQLiteUnitOfWork(self._factory) as uow:
            old_session = self._authenticate_session(uow.connection, raw_token, now_utc)
            issued, stored = self._new_session(
                user_id=old_session.user_id,
                now_utc=now_utc,
                expires_at=expires_at,
                session_family_id=old_session.session_family_id,
                rotated_from_session_id=old_session.session_id,
                client_fingerprint_hash=old_session.client_fingerprint_hash,
                user_agent_hash=old_session.user_agent_hash,
            )
            self._repository.add(uow.connection, stored, issued.raw_token_once)
            self._repository.revoke(uow.connection, old_session.session_id, "ROTATED", now_utc)
            uow.commit()
            return issued

    def revoke(self, session_id: str, reason: str, now_utc: datetime) -> None:
        _require_identifier(session_id, "session_id")
        _require_identifier(reason, "reason")
        _require_utc(now_utc, "now_utc")
        with SQLiteUnitOfWork(self._factory) as uow:
            self._repository.revoke(uow.connection, session_id, reason, now_utc)
            uow.commit()

    def _authenticate_session(
        self,
        connection: sqlite3.Connection,
        raw_token: str,
        now_utc: datetime,
    ) -> StoredSession:
        if not isinstance(raw_token, str) or not raw_token:
            raise SecurityError("AUTHENTICATION_REQUIRED", "valid authentication is required")
        session = self._repository.find_by_token(connection, raw_token)
        if session is None:
            raise SecurityError("AUTHENTICATION_REQUIRED", "valid authentication is required")
        if session.revoked_at is not None or session.expires_at <= now_utc:
            raise SecurityError("SESSION_EXPIRED", "session is no longer active")
        if not self._repository.user_is_active(connection, session.user_id):
            raise SecurityError("SESSION_EXPIRED", "session is no longer active")
        return session

    @staticmethod
    def _new_session(
        *,
        user_id: str,
        now_utc: datetime,
        expires_at: datetime,
        session_family_id: str | None,
        rotated_from_session_id: str | None,
        client_fingerprint_hash: str | None,
        user_agent_hash: str | None,
    ) -> tuple[IssuedSession, StoredSession]:
        session_id = uuid4().hex
        family_id = session_family_id or session_id
        random_secret = secrets.token_urlsafe(32)
        raw_token = f"v1.{session_id}.{random_secret}"
        issued = IssuedSession(session_id, family_id, raw_token, expires_at)
        stored = StoredSession(
            session_id=session_id,
            user_id=user_id,
            session_token_hash="[PENDING_HASH]",
            session_family_id=family_id,
            rotated_from_session_id=rotated_from_session_id,
            created_at=now_utc,
            expires_at=expires_at,
            client_fingerprint_hash=client_fingerprint_hash,
            user_agent_hash=user_agent_hash,
        )
        return issued, stored

    @staticmethod
    def _validate_interval(now_utc: datetime, expires_at: datetime) -> None:
        _require_utc(now_utc, "now_utc")
        _require_utc(expires_at, "expires_at")
        if expires_at <= now_utc:
            raise ValueError("expires_at must be later than now_utc")
