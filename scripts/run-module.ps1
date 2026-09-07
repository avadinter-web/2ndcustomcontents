param(
    [string]$Module
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Module) -or $Module -notmatch '^[A-Za-z_][A-Za-z0-9_.]*$') {
    throw "A valid Python module name is required."
}

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot "src")).Path
$pythonPath = Join-Path $repositoryRoot ".venv\Scripts\python.exe"

if (-not [string]::IsNullOrWhiteSpace($env:CUSTOM_CONTENT_STUDIO_PYTHON)) {
    $pythonPath = $env:CUSTOM_CONTENT_STUDIO_PYTHON
}

if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw "Python executable not found: $pythonPath. Create the locked repository .venv first."
}

$previousPythonPath = $env:PYTHONPATH
$pathSeparator = [IO.Path]::PathSeparator
$env:PYTHONPATH = if ([string]::IsNullOrWhiteSpace($previousPythonPath)) {
    $sourceRoot
} else {
    "$sourceRoot$pathSeparator$previousPythonPath"
}

$exitCode = 1
Push-Location -LiteralPath $repositoryRoot
try {
    & $pythonPath -m $Module @args
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
    if ($null -eq $previousPythonPath) {
        Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
    } else {
        $env:PYTHONPATH = $previousPythonPath
    }
}

exit $exitCode
