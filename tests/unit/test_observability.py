from __future__ import annotations

import io
import json
import logging
from uuid import UUID

import pytest
from pytest import MonkeyPatch

from custom_content_studio.config import Environment, LogFormat, load_settings
from custom_content_studio.observability import (
    LOGGER_NAME,
    Component,
    ObservabilityContext,
    configure_local_logging,
    new_request_context,
)


@pytest.fixture(autouse=True)
def restore_application_logger() -> None:
    logger = logging.getLogger(LOGGER_NAME)
    original_handlers = list(logger.handlers)
    original_level = logger.level
    original_propagate = logger.propagate
    yield
    for handler in tuple(logger.handlers):
        if handler not in original_handlers:
            logger.removeHandler(handler)
            handler.close()
    logger.handlers[:] = original_handlers
    logger.setLevel(original_level)
    logger.propagate = original_propagate


def test_generated_request_context_uses_distinct_opaque_uuids() -> None:
    first = new_request_context()
    second = new_request_context()

    assert first.component is Component.API
    assert UUID(first.request_id or "")
    assert UUID(first.correlation_id or "")
    assert first.request_id != first.correlation_id
    assert first.request_id != second.request_id


@pytest.mark.parametrize(
    "kwargs",
    [
        {"request_id": " padded"},
        {"correlation_id": "x" * 129},
        {"workspace_id": "line\nbreak"},
        {"attempt": 0},
        {"attempt": True},
    ],
)
def test_context_rejects_unbounded_or_invalid_values(kwargs: dict[str, object]) -> None:
    with pytest.raises((TypeError, ValueError)):
        ObservabilityContext(Component.API, **kwargs)  # type: ignore[arg-type]


def test_json_logger_is_structured_bounded_and_utc(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.setenv("CCS_LOG_FORMAT", LogFormat.JSON.value)
    settings = load_settings(Environment.DEV)
    stream = io.StringIO()
    context = ObservabilityContext(
        Component.API,
        request_id="request-1",
        correlation_id="correlation-1",
        workspace_id="workspace-1",
        operation_id="operation-1",
        attempt=2,
        error_code="SAFE_CODE",
    )

    configure_local_logging(settings, stream=stream).emit(
        logging.INFO,
        "request.completed",
        "local request completed",
        context,
    )

    payload = json.loads(stream.getvalue())
    assert list(payload) == [
        "timestamp_utc",
        "level",
        "environment",
        "component",
        "event",
        "message",
        "request_id",
        "correlation_id",
        "workspace_id",
        "operation_id",
        "attempt",
        "error_code",
    ]
    assert payload["timestamp_utc"].endswith("Z")
    assert payload["environment"] == "DEV"
    assert payload["component"] == "api"
    assert payload["request_id"] == "request-1"


def test_console_logger_emits_one_deterministic_line(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.setenv("CCS_LOG_FORMAT", LogFormat.CONSOLE.value)
    settings = load_settings(Environment.DEV)
    stream = io.StringIO()

    configure_local_logging(settings, stream=stream).emit(
        logging.WARNING,
        "startup.not_ready",
        "local startup checks did not pass",
        ObservabilityContext(Component.WORKER, error_code="SCOPE_INVALID"),
    )

    output = stream.getvalue()
    assert output.count("\n") == 1
    assert 'level="WARNING"' in output
    assert 'component="worker"' in output
    assert 'event="startup.not_ready"' in output
    assert 'error_code="SCOPE_INVALID"' in output


def test_configuration_is_idempotent_and_preserves_unrelated_handlers() -> None:
    settings = load_settings(Environment.DEV)
    logger = logging.getLogger(LOGGER_NAME)
    unrelated = logging.NullHandler()
    root_handlers = tuple(logging.getLogger().handlers)
    logger.addHandler(unrelated)

    configure_local_logging(settings, stream=io.StringIO())
    configure_local_logging(settings, stream=io.StringIO())

    assert unrelated in logger.handlers
    assert sum(bool(getattr(handler, "_ccs_owned", False)) for handler in logger.handlers) == 1
    assert tuple(logging.getLogger().handlers) == root_handlers
    assert logger.propagate is False


def test_unsafe_message_is_rejected_before_logging() -> None:
    settings = load_settings(Environment.DEV)
    stream = io.StringIO()
    local_logger = configure_local_logging(settings, stream=stream)

    with pytest.raises(ValueError, match="bounded safe summary"):
        local_logger.emit(
            logging.INFO,
            "request.completed",
            "Authorization: Bearer raw-secret",
            ObservabilityContext(Component.API),
        )
    assert "raw-secret" not in stream.getvalue()


def test_formatter_failure_emits_fixed_fallback_without_interpolation() -> None:
    settings = load_settings(Environment.DEV)
    stream = io.StringIO()
    configure_local_logging(settings, stream=stream)

    logging.getLogger(LOGGER_NAME).error("Bearer should-never-appear")

    output = stream.getvalue()
    assert "Bearer should-never-appear" not in output
    assert "logging.format_error" in output
    assert "structured log record rejected" in output
