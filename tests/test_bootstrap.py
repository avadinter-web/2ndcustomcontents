import json
from pathlib import Path

from pytest import CaptureFixture

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
    repository_root = (Path(__file__).parent / "fixture-repository").resolve()

    assert load_settings(Environment.DEV, repository_root).runtime_root == (
        repository_root / ".runtime" / "DEV"
    )


def test_health_route_exists() -> None:
    assert any(route.path == "/health" for route in app.routes)


def test_process_shells_clean_boot() -> None:
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
    assert cli_main(["health"]) == 0
    output = json.loads(capsys.readouterr().out)
    assert output["status"] == "ok"
    assert output["environment"] == "DEV"
