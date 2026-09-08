from ..config import Settings
from ..observability import Component
from .composition import bootstrap


def main() -> Settings:
    """Validate startup and emit one bounded local bootstrap diagnostic."""
    return bootstrap(component=Component.BOOTSTRAP)
