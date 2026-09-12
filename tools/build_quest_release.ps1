$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Users\demav\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe'
$output = Join-Path $projectRoot 'builds\phantom-fray-release.apk'
$templateVersion = Join-Path $projectRoot 'android\.build_version'
$credentialsPath = Join-Path $projectRoot 'export_credentials.cfg'

if (-not (Test-Path $templateVersion)) {
    & (Join-Path $PSScriptRoot 'install_android_template.ps1')
}
if (-not (Test-Path $credentialsPath)) {
    throw 'Missing ignored export_credentials.cfg with Quest Release keystore settings.'
}
$credentials = Get-Content $credentialsPath
function Read-CredentialValue([string] $key) {
    $line = $credentials | Where-Object { $_ -like "$key=*" } | Select-Object -First 1
    if (-not $line) { throw "Missing credential $key" }
    return ($line.Split('=', 2)[1]).Trim('"')
}
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = Read-CredentialValue 'keystore/release'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = Read-CredentialValue 'keystore/release_user'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = Read-CredentialValue 'keystore/release_password'

New-Item (Split-Path -Parent $output) -ItemType Directory -Force | Out-Null
Get-ChildItem (Join-Path $projectRoot 'android\build\res') -Filter '*.import' -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
& $godot --headless --path $projectRoot --export-release 'Quest Release' $output
if ($LASTEXITCODE -ne 0) {
    throw "Quest release export failed with exit code $LASTEXITCODE"
}
Write-Host "Built $output"
