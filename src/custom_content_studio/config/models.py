from enum import StrEnum
from pathlib import Path

from pydantic import BaseModel, ConfigDict, model_validator


class Environment(StrEnum):
    DEV = "DEV"
    STAGING = "STAGING"
    PROD = "PROD"


class Settings(BaseModel):
    model_config = ConfigDict(frozen=True)

    environment: Environment
    repository_root: Path
    runtime_root: Path

    @model_validator(mode="after")
    def runtime_is_repository_contained(self) -> "Settings":
        expected_runtime = self.repository_root / ".runtime" / self.environment.value
        if self.runtime_root != expected_runtime:
            raise ValueError("runtime root must match the repository profile path")
        return self
