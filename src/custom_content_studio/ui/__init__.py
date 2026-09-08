from ..bootstrap import bootstrap
from ..config import Settings
from ..observability import Component


def main() -> Settings:
    """Validate the UI composition root without rendering product pages."""
    return bootstrap(component=Component.UI)


__all__ = ["main"]
