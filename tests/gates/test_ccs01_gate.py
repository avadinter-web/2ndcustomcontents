from __future__ import annotations

import ast
import hashlib
import io
import logging
import sys
from datetime import UTC, datetime, timedelta
from importlib.abc import MetaPathFinder
from ipaddress import ip_address
from pathlib import Path
from urllib.parse import urlsplit

from pytest import MonkeyPatch

from custom_content_studio.api import main as api_main
from custom_content_studio.application.services import SessionService
from custom_content_studio.bootstrap import bootstrap
from custom_content_studio.cli import main as cli_main
from custom_content_studio.config import Environment, load_settings
from custom_content_studio.infrastructure.sqlite.repositories import SQLiteSessionRepository
from custom_content_studio.observability import (
    LOGGER_NAME,
    Component,
    configure_local_logging,
    readiness_from_settings,
)
from custom_content_studio.persistence import (
    MigrationRunner,
    SQLiteConnectionFactory,
    SQLiteUnitOfWork,
)
from custom_content_studio.scheduler import main as scheduler_main
from custom_content_studio.ui import main as ui_main
from custom_content_studio.workers import main as worker_main

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS_ROOT = REPOSITORY_ROOT / "migrations"
RUNTIME_ROOT = REPOSITORY_ROOT / ".runtime"
EXPECTED_IDENTITIES = {
    REPOSITORY_ROOT
    / ".venv"
    / "Scripts"
    / "python.exe": "0b471133e110cfb53a061cad528ce8e517d7b9ac41a0a396c39ad795a487fc14",
    REPOSITORY_ROOT
    / "requirements.lock": "421cb8cba331c116faa51e6fb5b86f8c299970968bd5f2f43b6544bd5f73d851",
    Path(
        "C:/Users/knthr/AppData/Local/Microsoft/WinGet/Packages/"
        "Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe/"
        "ffmpeg-8.1.1-essentials_build/bin/ffmpeg.exe"
    ): "228d7a8556258de907fdb55f36850078ebc7680b84ec30d84ea02e99bec1d1eb",
    Path(
        "C:/Users/knthr/AppData/Local/Microsoft/WinGet/Packages/"
        "Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe/"
        "ffmpeg-8.1.1-essentials_build/bin/ffprobe.exe"
    ): "0fde260f5abd35c9cafd96f594cc76365a780c1b73a90e35b6a3409ea1db1bf0",
}
PROVIDER_ROOTS = frozenset({"google", "higgsfield", "openai", "replicate", "runwayml"})


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _tree_fingerprint(root: Path) -> dict[str, str]:
    if not root.exists():
        return {}
    return {
        path.relative_to(root).as_posix(): _sha256(path)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


class _DenyProviderImports(MetaPathFinder):
    def find_spec(
        self,
        fullname: str,
        path: object = None,
        target: object = None,
    ) -> None:
        del path, target
        if fullname.partition(".")[0] in PROVIDER_ROOTS:
            raise AssertionError(f"provider import attempted: {fullname}")
        return None


def test_toolchain_identity_matches_recorded_local_contract() -> None:
    for path, expected in EXPECTED_IDENTITIES.items():
        assert path.is_file(), f"required local identity is missing: {path}"
        assert _sha256(path) == expected
    expected_python = (REPOSITORY_ROOT / ".venv/Scripts/python.exe").resolve()
    assert Path(sys.executable).resolve() == expected_python


def test_optional_provider_absence_does_not_break_foundation_boot(
    monkeypatch: MonkeyPatch,
) -> None:
    before = _tree_fingerprint(RUNTIME_ROOT)
    monkeypatch.setattr(sys, "meta_path", [_DenyProviderImports(), *sys.meta_path])
    for name in tuple(sys.modules):
        if name.partition(".")[0] in PROVIDER_ROOTS:
            monkeypatch.delitem(sys.modules, name, raising=False)
    settings = bootstrap(Environment.DEV, REPOSITORY_ROOT)
    assert settings.kill_publish is True
    assert settings.kill_scheduler is True
    assert _tree_fingerprint(RUNTIME_ROOT) == before


def test_loopback_bindings_and_ui_import_boundary() -> None:
    for environment in Environment:
        settings = load_settings(environment, REPOSITORY_ROOT)
        assert ip_address(settings.api_host).is_loopback
        assert ip_address(urlsplit(settings.ui_api_url).hostname or "").is_loopback

    forbidden = {"fastapi", "uvicorn", "custom_content_studio.api"}
    for source_path in (REPOSITORY_ROOT / "src/custom_content_studio/ui").rglob("*.py"):
        tree = ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
        imports = {
            alias.name
            for node in ast.walk(tree)
            if isinstance(node, ast.Import)
            for alias in node.names
        }
        imports.update(
            node.module or "" for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)
        )
        assert not any(
            imported == denied or imported.startswith(f"{denied}.")
            for imported in imports
            for denied in forbidden
        )


def test_process_shells_start_stop_twice_without_provider_or_runtime_writes(
    monkeypatch: MonkeyPatch,
) -> None:
    before = _tree_fingerprint(RUNTIME_ROOT)
    monkeypatch.setenv("CCS_ENV", "DEV")
    for _ in range(2):
        assert api_main().environment is Environment.DEV
        assert ui_main().environment is Environment.DEV
        assert worker_main().environment is Environment.DEV
        assert scheduler_main().environment is Environment.DEV
        assert cli_main(["--environment", "DEV", "health"]) == 0
    assert _tree_fingerprint(RUNTIME_ROOT) == before


def test_dev_test_staging_roots_are_disjoint_and_test_effects_stay_in_test_root(
    tmp_path: Path,
) -> None:
    before = _tree_fingerprint(RUNTIME_ROOT)
    governed = tuple((RUNTIME_ROOT / name).resolve() for name in ("DEV", "TEST", "STAGING"))
    assert len(set(governed)) == 3
    assert all(path.parent == RUNTIME_ROOT.resolve() for path in governed)

    test_effect = tmp_path / "TEST" / "gate-observation.txt"
    test_effect.parent.mkdir()
    test_effect.write_text("synthetic gate observation", encoding="utf-8")
    assert test_effect.is_relative_to(tmp_path)
    assert _tree_fingerprint(RUNTIME_ROOT) == before


def test_security_outputs_database_logs_and_health_contain_no_raw_secret(
    tmp_path: Path,
) -> None:
    factory = SQLiteConnectionFactory((tmp_path / "gate.sqlite3").resolve())
    MigrationRunner(factory, MIGRATIONS_ROOT).migrate_fresh()
    with SQLiteUnitOfWork(factory) as uow:
        uow.connection.execute(
            "INSERT INTO users(id,email,email_normalized,status,created_at,updated_at) "
            "VALUES ('gate-user','gate@example.test','gate@example.test','ACTIVE',?,?)",
            ("2026-09-08T00:00:00Z", "2026-09-08T00:00:00Z"),
        )
        uow.commit()

    service = SessionService(factory, SQLiteSessionRepository())
    now = datetime(2026, 9, 8, tzinfo=UTC)
    issued = service.issue("gate-user", now, now + timedelta(minutes=5))
    raw_secret = issued.raw_token_once
    assert raw_secret.encode() not in factory.database_path.read_bytes()

    stream = io.StringIO()
    settings = load_settings(Environment.DEV, REPOSITORY_ROOT)
    configure_local_logging(settings, stream=stream)
    logging.getLogger(LOGGER_NAME).error("Authorization: Bearer %s", raw_secret)
    health = readiness_from_settings(settings, Component.API).as_dict()
    combined = stream.getvalue() + repr(health)
    assert raw_secret not in combined
    assert factory.database_path.parent == tmp_path.resolve()
