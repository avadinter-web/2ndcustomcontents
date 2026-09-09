from ..bootstrap import bootstrap
from ..config import Settings
from ..observability import Component
from .route_shell import (
    BOUNDED_LAYOUT_POLICY,
    STANDALONE_ROUTES,
    BoundedLayoutPolicy,
    StandaloneRoute,
)


def main() -> Settings:
    """Validate the UI composition root without rendering product pages."""
    return bootstrap(component=Component.UI)


__all__ = [
    "BOUNDED_LAYOUT_POLICY",
    "STANDALONE_ROUTES",
    "BoundedLayoutPolicy",
    "StandaloneRoute",
    "main",
]
