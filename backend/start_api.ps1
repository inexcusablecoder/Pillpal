# PillPal API: venv, deps, migrations, then uvicorn :8000
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
  Write-Host "Creating Python virtual environment (.venv)..."
  if (Get-Command py -ErrorAction SilentlyContinue) {
    py -3 -m venv .venv
  } else {
    python -m venv .venv
  }
}
if (-not (Test-Path $py)) {
  Write-Error "Could not create .venv — install Python 3.10+ (https://www.python.org/downloads/)"
  exit 1
}

Write-Host "Installing dependencies (pip)..."
& $py -m pip install -r requirements.txt

Write-Host "Applying database migrations (alembic)..."
& $py -m alembic upgrade head

if (-not (Test-Path ".env")) {
  Write-Host "No .env file — copying from .env.example (edit DATABASE_URL and JWT_SECRET)."
  Copy-Item ".env.example" ".env"
}

$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
  if (-not (Select-String -Path $envFile -Pattern "COHERE_API_KEY" -Quiet)) {
    Add-Content -Path $envFile -Value "`r`n# Cohere: AI label reading — https://dashboard.cohere.com/`r`nCOHERE_API_KEY=`r`n"
    Write-Host "Added COHERE_API_KEY= to .env — paste your key for label summaries."
  }
}

Write-Host ""
Write-Host "Starting API: http://127.0.0.1:8000  |  Docs: http://127.0.0.1:8000/docs"
Write-Host "Label AI: set COHERE_API_KEY in .env, then re-upload a label or use Refresh AI label reading."
Write-Host "Voice reminders: set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_NUMBER in .env; restart after changes."
Write-Host "  Test: GET /api/v1/calls/reminder-status  |  POST /api/v1/calls/test (see OpenAPI docs)."
Write-Host ""
& $py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
