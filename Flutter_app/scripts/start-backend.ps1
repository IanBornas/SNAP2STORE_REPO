<#
start-backend.ps1

Ensure backend venv exists, install requirements if present, then start backend as a background process.
This script returns immediately after requesting the background start so it can be used as a preLaunchTask.
#>

try {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = (Resolve-Path "$scriptRoot\.." ).Path
    $backendPath = Join-Path $repoRoot 'backend'

    if (-not (Test-Path $backendPath)) {
        Write-Error "Backend folder not found at $backendPath"
        exit 1
    }

    $venvPath = Join-Path $backendPath '.venv'
    if (-not (Test-Path $venvPath)) {
        Write-Host "Creating Python venv at $venvPath..."
        python -m venv $venvPath
    }

    $py = Join-Path $venvPath 'Scripts\python.exe'
    if (-not (Test-Path $py)) {
        Write-Error "Python executable not found in venv: $py"
        exit 1
    }

    $reqFile = Join-Path $backendPath 'requirements.txt'
    if (Test-Path $reqFile) {
        Write-Host "Installing requirements..."
        & $py -m pip install --upgrade pip | Out-Null
        & $py -m pip install -r $reqFile | Out-Null
    }

    # If port 5000 is already open, assume backend is running and skip spawning
    $isOpen = $false
    try { $isOpen = (Test-NetConnection -ComputerName 127.0.0.1 -Port 5000 -WarningAction SilentlyContinue).TcpTestSucceeded } catch {}
    if ($isOpen) {
        Write-Host "Backend already detected on http://127.0.0.1:5000 — skipping start."
    } else {
        Write-Host "Starting backend via venv python..."
        Start-Process -FilePath $py -ArgumentList 'app.py' -WorkingDirectory $backendPath -NoNewWindow
        Write-Host "Backend start requested (background)."
    }

    Write-Host "Waiting for /warmup to become available..."

    # Poll /warmup until ready or timeout
    $maxAttempts = 20
    $attempt = 0
    $url = 'http://127.0.0.1:5000/warmup'
    while ($attempt -lt $maxAttempts) {
        try {
            $resp = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec 2
            if ($resp -and $resp.success -eq $true) {
                Write-Host "Backend warmup OK"
                break
            }
        } catch {
            # ignore and retry
        }
        Start-Sleep -Seconds 1
        $attempt++
    }
    if ($attempt -ge $maxAttempts) {
        Write-Warning "Backend did not respond to $url within the timeout period. Proceeding anyway."
    }
} catch {
    Write-Error "start-backend failed: $_"
    exit 1
}
