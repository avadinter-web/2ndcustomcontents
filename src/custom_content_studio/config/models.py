from enum import StrEnum
from ipaddress import ip_address
from pathlib import Path
from typing import Literal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Environment(StrEnum):
    DEV = "DEV"
    STAGING = "STAGING"
    PROD = "PROD"


class LogFormat(StrEnum):
    CONSOLE = "console"
    JSON = "json"


class LogLevel(StrEnum):
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class Settings(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, hide_input_in_errors=True)

    environment: Environment
    app_name: Literal["custom_content_studio"] = "custom_content_studio"
    spec_version: Literal["2.2"] = "2.2"
    repository_root: Path
    runtime_root: Path
    log_level: LogLevel = LogLevel.INFO
    log_format: LogFormat = LogFormat.CONSOLE
    debug: bool = Field(default=False, strict=True)
    api_host: str = "127.0.0.1"
    api_port: int = Field(default=8000, ge=1, le=65535, strict=True)
    ui_api_url: str = "http://127.0.0.1:8000"
    kill_publish: bool = Field(default=True, strict=True)
    kill_scheduler: bool = Field(default=True, strict=True)

    @field_validator("api_host")
    @classmethod
    def api_host_is_loopback(cls, value: str) -> str:
        try:
            address = ip_address(value)
        except ValueError as error:
            raise ValueError("api_host must be a loopback IP address") from error
        if not address.is_loopback:
            raise ValueError("api_host must be a loopback IP address")
        return value

    @field_validator("ui_api_url")
    @classmethod
    def ui_api_url_is_local(cls, value: str) -> str:
        parsed = urlsplit(value)
        try:
            address = ip_address(parsed.hostname or "")
            port = parsed.port
        except ValueError as error:
            raise ValueError("ui_api_url must be a local HTTP endpoint") from error
        if (
            parsed.scheme not in {"http", "https"}
            or not address.is_loopback
            or port is None
            or parsed.username is not None
            or parsed.password is not None
            or parsed.query
            or parsed.fragment
        ):
            raise ValueError("ui_api_url must be a local HTTP endpoint")
        return value

    @model_validator(mode="after")
    def profile_is_safe(self) -> "Settings":
        if not self.repository_root.is_absolute() or not self.runtime_root.is_absolute():
            raise ValueError("repository and runtime roots must be absolute")
        if self.repository_root != self.repository_root.resolve(strict=False):
            raise ValueError("repository root must be resolved")
        expected_runtime = (self.repository_root / ".runtime" / self.environment.value).resolve(
            strict=False
        )
        if self.runtime_root != expected_runtime:
            raise ValueError("runtime root must match the repository profile path")
        if self.environment is not Environment.DEV and self.debug:
            raise ValueError("debug must be false outside DEV")
        if self.environment is Environment.PROD and self.log_format is not LogFormat.JSON:
            raise ValueError("PROD log_format must be json")
        if not self.kill_publish or not self.kill_scheduler:
            raise ValueError("publish and scheduler kill switches must remain enabled")
        return self
