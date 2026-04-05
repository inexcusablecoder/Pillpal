# Sync remote branch `calling_agent` without git (GitHub ZIP). Preserves backend\.env.
$ErrorActionPreference = "Stop"
$dst = Split-Path $PSScriptRoot -Parent

$zip = "$env:TEMP\Pillpal-calling_agent.zip"
$extract = "$env:TEMP\Pillpal-calling_agent-sync"
$src = Join-Path $extract "Pillpal-calling_agent"

Write-Host "Downloading calling_agent from GitHub..."
Invoke-WebRequest -Uri "https://github.com/inexcusablecoder/Pillpal/archive/refs/heads/calling_agent.zip" -OutFile $zip -UseBasicParsing
Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $zip -DestinationPath $extract -Force

$envFile = Join-Path $dst "backend\.env"
$bak = "$env:TEMP\pillpal-env-backup.sync"
if (Test-Path $envFile) { Copy-Item $envFile $bak -Force; Write-Host "Backed up backend\.env" }

Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
Write-Host "Synced into: $dst"

if (Test-Path $bak) { Copy-Item $bak $envFile -Force; Write-Host "Restored backend\.env" }

Write-Host ""
Write-Host "Next (from folder: $dst\backend):"
Write-Host "  .\.venv\Scripts\pip.exe install -r requirements.txt"
Write-Host "  .\.venv\Scripts\python.exe -m alembic upgrade head"
Write-Host "From $dst\frontend\pillpal_app: flutter pub get"
