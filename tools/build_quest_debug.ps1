$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Users\demav\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe'
$output = Join-Path $projectRoot 'builds\phantom-fray-debug.apk'
$templateVersion = Join-Path $projectRoot 'android\.build_version'

if (-not (Test-Path $templateVersion)) {
    & (Join-Path $PSScriptRoot 'install_android_template.ps1')
}
New-Item (Split-Path -Parent $output) -ItemType Directory -Force | Out-Null
Get-ChildItem (Join-Path $projectRoot 'android\build\res') -Filter '*.import' -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
& $godot --headless --path $projectRoot --export-debug 'Quest Debug' $output
if ($LASTEXITCODE -ne 0) {
    throw "Quest debug export failed with exit code $LASTEXITCODE"
}
Write-Host "Built $output"
