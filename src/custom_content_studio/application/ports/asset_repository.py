from __future__ import annotations

import sqlite3
from typing import Protocol

from ...domain.assets import Asset


class AssetRepositoryError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        super().__init__(f"{code}: {message}")


class AssetAlreadyExistsError(AssetRepositoryError):
    def __init__(self) -> None:
        super().__init__(
            "ASSET_ALREADY_EXISTS", "asset identity or storage reference already exists"
        )


class AssetNotFoundError(AssetRepositoryError):
    def __init__(self) -> None:
        super().__init__("ASSET_SCOPE_NOT_FOUND", "asset or project is not available in workspace")


class AssetConflictError(AssetRepositoryError):
    def __init__(self) -> None:
        super().__init__("ASSET_VERSION_CONFLICT", "asset row version is stale")


class AssetArchivedError(AssetRepositoryError):
    def __init__(self) -> None:
        super().__init__("ASSET_ARCHIVED", "archived asset cannot be changed")


class AssetRepositoryPort(Protocol):
    def create(self, connection: sqlite3.Connection, asset: Asset) -> None: ...

    def get_by_id(
        self, connection: sqlite3.Connection, workspace_id: str, asset_id: str
    ) -> Asset | None: ...

    def list_active(
        self, connection: sqlite3.Connection, workspace_id: str
    ) -> tuple[Asset, ...]: ...

    def update(self, connection: sqlite3.Connection, asset: Asset) -> Asset: ...
