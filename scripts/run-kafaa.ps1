# Run Kafaa with local build configuration on Windows
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = Join-Path (Split-Path -Parent $ScriptDir) "kafaa_app"
$ConfigFile = Join-Path $AppDir "env\dev.json"

if (-not (Test-Path $ConfigFile)) {
    Write-Error "Kafaa configuration is missing: kafaa_app\env\dev.json`nCopy env\dev.example.json to env\dev.json and add the kaffaDB public API key."
    exit 1
}

Set-Location $AppDir
flutter run --dart-define-from-file="$ConfigFile" @args
