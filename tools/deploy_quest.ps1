# Deploys a release build to a Meta release channel, in order:
# version bump, validation, release export, upload.
#
#   powershell -File tools/deploy_quest.ps1 -Channel alpha -Notes "Shuffled boss cycle"
#   powershell -File tools/deploy_quest.ps1 -Channel beta -VersionName 1.1.0 -Notes "..."
#
# Run it from the main clone, not a worktree: it needs the ignored export_credentials.cfg
# with the keystore password and the Meta app secret, and it commits the version bump.
# -SkipValidation skips the headless runner (only for a rebuild of something already validated).
# -NoCommit leaves the version bump uncommitted.
param(
    [Parameter(Mandatory = $true)] [string] $Channel,
    [string] $Notes = '',
    [string] $VersionName = '',
    [switch] $SkipValidation,
    [switch] $NoCommit
)
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Users\demav\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
$presets = Join-Path $projectRoot 'export_presets.cfg'
$credentialsPath = Join-Path $projectRoot 'export_credentials.cfg'

# Guard rails before anything is changed.
if (-not (Test-Path $credentialsPath)) { throw "No export_credentials.cfg in $projectRoot. Run from the main clone." }
$credentials = Get-Content $credentialsPath
foreach ($key in 'keystore/release', 'keystore/release_user', 'keystore/release_password', 'meta/app_id') {
    $line = $credentials | Where-Object { $_ -like "$key=*" } | Select-Object -First 1
    if (-not $line -or -not ($line.Split('=', 2)[1]).Trim('"')) { throw "export_credentials.cfg has no value for $key. Run from the main clone, or fill it in." }
}
$secret = $credentials | Where-Object { $_ -like 'meta/app_secret=*' -or $_ -like 'meta/token=*' } | Select-Object -First 1
if (-not $secret -or -not ($secret.Split('=', 2)[1]).Trim('"')) { throw 'export_credentials.cfg has neither meta/app_secret nor meta/token.' }
Push-Location $projectRoot
try {
    $dirty = git status --porcelain | Where-Object { $_ -notmatch 'export_presets\.cfg$' }
    if ($dirty) { throw "Working tree has uncommitted changes besides export_presets.cfg:`n$($dirty -join "`n")`nCommit or revert them first, so the tag matches what ships." }
    $branch = git rev-parse --abbrev-ref HEAD
    if ($branch -ne 'main') { Write-Warning "Deploying from branch '$branch', not main." }

    # Version bump: both presets share one code, so debug and release never disagree.
    $text = Get-Content $presets -Raw
    $codes = [regex]::Matches($text, '(?m)^version/code=(\d+)$') | ForEach-Object { [int]$_.Groups[1].Value }
    if ($codes.Count -eq 0) { throw 'No version/code lines in export_presets.cfg' }
    $newCode = ($codes | Measure-Object -Maximum).Maximum + 1
    $text = [regex]::Replace($text, '(?m)^version/code=\d+$', "version/code=$newCode")
    if ($VersionName) { $text = [regex]::Replace($text, '(?m)^version/name="[^"]*"$', "version/name=`"$VersionName`"") }
    [System.IO.File]::WriteAllText($presets, $text.Replace("`r`n", "`n"))
    $versionName = ([regex]::Match($text, '(?m)^\[preset\.1\](?:.|\n)*?^version/name="([^"]*)"$')).Groups[1].Value
    Write-Host "Version code $newCode, version name $versionName"

    # Validation on the exact tree that ships.
    if (-not $SkipValidation) {
        & $godot --headless --xr-mode off --editor --path $projectRoot --quit 2>$null | Out-Null
        $passed = $false
        for ($attempt = 1; $attempt -le 2 -and -not $passed; $attempt++) {
            $out = & $godot --headless --xr-mode off --path $projectRoot --script res://Tests/validation_runner.gd 2>&1 | Out-String
            $passed = $out -match 'VALIDATION PASSED'
            if (-not $passed) {
                $errors = ($out -split "`n" | Where-Object { $_ -match '^ERROR: [A-Z][a-z]' }) -join "`n"
                if ($errors -match 'Yellow arc stalled' -and ($errors -split "`n").Count -eq 1) { Write-Warning 'Only the known flaky arc test failed; retrying once.' } else { throw "Validation failed:`n$errors" }
            }
        }
        if (-not $passed) { throw 'Validation failed twice.' }
        git checkout -- addons icon.svg.import 2>$null
        Write-Host 'Validation passed'
    }

    # Commit the bump so the shipped build is a known commit.
    if (-not $NoCommit) {
        git add export_presets.cfg
        git commit -q -m "Bump version code to $newCode for the $Channel channel."
    }
    $commit = git rev-parse --short HEAD

    # Release export, then upload. The Gradle daemon would hold the console open after the APK is written.
    $env:GRADLE_OPTS = (("$env:GRADLE_OPTS -Dorg.gradle.daemon=false").Trim())
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_quest_release.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
    $apk = Join-Path $projectRoot 'builds\phantom-fury-release.apk'
    $uploadNotes = if ($Notes) { "$Notes (v$versionName code $newCode, $commit)" } else { "v$versionName code $newCode, $commit" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'upload_quest_build.ps1') -Channel $Channel -Apk $apk -Notes $uploadNotes
    if ($LASTEXITCODE -ne 0) { throw 'Upload failed' }

    $sha = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower()
    Write-Host ''
    Write-Host "Deployed v$versionName (code $newCode) from $commit to channel '$Channel'."
    Write-Host "APK sha256 $sha"
    Write-Host "Next: push the bump commit, add testers to '$Channel' in the dashboard, and log the build in development/Playtest_Log.md."
} finally {
    Pop-Location
}
