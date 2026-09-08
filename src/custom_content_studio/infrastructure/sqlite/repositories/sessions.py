from __future__ import annotations

import base64
import hashlib
import hmac
import re
import secrets
import sqlite3
from datetime import UTC, datetime

from ....domain.security import Role, SecurityError, StoredSession

_TOKEN_PATTERN = re.compile(r"v1\.([0-9a-f]{32})\.([A-Za-z0-9_-]{43})")
_HASH_PATTERN = re.compile(
    r"scrypt\$n=(\d+),r=(\d+),p=(\d+),l=(\d+)\$([A-Za-z0-9_-]+)\$([A-Za-z0-9_-]+)"
)
_SCRYPT_N = 1 << 14
_SCRYPT_R = 8
_SCRYPT_P = 1
_DKLEN = 32
_SALT_BYTES = 16
_SCRYPT_MAXMEM = 32 * 1024 * 1024


def _encode_binary(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _decode_binary(value: str, expected_length: int) -> bytes:
    if len(value) > 128:
        raise ValueError("encoded value is too long")
    decoded = base64.b64decode(value + "=" * (-len(value) % 4), altchars=b"-_", validate=True)
    if len(decoded) != expected_length:
        raise ValueError("encoded value has unexpected length")
    return decoded


def _token_session_id(raw_token: str) -> str | None:
    if len(raw_token) > 128:
        return None
    match = _TOKEN_PATTERN.fullmatch(raw_token)
    return match.group(1) if match is not None else None


def encode_token_hash(raw_token: str) -> str:
    if _token_session_id(raw_token) is None:
        raise ValueError("raw token has invalid format")
    salt = secrets.token_bytes(_SALT_BYTES)
    digest = hashlib.scrypt(
        raw_token.encode("utf-8"),
        salt=salt,
        n=_SCRYPT_N,
        r=_SCRYPT_R,
        p=_SCRYPT_P,
        dklen=_DKLEN,
        maxmem=_SCRYPT_MAXMEM,
    )
    return (
        f"scrypt$n={_SCRYPT_N},r={_SCRYPT_R},p={_SCRYPT_P},l={_DKLEN}"
        f"${_encode_binary(salt)}${_encode_binary(digest)}"
    )


def verify_token_hash(raw_token: str, encoded_hash: str) -> bool:
    if _token_session_id(raw_token) is None or len(encoded_hash) > 256:
        return False
    match = _HASH_PATTERN.fullmatch(encoded_hash)
    if match is None:
        return False
    try:
        n, r, p, length = (int(match.group(index)) for index in range(1, 5))
        if (n, r, p, length) != (_SCRYPT_N, _SCRYPT_R, _SCRYPT_P, _DKLEN):
            return False
        salt = _decode_binary(match.group(5), _SALT_BYTES)
        expected = _decode_binary(match.group(6), _DKLEN)
        actual = hashlib.scrypt(
            raw_token.encode("utf-8"),
            salt=salt,
            n=n,
            r=r,
            p=p,
            dklen=length,
            maxmem=_SCRYPT_MAXMEM,
        )
    except (ValueError, OverflowError):
        return False
    return hmac.compare_digest(actual, expected)


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _datetime(value: object) -> datetime:
    if not isinstance(value, str):
        raise SecurityError("SESSION_DATA_INVALID", "session timestamp is invalid")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise SecurityError("SESSION_DATA_INVALID", "session timestamp is invalid") from error
    if parsed.tzinfo is None:
        raise SecurityError("SESSION_DATA_INVALID", "session timestamp is invalid")
    return parsed.astimezone(UTC)


def _optional_datetime(value: object) -> datetime | None:
    return None if value is None else _datetime(value)


def _to_session(row: sqlite3.Row) -> StoredSession:
    return StoredSession(
        session_id=str(row["id"]),
        user_id=str(row["user_id"]),
        session_token_hash=str(row["session_token_hash"]),
        session_family_id=str(row["session_family_id"]),
        rotated_from_session_id=(
            None if row["rotated_from_session_id"] is None else str(row["rotated_from_session_id"])
        ),
        created_at=_datetime(row["created_at"]),
        expires_at=_datetime(row["expires_at"]),
        revoked_at=_optional_datetime(row["revoked_at"]),
        revocation_reason=(
            None if row["revocation_reason"] is None else str(row["revocation_reason"])
        ),
        client_fingerprint_hash=(
            None if row["client_fingerprint_hash"] is None else str(row["client_fingerprint_hash"])
        ),
        user_agent_hash=(None if row["user_agent_hash"] is None else str(row["user_agent_hash"])),
    )


class SQLiteSessionRepository:
    def add(
        self,
        connection: sqlite3.Connection,
        session: StoredSession,
        raw_token: str,
    ) -> None:
        if _token_session_id(raw_token) != session.session_id:
            raise SecurityError("SESSION_DATA_INVALID", "session token identity is invalid")
        encoded_hash = encode_token_hash(raw_token)
        connection.execute(
            "INSERT INTO auth_sessions("
            "id,user_id,session_token_hash,session_family_id,rotated_from_session_id,"
            "created_at,expires_at,last_seen_at,revoked_at,revocation_reason,"
            "client_fingerprint_hash,user_agent_hash) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                session.session_id,
                session.user_id,
                encoded_hash,
                session.session_family_id,
                session.rotated_from_session_id,
                _iso(session.created_at),
                _iso(session.expires_at),
                _iso(session.created_at),
                None,
                None,
                session.client_fingerprint_hash,
                session.user_agent_hash,
            ),
        )

    def find_by_token(self, connection: sqlite3.Connection, raw_token: str) -> StoredSession | None:
        session_id = _token_session_id(raw_token)
        if session_id is None:
            return None
        row = connection.execute("SELECT * FROM auth_sessions WHERE id=?", (session_id,)).fetchone()
        if row is None or not verify_token_hash(raw_token, str(row["session_token_hash"])):
            return None
        return _to_session(row)

    def get(self, connection: sqlite3.Connection, session_id: str) -> StoredSession | None:
        row = connection.execute("SELECT * FROM auth_sessions WHERE id=?", (session_id,)).fetchone()
        return None if row is None else _to_session(row)

    def user_is_active(self, connection: sqlite3.Connection, user_id: str) -> bool:
        return (
            connection.execute(
                "SELECT 1 FROM users WHERE id=? AND status='ACTIVE'", (user_id,)
            ).fetchone()
            is not None
        )

    def role_for_workspace(
        self,
        connection: sqlite3.Connection,
        user_id: str,
        workspace_id: str,
    ) -> Role | None:
        row = connection.execute(
            "SELECT wm.role FROM workspace_memberships wm "
            "JOIN users u ON u.id=wm.user_id "
            "WHERE wm.user_id=? AND wm.workspace_id=? AND u.status='ACTIVE'",
            (user_id, workspace_id),
        ).fetchone()
        return None if row is None else Role(str(row["role"]))

    def mark_seen(
        self,
        connection: sqlite3.Connection,
        session_id: str,
        seen_at_utc: datetime,
    ) -> None:
        connection.execute(
            "UPDATE auth_sessions SET last_seen_at=? WHERE id=? AND last_seen_at<?",
            (_iso(seen_at_utc), session_id, _iso(seen_at_utc)),
        )

    def revoke(
        self,
        connection: sqlite3.Connection,
        session_id: str,
        reason: str,
        revoked_at_utc: datetime,
    ) -> None:
        if not isinstance(reason, str) or not reason or reason != reason.strip():
            raise SecurityError("SESSION_STATE_CONFLICT", "revocation reason is invalid")
        session = self.get(connection, session_id)
        if session is None:
            raise SecurityError("SESSION_NOT_FOUND", "session does not exist")
        if session.revoked_at is not None:
            if session.revocation_reason == reason:
                return
            raise SecurityError("SESSION_STATE_CONFLICT", "session revocation is reason-bound")
        if revoked_at_utc < session.created_at:
            raise SecurityError("SESSION_STATE_CONFLICT", "revocation time is invalid")
        cursor = connection.execute(
            "UPDATE auth_sessions SET revoked_at=?,revocation_reason=? "
            "WHERE id=? AND revoked_at IS NULL",
            (_iso(revoked_at_utc), reason, session_id),
        )
        if cursor.rowcount != 1:
            raise SecurityError("SESSION_STATE_CONFLICT", "session state changed")
