<#
Start-Dev.ps1

Creates or reuses a Python venv for the backend, installs requirements if needed,
starts the backend (background), then runs the Flutter app in the current terminal.

Usage:
  # Run with default flutter target
  powershell -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1

  # Pass Flutter args (for example to choose device)
  powershell -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1 -FlutterArgs '-d edge'

Notes:
 - This script assumes `python` and `flutter` are on PATH.
 - It starts the backend with the venv python at `backend\.venv\Scripts\python.exe`.
#>

param(
    [string]$FlutterArgs = ''
)

try {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    # repo root is parent of 'scripts' folder
    $repoRoot = (Resolve-Path "$scriptRoot\..").Path
    $backendPath = Join-Path $repoRoot 'backend'

    if (-not (Test-Path $backendPath)) {
        Write-Error "Backend folder not found at $backendPath"
        exit 1
    }

    Write-Host "Using backend folder: $backendPath"

    $venvPath = Join-Path $backendPath '.venv'
    if (-not (Test-Path $venvPath)) {
        Write-Host "Creating Python venv at $venvPath..."
        python -m venv $venvPath
    } else {
        Write-Host "Using existing venv at $venvPath"
    }

    $py = Join-Path $venvPath 'Scripts\python.exe'
    if (-not (Test-Path $py)) {
        Write-Error "Python executable not found in venv: $py"
        exit 1
    }

    Write-Host "Upgrading pip and installing backend requirements..."
    & $py -m pip install --upgrade pip | Out-Null
    $reqFile = Join-Path $backendPath 'requirements.txt'
    if (Test-Path $reqFile) {
        & $py -m pip install -r $reqFile
    } else {
        Write-Host "No requirements.txt found; skipping pip install"
    }

    Write-Host "Starting backend (background process)..."
    Start-Process -FilePath $py -ArgumentList 'app.py' -WorkingDirectory $backendPath -NoNewWindow

    Write-Host "Backend launch requested. Waiting 2s for startup..."
    Start-Sleep -Seconds 2

    # Switch to repo root and run flutter
    Set-Location $repoRoot
    Write-Host "Running 'flutter pub get'..."
    flutter pub get

    Write-Host "Starting Flutter app (this will run in the current terminal)..."
    if ([string]::IsNullOrEmpty($FlutterArgs)) {
        flutter run
    } else {
        flutter run $FlutterArgs
    }

} catch {
    Write-Error "Error in start-dev script: $_"
    exit 1
}
