from __future__ import annotations

import threading
import time
from pathlib import Path

import pytest

from custom_content_studio.persistence import (
    MigrationRunner,
    PersistenceError,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"


def _factory(tmp_path: Path) -> SQLiteConnectionFactory:
    database_path = (tmp_path / "studio.sqlite3").resolve()
    assert database_path.parent == tmp_path.resolve()
    factory = SQLiteConnectionFactory(database_path)
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    return factory


def _insert_user(uow: SQLiteUnitOfWork, user_id: str) -> None:
    uow.connection.execute(
        "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
        "VALUES (?,?,?,'ACTIVE','2026-09-08T00:00:00Z','2026-09-08T00:00:00Z')",
        (user_id, f"{user_id}@example.test", f"{user_id}@example.test"),
    )


def _count_users(factory: SQLiteConnectionFactory) -> int:
    connection = factory.connect()
    try:
        return int(connection.execute("SELECT COUNT(*) FROM users").fetchone()[0])
    finally:
        connection.close()


def test_explicit_commit_persists(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    with SQLiteUnitOfWork(factory) as uow:
        _insert_user(uow, "committed")
        uow.commit()
    assert _count_users(factory) == 1


def test_explicit_rollback_does_not_persist(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    with SQLiteUnitOfWork(factory) as uow:
        _insert_user(uow, "rolled-back")
        uow.rollback()
    assert _count_users(factory) == 0


def test_exception_rolls_back(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    with pytest.raises(RuntimeError, match="injected"):
        with SQLiteUnitOfWork(factory) as uow:
            _insert_user(uow, "exception")
            raise RuntimeError("injected")
    assert _count_users(factory) == 0


def test_normal_exit_without_commit_rolls_back(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    with SQLiteUnitOfWork(factory) as uow:
        _insert_user(uow, "implicit-rollback")
    assert _count_users(factory) == 0


def test_finished_and_closed_unit_of_work_rejects_use(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    uow = SQLiteUnitOfWork(factory)
    with uow:
        uow.commit()
        with pytest.raises(PersistenceError, match="UNIT_OF_WORK_FINISHED"):
            uow.rollback()
    with pytest.raises(PersistenceError, match="UNIT_OF_WORK_NOT_ACTIVE"):
        _ = uow.connection
    with pytest.raises(PersistenceError, match="UNIT_OF_WORK_NOT_ACTIVE"):
        uow.commit()


def test_second_writer_waits_and_keeps_busy_timeout(tmp_path: Path) -> None:
    factory = _factory(tmp_path)
    started = threading.Event()
    acquired = threading.Event()
    observed_timeout: list[int] = []

    def second_writer() -> None:
        started.set()
        with SQLiteUnitOfWork(factory) as uow:
            observed_timeout.append(
                int(uow.connection.execute("PRAGMA busy_timeout").fetchone()[0])
            )
            acquired.set()
            uow.rollback()

    with SQLiteUnitOfWork(factory):
        worker = threading.Thread(target=second_writer)
        worker.start()
        assert started.wait(timeout=1)
        time.sleep(0.05)
        assert not acquired.is_set()
    worker.join(timeout=2)

    assert not worker.is_alive()
    assert acquired.is_set()
    assert observed_timeout == [5000]
