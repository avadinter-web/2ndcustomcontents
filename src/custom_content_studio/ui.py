from .bootstrap import bootstrap
from .config import Settings


def main() -> Settings:
    """Validate the UI composition root without rendering product pages."""
    return bootstrap()


if __name__ == "__main__":
    main()
