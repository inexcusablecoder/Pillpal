# Flutter web for PillPal (port 8091, local CanvasKit). Run backend first on :8000.
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
  Write-Error "Flutter not found. Install Flutter SDK and add to PATH, or install to $env:USERPROFILE\flutter"
  exit 1
}

Write-Host "flutter pub get..."
& $flutter pub get

Write-Host ""
Write-Host "Serving web on http://localhost:$port (API expected at http://localhost:8000)"
Write-Host "Using --release for a stable web build (avoids dev-compiler white-screen issues)."
Write-Host ""

& $flutter run -d web-server `
  --release `
  --web-hostname localhost `
  --web-port $port `
  --no-web-resources-cdn
