from enum import StrEnum
from pathlib import Path

from pydantic import BaseModel, field_validator


class Environment(StrEnum):
    DEV = "DEV"
    STAGING = "STAGING"
    PROD = "PROD"


class Settings(BaseModel):
    environment: Environment
    repository_root: Path
    runtime_root: Path

    @field_validator("runtime_root")
    @classmethod
    def runtime_is_contained(cls, value: Path) -> Path:
        if value.name not in {item.value for item in Environment}:
            raise ValueError("runtime root must end with the selected environment")
        return value


def load_settings(environment: Environment = Environment.DEV, repository_root: Path | None = None) -> Settings:
    root = (repository_root or Path.cwd()).resolve()
    runtime = (root / ".runtime" / environment.value).resolve()
    if root not in runtime.parents:
        raise ValueError("runtime root escapes repository")
    return Settings(environment=environment, repository_root=root, runtime_root=runtime)
