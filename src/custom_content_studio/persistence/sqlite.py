from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from pathlib import Path


class PersistenceError(RuntimeError):
    """Stable persistence boundary error without leaking sqlite exceptions."""

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class DatabaseConfigurationError(PersistenceError):
    def __init__(self, message: str) -> None:
        super().__init__("DATABASE_CONFIGURATION_FAILED", message)


@dataclass(frozen=True)
class SQLiteConnectionFactory:
    database_path: Path
    busy_timeout_ms: int = 5000

    def __post_init__(self) -> None:
        if not self.database_path.is_absolute():
            raise DatabaseConfigurationError("database path must be absolute")
        if self.busy_timeout_ms <= 0:
            raise DatabaseConfigurationError("busy timeout must be positive")

    def connect(self) -> sqlite3.Connection:
        if not self.database_path.parent.is_dir():
            raise DatabaseConfigurationError("database parent directory must exist")

        connection: sqlite3.Connection | None = None
        try:
            connection = sqlite3.connect(
                self.database_path,
                timeout=self.busy_timeout_ms / 1000,
                isolation_level=None,
            )
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA foreign_keys = ON")
            journal_row = connection.execute("PRAGMA journal_mode = WAL").fetchone()
            connection.execute(f"PRAGMA busy_timeout = {self.busy_timeout_ms:d}")
            foreign_keys_row = connection.execute("PRAGMA foreign_keys").fetchone()
            busy_timeout_row = connection.execute("PRAGMA busy_timeout").fetchone()

            journal_mode = str(journal_row[0]).casefold() if journal_row is not None else ""
            foreign_keys = int(foreign_keys_row[0]) if foreign_keys_row is not None else 0
            busy_timeout = int(busy_timeout_row[0]) if busy_timeout_row is not None else 0
            if journal_mode != "wal":
                raise DatabaseConfigurationError("journal_mode must be WAL")
            if foreign_keys != 1:
                raise DatabaseConfigurationError("foreign_keys must be ON")
            if busy_timeout != self.busy_timeout_ms:
                raise DatabaseConfigurationError("busy_timeout verification failed")
            return connection
        except PersistenceError:
            if connection is not None:
                connection.close()
            raise
        except sqlite3.Error as error:
            if connection is not None:
                connection.close()
            raise DatabaseConfigurationError("unable to configure SQLite connection") from error
