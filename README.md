# Custom Content Studio

This repository currently contains the approved execution-environment scaffold only. Product source, entrypoints, database schema, migrations, and provider integrations have not been implemented.

## Supported host toolchain

- CPython 3.12.x, using the repository-local `.venv`
- FFmpeg and FFprobe with absolute paths recorded in `reports/ENV-02_03_04_EXECUTION_REPORT.md`
- Public PyPI dependencies resolved into the single exact, hash-checked `requirements.lock`

Do not use another project's virtual environment or media binaries. Do not use bare `python`, `pip`, `ffmpeg`, or `ffprobe` in governed execution packets; bind their resolved executable paths and hashes.

## Reproducible environment

PowerShell commands are run from `E:\Custom_Contents_APP`:

```powershell
C:\Users\knthr\AppData\Local\Programs\Python\Python312\python.exe -m venv .venv
Remove-Item Env:PIP_NO_INDEX -ErrorAction SilentlyContinue
$env:PIP_CONFIG_FILE = "NUL"
.\.venv\Scripts\python.exe -m pip install --require-hashes -r requirements.lock
.\.venv\Scripts\python.exe -m pip check
```

The committed lock is the only installation input. To intentionally refresh it, use the pinned `pip-tools` version already recorded in the current lock, review the full diff, then run:

```powershell
Remove-Item Env:PIP_NO_INDEX -ErrorAction SilentlyContinue
$env:PIP_CONFIG_FILE = "NUL"
.\.venv\Scripts\pip-compile.exe --no-config --all-build-deps --all-extras --allow-unsafe --generate-hashes --strip-extras --resolver=backtracking --index-url https://pypi.org/simple --output-file requirements.lock pyproject.toml
```

Lock refresh is a governed dependency change; never regenerate it implicitly during app startup or CI.

## Profiles and secrets

Runtime data belongs under `.runtime\DEV`, `.runtime\TEST`, or `.runtime\STAGING`; the whole directory is ignored by Git. TEST must use fake providers when product code is added. `.env.example` contains non-secret placeholders only. A real `.env` is ignored and must never be committed; provider credentials must eventually be represented by secret-store locators rather than raw values in tracked files or reports.

No server or provider command is currently available. See `reports/ENV-02_03_04_EXECUTION_REPORT.md` for the exact readiness status and `NOT RUN` checks.
