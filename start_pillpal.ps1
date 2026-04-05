# PillPal dev: PostgreSQL-backed API :8000 + Flutter web :8091 (label photos + Cohere AI when key is set).
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$apiUrl = "http://127.0.0.1:8000/health"
$webPort = 8091

Write-Host "=== PillPal ===" -ForegroundColor Cyan
Write-Host "1. Backend: ensure PostgreSQL is running and DATABASE_URL in backend\.env is correct."
Write-Host "2. Cohere:  set COHERE_API_KEY in backend\.env for AI label summaries (optional)."
Write-Host ""

Write-Host "Checking API at $apiUrl ..."
$apiOk = $false
for ($i = 0; $i -lt 60; $i++) {
  try {
    $r = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -TimeoutSec 2
    if ($r.StatusCode -eq 200) { $apiOk = $true; break }
  } catch { }
  if ($i -eq 0) {
    Write-Host "Starting backend in a new window (venv, pip, alembic, uvicorn)..."
    $apiScript = Join-Path $root "backend\start_api.ps1"
    Start-Process powershell -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", $apiScript)
  }
  Start-Sleep -Seconds 1
}
if (-not $apiOk) {
  Write-Error "Backend did not become ready. Fix backend\.env (DATABASE_URL), ensure Postgres is up, check the backend window for errors."
  exit 1
}
Write-Host "API OK." -ForegroundColor Green

Write-Host "Starting Flutter web on port $webPort..."
$webScript = Join-Path $root "frontend\pillpal_app\start_web.ps1"
Start-Process powershell -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", $webScript)

Write-Host "Waiting for first compile (can take 1-2 min)..."
$ready = $false
for ($j = 0; $j -lt 120; $j++) {
  try {
    $h = Invoke-WebRequest -Uri "http://localhost:$webPort/" -UseBasicParsing -TimeoutSec 3
    if ($h.StatusCode -eq 200) { $ready = $true; break }
  } catch { }
  Start-Sleep -Seconds 1
}

$openUrl = "http://localhost:$webPort"
if ($ready) {
  Write-Host "Opening $openUrl" -ForegroundColor Green
} else {
  Write-Host "Web server not ready yet - when the Flutter window shows the URL, open:"
  Write-Host "  $openUrl"
}
Start-Process $openUrl
