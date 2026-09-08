from ..bootstrap import bootstrap
from ..config import Settings
from ..observability import Component


def main() -> Settings:
    """Validate the scheduler composition root without scheduling jobs."""
    return bootstrap(component=Component.SCHEDULER)
