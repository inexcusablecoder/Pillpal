# Faster reloads (DDC). If you get a white screen, use start_web.ps1 (--release) instead.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$port = 8091

$flutter = $null
if (Get-Command flutter -ErrorAction SilentlyContinue) { $flutter = "flutter" }
else {
  $bat = Join-Path $env:USERPROFILE "flutter\bin\flutter.bat"
  if (Test-Path $bat) { $flutter = $bat }
}
if (-not $flutter) { Write-Error "Flutter not found."; exit 1 }

& $flutter pub get
& $flutter run -d web-server --web-hostname localhost --web-port $port --no-web-resources-cdn
