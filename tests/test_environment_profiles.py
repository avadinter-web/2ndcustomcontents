import json
from pathlib import Path

import pytest
from pytest import CaptureFixture, MonkeyPatch

from custom_content_studio.bootstrap import bootstrap
from custom_content_studio.cli import main as cli_main
from custom_content_studio.config import ConfigurationError, Environment, load_settings


def _write_profile(root: Path, environment: Environment, extra: str = "") -> None:
    config_root = root / "config"
    config_root.mkdir(parents=True, exist_ok=True)
    (config_root / f"{environment.value.lower()}.toml").write_text(
        f'environment = "{environment.value}"\n{extra}', encoding="utf-8"
    )


@pytest.mark.parametrize("environment", list(Environment))
def test_each_profile_uses_its_fixed_path(environment: Environment) -> None:
    settings = load_settings(environment)

    assert settings.environment is environment
    assert settings.runtime_root == settings.repository_root / ".runtime" / environment.value


def test_explicit_selector_wins_over_process_environment() -> None:
    settings = load_settings(Environment.PROD, environ={"CCS_ENV": "DEV"})

    assert settings.environment is Environment.PROD


def test_process_override_wins_over_profile_value() -> None:
    settings = load_settings(
        Environment.DEV,
        environ={"CCS_API_PORT": "8999"},
    )

    assert settings.api_port == 8999


def test_missing_or_unknown_selector_fails_closed() -> None:
    with pytest.raises(ConfigurationError, match="environment must be selected"):
        load_settings(environ={})
    with pytest.raises(ConfigurationError, match="exactly one of DEV"):
        load_settings("dev", environ={})


def test_missing_profile_and_environment_mismatch_fail_closed(tmp_path: Path) -> None:
    with pytest.raises(ConfigurationError, match="profile file is required"):
        load_settings(Environment.DEV, tmp_path)

    config_root = tmp_path / "config"
    config_root.mkdir()
    (config_root / "dev.toml").write_text('environment = "STAGING"\n', encoding="utf-8")
    with pytest.raises(ConfigurationError, match="must match the selector"):
        load_settings(Environment.DEV, tmp_path)


@pytest.mark.parametrize(
    ("environment", "extra", "rule"),
    [
        (Environment.STAGING, "debug = true\n", "debug must be false"),
        (Environment.PROD, 'log_format = "console"\n', "PROD log_format must be json"),
        (Environment.DEV, 'api_host = "192.0.2.1"\n', "profile settings failed validation"),
        (Environment.DEV, "api_port = 0\n", "profile settings failed validation"),
        (Environment.DEV, "kill_publish = false\n", "publish and scheduler"),
    ],
)
def test_unsafe_profile_values_fail_closed(
    tmp_path: Path, environment: Environment, extra: str, rule: str
) -> None:
    _write_profile(tmp_path, environment, extra)

    with pytest.raises(ConfigurationError, match=rule):
        load_settings(environment, tmp_path)


def test_unknown_and_secret_like_settings_are_rejected_without_value_disclosure(
    tmp_path: Path,
) -> None:
    _write_profile(tmp_path, Environment.DEV, 'token = "do-not-disclose"\n')

    with pytest.raises(ConfigurationError) as profile_error:
        load_settings(Environment.DEV, tmp_path)
    assert "do-not-disclose" not in str(profile_error.value)

    with pytest.raises(ConfigurationError, match="unsupported process setting") as process_error:
        load_settings(Environment.DEV, environ={"CCS_UNKNOWN": "do-not-disclose"})
    assert "do-not-disclose" not in str(process_error.value)


def test_loader_and_bootstrap_do_not_create_runtime_paths(tmp_path: Path) -> None:
    (tmp_path / "pyproject.toml").write_text(
        '[project]\nname = "custom-content-studio"\n', encoding="utf-8"
    )
    (tmp_path / "src" / "custom_content_studio").mkdir(parents=True)
    (tmp_path / "src" / "custom_content_studio" / "__init__.py").write_text("", encoding="utf-8")
    _write_profile(tmp_path, Environment.DEV)
    runtime_root = tmp_path / ".runtime" / "DEV"

    assert not runtime_root.exists()
    assert load_settings(Environment.DEV, tmp_path).runtime_root == runtime_root
    assert bootstrap(Environment.DEV, tmp_path).runtime_root == runtime_root
    assert not runtime_root.exists()


def test_cli_reports_explicit_and_process_selectors(
    monkeypatch: MonkeyPatch, capsys: CaptureFixture[str]
) -> None:
    monkeypatch.setenv("CCS_ENV", "STAGING")

    assert cli_main(["health"]) == 0
    assert json.loads(capsys.readouterr().out)["environment"] == "STAGING"

    assert cli_main(["--environment", "PROD", "health"]) == 0
    assert json.loads(capsys.readouterr().out)["environment"] == "PROD"
