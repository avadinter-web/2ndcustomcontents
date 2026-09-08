from __future__ import annotations

import json
import logging
import re
import sys
from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import StrEnum
from typing import Final, TextIO, cast
from uuid import uuid4

from ..config import Environment, LogFormat, Settings
from ..domain.security import mask_sensitive

LOGGER_NAME: Final = "custom_content_studio"
_IDENTIFIER_LIMIT: Final = 128
_MESSAGE_LIMIT: Final = 512
_EVENT_PATTERN: Final = re.compile(r"^[a-z][a-z0-9_.-]{0,127}$")
_UNSAFE_MESSAGE_MARKERS: Final = (
    "authorization:",
    "bearer ",
    "cookie:",
    "password=",
    "secret=",
    "token=",
    "-----begin private key-----",
)


class Component(StrEnum):
    API = "api"
    UI = "ui"
    WORKER = "worker"
    SCHEDULER = "scheduler"
    CLI = "cli"
    BOOTSTRAP = "bootstrap"


def _validate_identifier(value: str | None, name: str) -> None:
    if value is None:
        return
    if (
        not isinstance(value, str)
        or not value
        or value != value.strip()
        or len(value) > _IDENTIFIER_LIMIT
        or not value.isprintable()
    ):
        raise ValueError(f"{name} must be a printable trimmed identifier of at most 128 chars")


@dataclass(frozen=True)
class ObservabilityContext:
    component: Component
    request_id: str | None = None
    correlation_id: str | None = None
    workspace_id: str | None = None
    operation_id: str | None = None
    attempt: int | None = None
    error_code: str | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.component, Component):
            raise TypeError("component must be a Component")
        for name in (
            "request_id",
            "correlation_id",
            "workspace_id",
            "operation_id",
            "error_code",
        ):
            _validate_identifier(getattr(self, name), name)
        if self.attempt is not None and (
            not isinstance(self.attempt, int) or isinstance(self.attempt, bool) or self.attempt < 1
        ):
            raise ValueError("attempt must be a positive integer")


def new_request_context(component: Component = Component.API) -> ObservabilityContext:
    """Create opaque identifiers at the trusted request boundary."""
    return ObservabilityContext(
        component=component,
        request_id=str(uuid4()),
        correlation_id=str(uuid4()),
    )


@dataclass(frozen=True)
class _StructuredEvent:
    environment: Environment
    context: ObservabilityContext
    event: str
    message: str

    def __post_init__(self) -> None:
        if not _EVENT_PATTERN.fullmatch(self.event):
            raise ValueError("event must be a bounded machine-readable name")
        if (
            not self.message
            or self.message != self.message.strip()
            or len(self.message) > _MESSAGE_LIMIT
            or not self.message.isprintable()
            or any(marker in self.message.casefold() for marker in _UNSAFE_MESSAGE_MARKERS)
        ):
            raise ValueError("message must be a bounded safe summary")

    def payload(self, record: logging.LogRecord) -> dict[str, object]:
        values: dict[str, object] = {
            "timestamp_utc": datetime.fromtimestamp(record.created, UTC)
            .isoformat()
            .replace("+00:00", "Z"),
            "level": record.levelname,
            "environment": self.environment.value,
            "component": self.context.component.value,
            "event": self.event,
            "message": self.message,
        }
        for name in (
            "request_id",
            "correlation_id",
            "workspace_id",
            "operation_id",
            "attempt",
            "error_code",
        ):
            value = getattr(self.context, name)
            if value is not None:
                values[name] = value
        return cast(dict[str, object], mask_sensitive(values))


class _StructuredFormatter(logging.Formatter):
    def __init__(self, output_format: LogFormat) -> None:
        super().__init__()
        self._output_format = output_format

    def format(self, record: logging.LogRecord) -> str:
        try:
            if not isinstance(record.msg, _StructuredEvent) or record.args:
                raise ValueError("unstructured record")
            payload = record.msg.payload(record)
        except Exception:
            payload = {
                "timestamp_utc": datetime.fromtimestamp(record.created, UTC)
                .isoformat()
                .replace("+00:00", "Z"),
                "level": "ERROR",
                "environment": "UNKNOWN",
                "component": "bootstrap",
                "event": "logging.format_error",
                "message": "structured log record rejected",
            }
        if self._output_format is LogFormat.JSON:
            return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        return " ".join(
            f"{key}={json.dumps(value, ensure_ascii=False, separators=(',', ':'))}"
            for key, value in payload.items()
        )


class _OwnedStreamHandler(logging.StreamHandler[TextIO]):
    _ccs_owned = True


@dataclass(frozen=True)
class LocalStructuredLogger:
    _logger: logging.Logger = field(repr=False)
    environment: Environment

    def emit(
        self,
        level: int,
        event: str,
        message: str,
        context: ObservabilityContext,
    ) -> None:
        self._logger.log(level, _StructuredEvent(self.environment, context, event, message))


def configure_local_logging(
    settings: Settings,
    *,
    stream: TextIO | None = None,
) -> LocalStructuredLogger:
    """Install one local stderr handler without touching root or unrelated handlers."""
    logger = logging.getLogger(LOGGER_NAME)
    for handler in tuple(logger.handlers):
        if isinstance(handler, _OwnedStreamHandler):
            logger.removeHandler(handler)
            handler.close()
    handler = _OwnedStreamHandler(stream if stream is not None else sys.stderr)
    handler.setFormatter(_StructuredFormatter(settings.log_format))
    handler.setLevel(settings.log_level.value)
    logger.addHandler(handler)
    logger.setLevel(settings.log_level.value)
    logger.propagate = False
    return LocalStructuredLogger(logger, settings.environment)


__all__ = [
    "LOGGER_NAME",
    "Component",
    "LocalStructuredLogger",
    "ObservabilityContext",
    "configure_local_logging",
    "new_request_context",
]
