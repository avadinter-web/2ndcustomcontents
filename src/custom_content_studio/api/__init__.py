from fastapi import FastAPI

from ..bootstrap import bootstrap
from ..config import Settings

app = FastAPI(title="Custom Content Studio")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


def main() -> Settings:
    """Validate the API composition root without starting a server."""
    return bootstrap()


__all__ = ["app", "health", "main"]
