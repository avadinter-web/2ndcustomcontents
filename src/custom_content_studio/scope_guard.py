from __future__ import annotations

import argparse
import ast
import json
import sys
import tomllib
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Final

_EXPECTED_PROJECT_NAME: Final = "custom-content-studio"
_EXPECTED_PACKAGE_PATH: Final = Path("src/custom_content_studio")
_LEGACY_MODULE: Final = "friends" + "_shadowing_ai_starter"


class ScopeGuardError(RuntimeError):
    """Raised when the application runtime is not isolated inside its repository."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(f"{code}: {message}")
        self.code = code


@dataclass(frozen=True)
class ScopeValidation:
    repository_root: Path
    runtime_roots: tuple[Path, ...]
    scanned_python_files: int


def _is_legacy_module(module_name: str) -> bool:
    normalized = module_name.casefold()
    legacy = _LEGACY_MODULE.casefold()
    return normalized == legacy or normalized.startswith(f"{legacy}.")


def _validate_repository_root(repository_root: Path) -> Path:
    if not repository_root.is_absolute():
        raise ScopeGuardError("REPOSITORY_ROOT_NOT_ABSOLUTE", "repository root must be absolute")

    root = repository_root.resolve(strict=True)
    if not root.is_dir():
        raise ScopeGuardError("REPOSITORY_ROOT_INVALID", "repository root must be a directory")
    if any(_LEGACY_MODULE.casefold() in part.casefold() for part in root.parts):
        raise ScopeGuardError("LEGACY_ROOT_FORBIDDEN", "legacy repository path is forbidden")

    project_file = root / "pyproject.toml"
    package_root = root / _EXPECTED_PACKAGE_PATH
    if not project_file.is_file() or not package_root.is_dir():
        raise ScopeGuardError(
            "REPOSITORY_IDENTITY_INVALID",
            "repository must contain pyproject.toml and src/custom_content_studio",
        )

    try:
        with project_file.open("rb") as stream:
            project_name = tomllib.load(stream).get("project", {}).get("name")
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise ScopeGuardError(
            "REPOSITORY_IDENTITY_INVALID", "pyproject.toml is unreadable"
        ) from error
    if project_name != _EXPECTED_PROJECT_NAME:
        raise ScopeGuardError(
            "REPOSITORY_IDENTITY_INVALID",
            f"project.name must be {_EXPECTED_PROJECT_NAME}",
        )
    return root


def _validate_runtime_roots(
    repository_root: Path, runtime_roots: Iterable[Path]
) -> tuple[Path, ...]:
    resolved_roots: list[Path] = []
    for runtime_root in runtime_roots:
        if not runtime_root.is_absolute():
            raise ScopeGuardError("RUNTIME_ROOT_NOT_ABSOLUTE", "runtime roots must be absolute")
        resolved = runtime_root.resolve(strict=False)
        try:
            relative = resolved.relative_to(repository_root)
        except ValueError as error:
            raise ScopeGuardError(
                "RUNTIME_ROOT_OUTSIDE_REPOSITORY",
                "mutable runtime root must remain inside the repository",
            ) from error
        if relative == Path("."):
            raise ScopeGuardError(
                "RUNTIME_ROOT_IS_REPOSITORY",
                "the repository root itself cannot be used as a mutable runtime root",
            )
        resolved_roots.append(resolved)

    if not resolved_roots:
        raise ScopeGuardError(
            "RUNTIME_ROOT_MISSING", "at least one mutable runtime root is required"
        )
    return tuple(resolved_roots)


def _scan_source_imports(repository_root: Path) -> int:
    package_root = repository_root / _EXPECTED_PACKAGE_PATH
    python_files = sorted(package_root.rglob("*.py"))
    for source_path in python_files:
        try:
            tree = ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
        except (OSError, UnicodeError, SyntaxError) as error:
            raise ScopeGuardError(
                "SOURCE_SCAN_FAILED", "application source could not be inspected"
            ) from error

        for node in ast.walk(tree):
            module_names: tuple[str, ...] = ()
            if isinstance(node, ast.Import):
                module_names = tuple(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module is not None:
                module_names = (node.module,)
            if any(_is_legacy_module(name) for name in module_names):
                raise ScopeGuardError(
                    "LEGACY_IMPORT_FORBIDDEN",
                    f"legacy import found in {source_path.relative_to(repository_root).as_posix()}",
                )
    return len(python_files)


def validate_runtime_scope(
    repository_root: Path,
    runtime_roots: Iterable[Path],
    *,
    imported_module_names: Iterable[str] | None = None,
) -> ScopeValidation:
    """Validate repository identity and local mutable-state isolation without side effects."""

    root = _validate_repository_root(repository_root)
    resolved_runtime_roots = _validate_runtime_roots(root, runtime_roots)
    active_modules = sys.modules if imported_module_names is None else imported_module_names
    if any(_is_legacy_module(name) for name in active_modules):
        raise ScopeGuardError("LEGACY_IMPORT_ACTIVE", "legacy runtime module is already imported")
    scanned_files = _scan_source_imports(root)
    return ScopeValidation(root, resolved_runtime_roots, scanned_files)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="custom-content-studio-scope-guard")
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--runtime-root", required=True, action="append", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = validate_runtime_scope(args.repository_root, args.runtime_root)
    payload = asdict(result)
    payload["repository_root"] = str(result.repository_root)
    payload["runtime_roots"] = [str(path) for path in result.runtime_roots]
    payload["status"] = "ok"
    print(json.dumps(payload, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
