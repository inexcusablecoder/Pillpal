# PillPal web in Chrome (DevTools console). Backend on :8000.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$port = 8091

$flutter = $null
if (Get-Command flutter -ErrorAction SilentlyContinue) {
  $flutter = "flutter"
} else {
  $bat = Join-Path $env:USERPROFILE "flutter\bin\flutter.bat"
  if (Test-Path $bat) { $flutter = $bat }
}
if (-not $flutter) {
  Write-Error "Flutter not found."
  exit 1
}

Write-Host "flutter pub get..."
& $flutter pub get

Write-Host "Launching Chrome — http://localhost:$port"
& $flutter run -d chrome `
  --web-port $port `
  --web-hostname localhost `
  --no-web-resources-cdn
