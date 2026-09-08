from __future__ import annotations

import asyncio
import json
from collections.abc import Callable
from uuid import UUID

from fastapi import Request, Response
from pytest import CaptureFixture, MonkeyPatch
from starlette.responses import JSONResponse

from custom_content_studio.api import correlate_request, health, health_live, health_ready
from custom_content_studio.cli import main as cli_main
from custom_content_studio.observability import Component, HealthStatus, liveness

HealthEndpoint = Callable[[Request, Response], dict[str, object]]


def _request(headers: tuple[tuple[bytes, bytes], ...] = ()) -> Request:
    return Request(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "GET",
            "scheme": "http",
            "path": "/health",
            "raw_path": b"/health",
            "query_string": b"",
            "headers": list(headers),
            "client": ("127.0.0.1", 50000),
            "server": ("127.0.0.1", 8000),
        }
    )


def _invoke(endpoint: HealthEndpoint, headers: tuple[tuple[bytes, bytes], ...] = ()) -> Response:
    async def call_next(request: Request) -> Response:
        response = Response()
        payload = endpoint(request, response)
        return JSONResponse(payload, status_code=response.status_code)

    return asyncio.run(correlate_request(_request(headers), call_next))


def _payload(response: Response) -> dict[str, object]:
    parsed = json.loads(response.body)
    assert isinstance(parsed, dict)
    return parsed


def test_liveness_has_no_configuration_dependency(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.delenv("CCS_ENV", raising=False)

    document = liveness(Component.API)

    assert document.status is HealthStatus.LIVE
    assert document.environment == "UNKNOWN"
    assert document.checks == ()


def test_api_health_contract_and_generated_correlation(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.setenv("CCS_ENV", "DEV")
    supplied = (
        (b"x-request-id", b"caller-request"),
        (b"x-correlation-id", b"caller-correlation"),
    )

    live = _invoke(health_live, supplied)
    ready = _invoke(health_ready, supplied)
    compatibility = _invoke(health, supplied)

    assert live.status_code == 200
    assert _payload(live)["status"] == "LIVE"
    assert _payload(live)["checks"] == []
    assert ready.status_code == 200
    assert _payload(ready)["status"] == "READY"
    ready_checks = _payload(ready)["checks"]
    assert isinstance(ready_checks, list)
    assert [check["name"] for check in ready_checks] == [
        "configuration",
        "scope",
        "runtime_paths",
    ]
    assert compatibility.status_code == 200
    assert _payload(compatibility)["status"] == "READY"
    for response in (live, ready, compatibility):
        request_id = response.headers["X-Request-ID"]
        correlation_id = response.headers["X-Correlation-ID"]
        assert UUID(request_id)
        assert UUID(correlation_id)
        assert request_id != "caller-request"
        assert correlation_id != "caller-correlation"
        payload = _payload(response)
        assert payload["request_id"] == request_id
        assert payload["correlation_id"] == correlation_id
        serialized = response.body.decode().casefold()
        assert "runtime_root" not in serialized
        assert "repository_root" not in serialized


def test_readiness_failure_is_safe_and_live_remains_available(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.delenv("CCS_ENV", raising=False)

    live = _invoke(health_live)
    ready = _invoke(health_ready)

    assert live.status_code == 200
    assert _payload(live)["status"] == "LIVE"
    assert ready.status_code == 503
    payload = _payload(ready)
    assert payload["status"] == "NOT_READY"
    assert payload["environment"] == "UNKNOWN"
    checks = payload["checks"]
    assert isinstance(checks, list)
    assert checks[0] == {
        "name": "configuration",
        "status": "NOT_READY",
        "diagnostic_code": "CONFIGURATION_INVALID",
    }
    serialized = json.dumps(payload).casefold()
    assert "traceback" not in serialized
    assert "e:\\" not in serialized


def test_cli_prints_common_ready_document(
    monkeypatch: MonkeyPatch,
    capsys: CaptureFixture[str],
) -> None:
    monkeypatch.setenv("CCS_LOG_FORMAT", "json")

    assert cli_main(["--environment", "DEV", "health"]) == 0
    captured = capsys.readouterr()
    payload = json.loads(captured.out)
    assert payload == {
        "checks": [
            {"name": "configuration", "status": "READY"},
            {"name": "scope", "status": "READY"},
            {"name": "runtime_paths", "status": "READY"},
        ],
        "component": "cli",
        "environment": "DEV",
        "service": "custom_content_studio",
        "status": "READY",
    }
    assert '"event":"startup.ready"' in captured.err
    assert "runtime_root" not in captured.out


def test_cli_returns_nonzero_with_safe_not_ready_document(
    monkeypatch: MonkeyPatch,
    capsys: CaptureFixture[str],
) -> None:
    monkeypatch.delenv("CCS_ENV", raising=False)

    assert cli_main(["health"]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "NOT_READY"
    checks = payload["checks"]
    assert isinstance(checks, list)
    assert checks[0]["diagnostic_code"] == "CONFIGURATION_INVALID"
