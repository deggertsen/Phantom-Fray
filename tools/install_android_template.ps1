$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotTemplates = Join-Path $env:APPDATA 'Godot\export_templates\4.7.1.stable'
$sourceArchive = Join-Path $godotTemplates 'android_source.zip'
$androidRoot = Join-Path $projectRoot 'android'
$buildRoot = Join-Path $androidRoot 'build'

if (-not (Test-Path $sourceArchive)) {
    throw "Missing Godot Android source template: $sourceArchive"
}

if (Test-Path $buildRoot) {
    Remove-Item $buildRoot -Recurse -Force
}
New-Item $buildRoot -ItemType Directory -Force | Out-Null
Expand-Archive -Path $sourceArchive -DestinationPath $buildRoot -Force
Set-Content -Path (Join-Path $androidRoot '.build_version') -Value '4.7.1.stable' -NoNewline
Write-Host "Installed Godot 4.7.1 Android Gradle template in $androidRoot"
