from ..bootstrap import bootstrap
from ..config import Settings
from ..observability import Component


def main() -> Settings:
    """Validate the worker composition root without dispatching work."""
    return bootstrap(component=Component.WORKER)
