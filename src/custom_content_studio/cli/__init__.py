import argparse
import json
import logging
from collections.abc import Sequence

from ..config import Environment, load_settings
from ..observability import (
    Component,
    HealthStatus,
    ObservabilityContext,
    configure_local_logging,
    readiness,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="custom-content-studio")
    parser.add_argument(
        "--environment",
        choices=[environment.value for environment in Environment],
        default=None,
    )
    parser.add_argument("command", choices=["health"])
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    document = readiness(Component.CLI, environment=args.environment)
    if document.status is HealthStatus.READY:
        settings = load_settings(args.environment)
        configure_local_logging(settings).emit(
            logging.INFO,
            "startup.ready",
            "local startup checks passed",
            ObservabilityContext(Component.CLI),
        )
    print(json.dumps(document.as_dict(), sort_keys=True))
    return 0 if document.status is HealthStatus.READY else 1


__all__ = ["build_parser", "main"]
