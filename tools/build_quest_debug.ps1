param(
    # Measurement build for the hand tracking tests (development/Exercise_Mechanics_Exploration.md,
    # section 3, tests 7 and 8): OpenXR hand tracking, the simultaneous hands and controllers
    # extension, and the HandTrackingProbe overlay, for this export only.
    [switch] $HandTrackingTest
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Users\demav\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
$output = Join-Path $projectRoot 'builds\phantom-fray-debug.apk'
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
    $output = Join-Path $projectRoot 'builds\phantom-fray-handtest.apk'
    # The Meta export plugin adds the hand tracking permission and the
    # com.oculus.handtracking.frequency meta-data only when this project setting is on in the
    # exporting editor, and the editor ignores override.cfg and custom feature tags, so the
    # settings go into project.godot for this export and the file is put back byte for byte.
    $projectBytes = [System.IO.File]::ReadAllBytes($projectFile)
    $handTestSettings = @"

[xr]

openxr/extensions/hand_tracking=true
openxr/extensions/hand_tracking_unobstructed_data_source=true
openxr/extensions/hand_tracking_controller_data_source=true
openxr/extensions/meta/simultaneous_hands_and_controllers=true

[phantom_fray]

$handTestMarker
"@
    [System.IO.File]::AppendAllText($projectFile, $handTestSettings.Replace("`r`n", "`n"))
    # A Gradle daemon inherits the Godot console's output and keeps it waiting after the APK is
    # written, which would hold project.godot modified. Build without one.
    $env:GRADLE_OPTS = (("$env:GRADLE_OPTS -Dorg.gradle.daemon=false").Trim())
}
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
