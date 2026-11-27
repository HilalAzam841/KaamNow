<#
Runs KaamNow on a Windows laptop. Works in Windows PowerShell 5 and PowerShell 7.

From the KaamNow folder:
  powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 setup    # first time: venv, packages, tables, demo accounts
  powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 update   # after every git pull
  powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 server   # start the API on http://localhost:8000
  powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 web      # open the app in Chrome (second window)
  powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 test     # run the server and app tests

Create the database and the .env file first (see the "Run KaamNow on your laptop" guide).
#>
param([Parameter(Position = 0)][ValidateSet('setup', 'update', 'server', 'web', 'test')][string]$Command = 'server')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# autobahn (used by the WebSocket server) fails to build its optional C speed-up on Windows without this.
$env:AUTOBAHN_USE_NVX = '0'
# Keeps the Dart compiler and Gradle from using all the laptop's memory.
$env:GRADLE_OPTS = '-Xmx2g'

function Run([string]$exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "$exe $($arguments -join ' ') failed (exit code $LASTEXITCODE)" }
}

$python = Join-Path $root '.venv\Scripts\python.exe'

function Ensure-Venv {
    if (-not (Test-Path $python)) {
        Write-Host 'Creating the Python environment (.venv)...'
        Run 'python' @('-m', 'venv', '.venv')
    }
    if (-not (Test-Path (Join-Path $root '.env'))) {
        throw 'No .env file in the KaamNow folder. Create it as the guide shows, then run this again.'
    }
}

function Install-Packages {
    Run $python @('-m', 'pip', 'install', '--upgrade', 'pip')
    Run $python @('-m', 'pip', 'install', '-r', 'requirements-dev.txt')
}

function App-Packages {
    Push-Location (Join-Path $root 'app')
    try { Run 'flutter' @('pub', 'get') } finally { Pop-Location }
}

switch ($Command) {
    'setup' {
        Ensure-Venv
        Install-Packages
        Run $python @('manage.py', 'migrate')
        Run $python @('manage.py', 'seed_demo_data')
        App-Packages
        Write-Host "`nDone. Start the server with: powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 server"
    }
    'update' {
        Ensure-Venv
        Install-Packages
        Run $python @('manage.py', 'migrate')
        App-Packages
        Write-Host "`nUp to date. Start the server again."
    }
    'server' {
        Ensure-Venv
        Run (Join-Path $root '.venv\Scripts\daphne.exe') @('-b', '0.0.0.0', '-p', '8000', 'config.asgi:application')
    }
    'web' {
        Push-Location (Join-Path $root 'app')
        try { Run 'flutter' @('run', '-d', 'chrome', '--dart-define=API_BASE_URL=http://localhost:8000') }
        finally { Pop-Location }
    }
    'test' {
        Ensure-Venv
        Run $python @('-m', 'pytest', '-q')
        Push-Location (Join-Path $root 'app')
        try { Run 'flutter' @('test', '--concurrency=2') } finally { Pop-Location }
    }
}
