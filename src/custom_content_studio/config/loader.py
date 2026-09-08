from __future__ import annotations

import os
import tomllib
from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Final

from pydantic import ValidationError

from .models import Environment, Settings

REPOSITORY_ROOT = Path(__file__).resolve().parents[3]

_PROFILE_FILES: Final = {
    Environment.DEV: "dev.toml",
    Environment.STAGING: "staging.toml",
    Environment.PROD: "prod.toml",
}
_PROFILE_KEYS: Final = {
    "environment",
    "app_name",
    "spec_version",
    "log_level",
    "log_format",
    "debug",
    "api_host",
    "api_port",
    "ui_api_url",
    "kill_publish",
    "kill_scheduler",
}
_SECRET_MARKERS: Final = (
    "api_key",
    "bearer",
    "credential",
    "password",
    "private_key",
    "secret",
    "token",
)
_SAFE_DEFAULTS: Final[dict[str, object]] = {
    "app_name": "custom_content_studio",
    "spec_version": "2.2",
    "log_level": "INFO",
    "log_format": "console",
    "debug": False,
    "api_host": "127.0.0.1",
    "api_port": 8000,
    "ui_api_url": "http://127.0.0.1:8000",
    "kill_publish": True,
    "kill_scheduler": True,
}


class ConfigurationError(ValueError):
    """Raised when an environment profile fails closed."""


def _parse_bool(value: str) -> bool:
    if value == "true":
        return True
    if value == "false":
        return False
    raise ConfigurationError("boolean settings must be exactly true or false")


def _parse_port(value: str) -> int:
    if not value.isascii() or not value.isdecimal():
        raise ConfigurationError("port settings must be decimal integers")
    return int(value)


def _identity(value: str) -> str:
    return value


_PROCESS_OVERRIDES: Final[dict[str, tuple[str, Callable[[str], object]]]] = {
    "CCS_LOG_LEVEL": ("log_level", _identity),
    "CCS_LOG_FORMAT": ("log_format", _identity),
    "CCS_DEBUG": ("debug", _parse_bool),
    "CCS_API_HOST": ("api_host", _identity),
    "CCS_API_PORT": ("api_port", _parse_port),
    "CCS_UI_API_URL": ("ui_api_url", _identity),
    "CCS_KILL_PUBLISH": ("kill_publish", _parse_bool),
    "CCS_KILL_SCHEDULER": ("kill_scheduler", _parse_bool),
}
_PROCESS_KEYS: Final = frozenset({"CCS_ENV", *_PROCESS_OVERRIDES})


def _select_environment(
    explicit_environment: Environment | str | None, environ: Mapping[str, str]
) -> Environment:
    raw_environment = (
        explicit_environment if explicit_environment is not None else environ.get("CCS_ENV")
    )
    if isinstance(raw_environment, Environment):
        return raw_environment
    if raw_environment is None:
        raise ConfigurationError("environment must be selected by --environment or CCS_ENV")
    try:
        return Environment(raw_environment)
    except ValueError as error:
        raise ConfigurationError("environment must be exactly one of DEV, STAGING, PROD") from error


def _contains_secret_material(value: object) -> bool:
    if isinstance(value, Mapping):
        for key, nested_value in value.items():
            normalized_key = str(key).casefold().replace("-", "_")
            if any(marker in normalized_key for marker in _SECRET_MARKERS):
                return True
            if _contains_secret_material(nested_value):
                return True
    elif isinstance(value, list):
        return any(_contains_secret_material(item) for item in value)
    elif isinstance(value, str):
        normalized_value = value.casefold()
        return normalized_value.startswith("bearer ") or (
            "-----begin private key-----" in normalized_value
        )
    return False


def _load_profile(root: Path, environment: Environment) -> dict[str, object]:
    profile_path = root / "config" / _PROFILE_FILES[environment]
    try:
        with profile_path.open("rb") as stream:
            profile = tomllib.load(stream)
    except FileNotFoundError as error:
        raise ConfigurationError(
            f"{environment.value} profile file is required at config/{_PROFILE_FILES[environment]}"
        ) from error
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise ConfigurationError(
            f"{environment.value} profile file must be readable valid TOML"
        ) from error

    if _contains_secret_material(profile):
        raise ConfigurationError("profile contains forbidden secret-like material")
    unknown_keys = set(profile) - _PROFILE_KEYS
    if unknown_keys:
        unknown_key = sorted(unknown_keys)[0]
        raise ConfigurationError(f"unsupported profile setting: {unknown_key}")
    if "environment" not in profile:
        raise ConfigurationError("profile setting environment is required")
    if profile["environment"] != environment.value:
        raise ConfigurationError("profile setting environment must match the selector")
    return profile


def _process_overrides(environ: Mapping[str, str]) -> dict[str, object]:
    unknown_keys = sorted(
        key for key in environ if key.startswith("CCS_") and key not in _PROCESS_KEYS
    )
    if unknown_keys:
        raise ConfigurationError(f"unsupported process setting: {unknown_keys[0]}")

    overrides: dict[str, object] = {}
    for process_key, (setting_key, parser) in _PROCESS_OVERRIDES.items():
        if process_key not in environ:
            continue
        try:
            overrides[setting_key] = parser(environ[process_key])
        except ConfigurationError as error:
            raise ConfigurationError(f"invalid process setting: {process_key}") from error
    return overrides


def load_settings(
    environment: Environment | str | None = None,
    repository_root: Path | None = None,
    *,
    environ: Mapping[str, str] | None = None,
) -> Settings:
    process_environment = os.environ if environ is None else environ
    selected_environment = _select_environment(environment, process_environment)
    root = (repository_root or REPOSITORY_ROOT).resolve()
    profile = _load_profile(root, selected_environment)
    settings_data = {
        **_SAFE_DEFAULTS,
        **profile,
        **_process_overrides(process_environment),
        "environment": selected_environment,
        "repository_root": root,
        "runtime_root": (root / ".runtime" / selected_environment.value).resolve(),
    }
    try:
        return Settings.model_validate(settings_data)
    except ValidationError as error:
        detail = error.errors(include_context=False, include_input=False)[0]["msg"]
        raise ConfigurationError(f"profile settings failed validation: {detail}") from error
