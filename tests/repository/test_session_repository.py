from __future__ import annotations

import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from custom_content_studio.application.services import SessionService
from custom_content_studio.domain.security import SecurityError, StoredSession
from custom_content_studio.infrastructure.sqlite.repositories import (
    SQLiteSessionRepository,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
NOW = datetime(2026, 9, 8, tzinfo=UTC)
SESSION_ID = "0123456789abcdef0123456789abcdef"
RAW_TOKEN = f"v1.{SESSION_ID}.{'A' * 43}"


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    factory = SQLiteConnectionFactory((tmp_path / "sessions.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _insert_user(connection: sqlite3.Connection, user_id: str = "user-1") -> None:
    connection.execute(
        "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
        "VALUES (?,?,?,'ACTIVE',?,?)",
        (
            user_id,
            f"{user_id}@example.test",
            f"{user_id}@example.test",
            "2026-09-08T00:00:00Z",
            "2026-09-08T00:00:00Z",
        ),
    )


def _session() -> StoredSession:
    return StoredSession(
        session_id=SESSION_ID,
        user_id="user-1",
        session_token_hash="[PENDING_HASH]",
        session_family_id=SESSION_ID,
        rotated_from_session_id=None,
        created_at=NOW,
        expires_at=NOW + timedelta(hours=1),
    )


def _seed(factory: SQLiteConnectionFactory) -> SQLiteSessionRepository:
    repository = SQLiteSessionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _insert_user(uow.connection)
        repository.add(uow.connection, _session(), RAW_TOKEN)
        uow.commit()
    return repository


def test_fresh_database_persists_hash_only(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    connection = factory.connect()
    try:
        rows = connection.execute("SELECT id,session_token_hash FROM auth_sessions").fetchall()
    finally:
        connection.close()
    assert len(rows) == 1
    assert str(rows[0]["id"]) == SESSION_ID
    encoded = str(rows[0]["session_token_hash"])
    assert encoded.startswith("scrypt$n=16384,r=8,p=1,l=32$")
    assert RAW_TOKEN not in encoded
    assert (tmp_path / "sessions.sqlite3").read_bytes().find(RAW_TOKEN.encode()) == -1


def test_lookup_accepts_correct_and_rejects_wrong_or_malformed_token(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    factory = _factory(tmp_path)
    repository = _seed(factory)
    import custom_content_studio.infrastructure.sqlite.repositories.sessions as module

    original_compare = module.hmac.compare_digest
    calls: list[tuple[bytes, bytes]] = []

    def observed_compare(actual: bytes, expected: bytes) -> bool:
        calls.append((actual, expected))
        return original_compare(actual, expected)

    monkeypatch.setattr(module.hmac, "compare_digest", observed_compare)
    connection = factory.connect()
    try:
        assert repository.find_by_token(connection, RAW_TOKEN) is not None
        wrong = f"v1.{SESSION_ID}.{'B' * 43}"
        assert repository.find_by_token(connection, wrong) is None
        assert repository.find_by_token(connection, "not-a-token") is None
    finally:
        connection.close()
    assert len(calls) == 2


def test_database_trigger_rejects_identity_mutation(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    _seed(factory)
    with (
        SQLiteUnitOfWork(factory) as uow,
        pytest.raises(sqlite3.IntegrityError, match="session identity is immutable"),
    ):
        uow.connection.execute(
            "UPDATE auth_sessions SET session_family_id='changed' WHERE id=?",
            (SESSION_ID,),
        )


def test_revocation_is_one_way_and_reason_bound(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = _seed(factory)
    with SQLiteUnitOfWork(factory) as uow:
        repository.revoke(uow.connection, SESSION_ID, "USER_REQUEST", NOW + timedelta(minutes=1))
        repository.revoke(uow.connection, SESSION_ID, "USER_REQUEST", NOW + timedelta(minutes=2))
        with pytest.raises(SecurityError) as caught:
            repository.revoke(uow.connection, SESSION_ID, "CHANGED", NOW + timedelta(minutes=2))
        assert caught.value.code == "SESSION_STATE_CONFLICT"
        uow.commit()
    with (
        SQLiteUnitOfWork(factory) as uow,
        pytest.raises(sqlite3.IntegrityError, match="one-way"),
    ):
        uow.connection.execute(
            "UPDATE auth_sessions SET revoked_at=NULL,revocation_reason=NULL WHERE id=?",
            (SESSION_ID,),
        )


def test_rotation_linkage_is_durable_and_old_token_is_rejected(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteSessionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _insert_user(uow.connection)
        uow.commit()
    service = SessionService(factory, repository)
    first = service.issue("user-1", NOW, NOW + timedelta(hours=1))
    second = service.rotate(
        first.raw_token_once, NOW + timedelta(minutes=1), NOW + timedelta(hours=2)
    )

    reopened = factory.connect()
    try:
        new_row = reopened.execute(
            "SELECT session_family_id,rotated_from_session_id FROM auth_sessions WHERE id=?",
            (second.session_id,),
        ).fetchone()
        old = repository.find_by_token(reopened, first.raw_token_once)
        new = repository.find_by_token(reopened, second.raw_token_once)
    finally:
        reopened.close()
    assert tuple(new_row) == (first.session_family_id, first.session_id)
    assert old is not None and old.revocation_reason == "ROTATED"
    assert new is not None and new.revoked_at is None


def test_repository_does_not_commit_caller_transaction(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    repository = SQLiteSessionRepository()
    with SQLiteUnitOfWork(factory) as uow:
        _insert_user(uow.connection)
        repository.add(uow.connection, _session(), RAW_TOKEN)

    connection = factory.connect()
    try:
        assert connection.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0
        assert connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0] == 0
    finally:
        connection.close()
