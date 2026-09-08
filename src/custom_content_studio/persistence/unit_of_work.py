from __future__ import annotations

import sqlite3
from types import TracebackType

from .sqlite import PersistenceError, SQLiteConnectionFactory


class SQLiteUnitOfWork:
    def __init__(self, factory: SQLiteConnectionFactory) -> None:
        self._factory = factory
        self._connection: sqlite3.Connection | None = None
        self._finished = False

    @property
    def connection(self) -> sqlite3.Connection:
        if self._connection is None:
            raise PersistenceError("UNIT_OF_WORK_NOT_ACTIVE", "unit of work is not active")
        return self._connection

    def __enter__(self) -> SQLiteUnitOfWork:
        if self._connection is not None:
            raise PersistenceError("UNIT_OF_WORK_ALREADY_ACTIVE", "unit of work is already active")
        connection = self._factory.connect()
        try:
            connection.execute("BEGIN IMMEDIATE")
        except sqlite3.Error as error:
            connection.close()
            raise PersistenceError(
                "UNIT_OF_WORK_BEGIN_FAILED", "unable to begin transaction"
            ) from error
        self._connection = connection
        self._finished = False
        return self

    def commit(self) -> None:
        connection = self._active_unfinished_connection()
        try:
            connection.execute("COMMIT")
        except sqlite3.Error as error:
            raise PersistenceError("UNIT_OF_WORK_COMMIT_FAILED", "unable to commit") from error
        self._finished = True

    def rollback(self) -> None:
        connection = self._active_unfinished_connection()
        try:
            connection.execute("ROLLBACK")
        except sqlite3.Error as error:
            raise PersistenceError("UNIT_OF_WORK_ROLLBACK_FAILED", "unable to roll back") from error
        self._finished = True

    def _active_unfinished_connection(self) -> sqlite3.Connection:
        connection = self._connection
        if connection is None:
            raise PersistenceError("UNIT_OF_WORK_NOT_ACTIVE", "unit of work is not active")
        if self._finished:
            raise PersistenceError("UNIT_OF_WORK_FINISHED", "transaction is already finished")
        return connection

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        del exc_type, exc_value, traceback
        connection = self._connection
        if connection is None:
            return
        try:
            if not self._finished and connection.in_transaction:
                connection.execute("ROLLBACK")
        except sqlite3.Error as error:
            raise PersistenceError("UNIT_OF_WORK_ROLLBACK_FAILED", "unable to roll back") from error
        finally:
            connection.close()
            self._connection = None
            self._finished = True
