from __future__ import annotations

from dataclasses import dataclass, field
from types import TracebackType
from typing import Self

import pytest

from custom_content_studio.application.ports import SecretLease, SecretStorePort
from custom_content_studio.domain.security import SecretReference, SecurityError

RAW_SECRET = "SYNTHETIC_TEST_SECRET_DO_NOT_USE"


@dataclass
class FakeLease:
    _value: str = field(repr=False)
    closed: bool = False

    def reveal(self) -> str:
        if self.closed:
            raise SecurityError("SECRET_LEASE_CLOSED", "secret lease is closed")
        return self._value

    def close(self) -> None:
        self.closed = True

    def __enter__(self) -> Self:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        del exc_type, exc_value, traceback
        self.close()

    def __repr__(self) -> str:
        return "FakeLease([REDACTED])"


class FakeSecretStore:
    def __init__(self, entries: dict[SecretReference, str]) -> None:
        self._entries = entries

    def resolve(self, secret_ref: SecretReference) -> FakeLease:
        try:
            return FakeLease(self._entries[secret_ref])
        except KeyError as error:
            raise SecurityError(
                "SECRET_REFERENCE_NOT_FOUND", "secret reference was not found"
            ) from error


def test_fake_conforms_to_port_and_closes_lease() -> None:
    reference = SecretReference("synthetic://known")
    store: SecretStorePort = FakeSecretStore({reference: RAW_SECRET})
    lease: SecretLease
    with store.resolve(reference) as lease:
        assert lease.reveal() == RAW_SECRET
        assert RAW_SECRET not in repr(lease)
    assert isinstance(lease, FakeLease)
    assert lease.closed
    with pytest.raises(SecurityError) as caught:
        lease.reveal()
    assert RAW_SECRET not in f"{caught.value!r} {caught.value}"


def test_unknown_reference_error_is_stable_and_non_secret() -> None:
    store = FakeSecretStore({SecretReference("synthetic://known"): RAW_SECRET})
    with pytest.raises(SecurityError) as caught:
        store.resolve(SecretReference("synthetic://missing"))
    assert caught.value.code == "SECRET_REFERENCE_NOT_FOUND"
    assert RAW_SECRET not in f"{caught.value!r} {caught.value}"
    assert "synthetic://missing" not in f"{caught.value!r} {caught.value}"
