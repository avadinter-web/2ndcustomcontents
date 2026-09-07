from .bootstrap import bootstrap
from .config import Settings


def main() -> Settings:
    """Validate the scheduler composition root without scheduling jobs."""
    return bootstrap()


if __name__ == "__main__":
    main()
