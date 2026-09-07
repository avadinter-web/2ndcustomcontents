from pathlib import Path

import pytest
from pytest import CaptureFixture, MonkeyPatch

from custom_content_studio.bootstrap import bootstrap
from custom_content_studio.config import Environment
from custom_content_studio.scope_guard import ScopeGuardError, main, validate_runtime_scope


def _valid_repository(root: Path) -> Path:
    package_root = root / "src" / "custom_content_studio"
    package_root.mkdir(parents=True)
    (root / "pyproject.toml").write_text(
        '[project]\nname = "custom-content-studio"\n',
        encoding="utf-8",
    )
    (package_root / "__init__.py").write_text("", encoding="utf-8")
    return root


def test_valid_repository_scope_and_startup(tmp_path: Path) -> None:
    repository_root = _valid_repository(tmp_path / "repository").resolve()
    runtime_root = repository_root / ".runtime" / "DEV"

    result = validate_runtime_scope(repository_root, (runtime_root,), imported_module_names=())
    settings = bootstrap(Environment.DEV, repository_root)

    assert result.repository_root == repository_root
    assert result.runtime_roots == (runtime_root,)
    assert result.scanned_python_files == 1
    assert settings.runtime_root == runtime_root


def test_legacy_source_import_is_rejected(tmp_path: Path) -> None:
    repository_root = _valid_repository(tmp_path / "repository").resolve()
    source_file = repository_root / "src" / "custom_content_studio" / "legacy_reference.py"
    source_file.write_text("import friends_shadowing_ai_starter\n", encoding="utf-8")

    with pytest.raises(ScopeGuardError, match="LEGACY_IMPORT_FORBIDDEN"):
        validate_runtime_scope(
            repository_root,
            (repository_root / ".runtime" / "DEV",),
            imported_module_names=(),
        )


def test_loaded_legacy_module_reference_is_rejected(tmp_path: Path) -> None:
    repository_root = _valid_repository(tmp_path / "repository").resolve()

    with pytest.raises(ScopeGuardError, match="LEGACY_IMPORT_ACTIVE"):
        validate_runtime_scope(
            repository_root,
            (repository_root / ".runtime" / "DEV",),
            imported_module_names=("friends_shadowing_ai_starter.runtime",),
        )


def test_runtime_root_outside_repository_is_rejected(tmp_path: Path) -> None:
    repository_root = _valid_repository(tmp_path / "repository").resolve()

    with pytest.raises(ScopeGuardError, match="RUNTIME_ROOT_OUTSIDE_REPOSITORY"):
        validate_runtime_scope(
            repository_root,
            ((tmp_path / "external-runtime").resolve(),),
            imported_module_names=(),
        )


def test_relative_repository_root_is_rejected(tmp_path: Path, monkeypatch: MonkeyPatch) -> None:
    _valid_repository(tmp_path / "repository")
    monkeypatch.chdir(tmp_path)

    with pytest.raises(ScopeGuardError, match="REPOSITORY_ROOT_NOT_ABSOLUTE"):
        validate_runtime_scope(
            Path("repository"),
            (Path("repository/.runtime/DEV"),),
            imported_module_names=(),
        )


def test_module_cli_validation(tmp_path: Path, capsys: CaptureFixture[str]) -> None:
    repository_root = _valid_repository(tmp_path / "repository").resolve()
    runtime_root = repository_root / ".runtime" / "DEV"

    assert (
        main(
            [
                "--repository-root",
                str(repository_root),
                "--runtime-root",
                str(runtime_root),
            ]
        )
        == 0
    )
    assert '"status": "ok"' in capsys.readouterr().out
