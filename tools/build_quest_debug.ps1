param(
    # Measurement build for the hand tracking tests (development/Exercise_Mechanics_Exploration.md,
    # section 3, tests 7 and 8): the HandTrackingProbe overlay, for this export only. Hand tracking
    # and simultaneous hands and controllers are on in every build since decision 39.
    [switch] $HandTrackingTest
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Users\demav\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
$output = Join-Path $projectRoot 'builds\phantom-fury-debug.apk'
$templateVersion = Join-Path $projectRoot 'android\.build_version'
$projectFile = Join-Path $projectRoot 'project.godot'
$handTestMarker = 'debug/hand_tracking_probe=true'

if (-not (Test-Path $templateVersion)) {
    & (Join-Path $PSScriptRoot 'install_android_template.ps1')
}
if (Select-String -Path $projectFile -SimpleMatch $handTestMarker -Quiet) {
    throw "project.godot still has the hand tracking test settings from an interrupted -HandTrackingTest build. Restore it with: git checkout -- project.godot"
}
$projectBytes = $null
if ($HandTrackingTest) {
    $output = Join-Path $projectRoot 'builds\phantom-fury-handtest.apk'
    # The editor ignores override.cfg and custom feature tags when exporting, so the probe
    # setting goes into project.godot for this export and the file is put back byte for byte.
    $projectBytes = [System.IO.File]::ReadAllBytes($projectFile)
    $handTestSettings = @"

[phantom_fury]

$handTestMarker
"@
    [System.IO.File]::AppendAllText($projectFile, $handTestSettings.Replace("`r`n", "`n"))
}
# A Gradle daemon inherits the Godot console's output and keeps this script waiting after the APK
# is written (and, with -HandTrackingTest, project.godot modified). Build without one.
$env:GRADLE_OPTS = (("$env:GRADLE_OPTS -Dorg.gradle.daemon=false").Trim())
try {
    New-Item (Split-Path -Parent $output) -ItemType Directory -Force | Out-Null
    Get-ChildItem (Join-Path $projectRoot 'android\build\res') -Filter '*.import' -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
    & $godot --headless --path $projectRoot --export-debug 'Quest Debug' $output
    if ($LASTEXITCODE -ne 0) {
        throw "Quest debug export failed with exit code $LASTEXITCODE"
    }
} finally {
    if ($projectBytes) {
        [System.IO.File]::WriteAllBytes($projectFile, $projectBytes)
    }
}
Write-Host "Built $output"
