from .bootstrap import bootstrap
from .config import Settings


def main() -> Settings:
    """Validate the worker composition root without dispatching work."""
    return bootstrap()


if __name__ == "__main__":
    main()
