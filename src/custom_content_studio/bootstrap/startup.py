from ..config import Settings
from .composition import bootstrap


def main() -> Settings:
    """Validate the shared composition root without external side effects."""
    return bootstrap()
