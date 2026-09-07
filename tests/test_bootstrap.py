from pathlib import Path

from custom_content_studio.api import app
from custom_content_studio.config import Environment, load_settings
from custom_content_studio.workers import main as worker_main


def test_settings_are_repository_scoped(tmp_path: Path) -> None:
    assert load_settings(Environment.DEV, tmp_path).runtime_root == tmp_path / ".runtime" / "DEV"


def test_health_route_exists() -> None:
    assert any(route.path == "/health" for route in app.routes)


def test_worker_shell_is_importable() -> None:
    assert worker_main() is None
