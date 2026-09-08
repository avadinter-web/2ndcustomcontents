import json

from pytest import CaptureFixture, MonkeyPatch

from custom_content_studio.api import app
from custom_content_studio.api import main as api_main
from custom_content_studio.bootstrap import main as bootstrap_main
from custom_content_studio.cli import main as cli_main
from custom_content_studio.config import Environment, load_settings
from custom_content_studio.scheduler import main as scheduler_main
from custom_content_studio.ui import main as ui_main
from custom_content_studio.worker import main as compatibility_worker_main
from custom_content_studio.workers import main as worker_main


def test_settings_are_repository_scoped() -> None:
    settings = load_settings(Environment.DEV)

    assert settings.runtime_root == settings.repository_root / ".runtime" / "DEV"


def test_health_routes_exist() -> None:
    paths = {route.path for route in app.routes}

    assert {"/health", "/health/live", "/health/ready"} <= paths


def test_process_shells_clean_boot(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.setenv("CCS_ENV", "DEV")
    entrypoints = (
        bootstrap_main,
        api_main,
        ui_main,
        worker_main,
        compatibility_worker_main,
        scheduler_main,
    )

    assert all(entrypoint().environment is Environment.DEV for entrypoint in entrypoints)


def test_cli_health(capsys: CaptureFixture[str]) -> None:
    assert cli_main(["--environment", "DEV", "health"]) == 0
    output = json.loads(capsys.readouterr().out)
    assert output["status"] == "READY"
    assert output["environment"] == "DEV"
    assert "runtime_root" not in output
