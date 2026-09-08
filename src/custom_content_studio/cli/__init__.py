import argparse
import json
from collections.abc import Sequence

from ..bootstrap import bootstrap
from ..config import Environment


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
    settings = bootstrap(args.environment)
    if args.command == "health":
        print(
            json.dumps(
                {
                    "environment": settings.environment.value,
                    "runtime_root": str(settings.runtime_root),
                    "status": "ok",
                },
                sort_keys=True,
            )
        )
    return 0


__all__ = ["build_parser", "main"]
