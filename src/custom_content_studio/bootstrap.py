from .config import Environment, Settings, load_settings


def bootstrap(environment: Environment = Environment.DEV) -> Settings:
    return load_settings(environment)


def main() -> Settings:
    """Validate the shared composition root without external side effects."""
    return bootstrap()


if __name__ == "__main__":
    main()
