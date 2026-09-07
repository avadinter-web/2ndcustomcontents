from enum import StrEnum
from pathlib import Path

from pydantic import BaseModel, ConfigDict, model_validator

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


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


def load_settings(
    environment: Environment = Environment.DEV, repository_root: Path | None = None
) -> Settings:
    root = (repository_root or REPOSITORY_ROOT).resolve()
    runtime = (root / ".runtime" / environment.value).resolve()
    return Settings(environment=environment, repository_root=root, runtime_root=runtime)
