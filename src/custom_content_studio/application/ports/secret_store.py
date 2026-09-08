from __future__ import annotations

from types import TracebackType
from typing import Protocol, Self

from ...domain.security import SecretReference


class SecretLease(Protocol):
    def reveal(self) -> str: ...

    def close(self) -> None: ...

    def __enter__(self) -> Self: ...

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None: ...


class SecretStorePort(Protocol):
    def resolve(self, secret_ref: SecretReference) -> SecretLease: ...
