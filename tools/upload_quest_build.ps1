# Uploads a Quest build to a Meta release channel with ovr-platform-util.
#
#   powershell -File tools/upload_quest_build.ps1 -Channel alpha -Notes "First tester build"
#   powershell -File tools/upload_quest_build.ps1 -Channel beta -Apk builds\phantom-fury-release.apk
#
# Credentials come from the ignored export_credentials.cfg next to the keystore settings:
#   meta/app_id="1234567890"
#   meta/app_secret="..."        (App Credentials from the dashboard's Development > API page)
# or, instead of the secret, a user token:
#   meta/token="..."
# Environment variables META_APP_ID, META_APP_SECRET, and META_TOKEN override the file.
# Nothing here is ever written into the project or printed.
#
# The utility is looked for on PATH, then at %APPDATA%\PhantomFray\ovr-platform-util.exe.
# Download it from the Meta developer site (Distribute > Platform Command Line Utility).
param(
    [Parameter(Mandatory = $true)] [string] $Channel,
    [string] $Apk,
    [string] $Notes = '',
    [ValidateSet('TEENS_AND_ADULTS', 'MIXED_AGES', 'CHILDREN')] [string] $AgeGroup = 'TEENS_AND_ADULTS'
)
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Apk) { $Apk = Join-Path $projectRoot 'builds\phantom-fury-release.apk' }
if (-not (Test-Path $Apk)) { throw "No APK at $Apk. Build one with tools\build_quest_release.ps1 first." }

$credentialsPath = Join-Path $projectRoot 'export_credentials.cfg'
$credentials = @()
if (Test-Path $credentialsPath) { $credentials = Get-Content $credentialsPath }
function Read-CredentialValue([string] $key) {
    $line = $credentials | Where-Object { $_ -like "$key=*" } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Split('=', 2)[1]).Trim('"')
}
$appId = if ($env:META_APP_ID) { $env:META_APP_ID } else { Read-CredentialValue 'meta/app_id' }
$appSecret = if ($env:META_APP_SECRET) { $env:META_APP_SECRET } else { Read-CredentialValue 'meta/app_secret' }
$token = if ($env:META_TOKEN) { $env:META_TOKEN } else { Read-CredentialValue 'meta/token' }
if (-not $appId) { throw 'No Meta App ID. Put meta/app_id="..." in export_credentials.cfg or set META_APP_ID.' }
if (-not $appSecret -and -not $token) { throw 'No Meta App Secret or token. Put meta/app_secret="..." (or meta/token="...") in export_credentials.cfg, or set META_APP_SECRET / META_TOKEN.' }

$util = Get-Command ovr-platform-util -ErrorAction SilentlyContinue
if ($util) { $utilPath = $util.Source } else { $utilPath = Join-Path $env:APPDATA 'PhantomFray\ovr-platform-util.exe' }
if (-not (Test-Path $utilPath)) {
    throw "ovr-platform-util not found on PATH or at $utilPath. Download it from https://developers.meta.com/horizon/resources/publish-reference-platform-command-line-utility/ and put it there."
}

$arguments = @('upload-quest-build', '--age-group', $AgeGroup, '--app-id', $appId, '--apk', $Apk, '--channel', $Channel)
if ($token) { $arguments += @('--token', $token) } else { $arguments += @('--app-secret', $appSecret) }
if ($Notes) { $arguments += @('--notes', $Notes) }

Write-Host "Uploading $(Split-Path -Leaf $Apk) to channel '$Channel' as app $appId ($AgeGroup)"
& $utilPath @arguments
if ($LASTEXITCODE -ne 0) { throw "Upload failed with exit code $LASTEXITCODE" }
Write-Host "Uploaded. Add testers to the '$Channel' channel in the developer dashboard if they are not on it yet."
