from .config import Environment, Settings, load_settings


def bootstrap(environment: Environment = Environment.DEV) -> Settings:
    return load_settings(environment)
