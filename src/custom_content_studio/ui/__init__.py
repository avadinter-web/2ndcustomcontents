from ..bootstrap import bootstrap
from ..config import Settings


def main() -> Settings:
    """Validate the UI composition root without rendering product pages."""
    return bootstrap()


__all__ = ["main"]
