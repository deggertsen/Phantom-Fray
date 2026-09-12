$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$apk = Join-Path $projectRoot 'builds\phantom-fray-menu-debug.apk'
$package = 'com.phantomfray.resonancerising'
$evidence = Join-Path $projectRoot 'reports\quest-menu'

New-Item $evidence -ItemType Directory -Force | Out-Null
$devices = & $adb devices
if (-not ($devices -match "\sdevice$")) {
    throw 'No authorized Quest device found. Approve USB debugging inside the headset.'
}

& $adb uninstall $package | Out-Host
& $adb install $apk | Out-Host
& $adb logcat -c
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 | Out-Host
Start-Sleep -Seconds 8
& $adb exec-out screencap -p > (Join-Path $evidence 'main-menu.png')
& $adb shell uiautomator dump /sdcard/phantom-menu.xml | Out-Host
& $adb pull /sdcard/phantom-menu.xml (Join-Path $evidence 'main-menu.xml') | Out-Host
& $adb logcat -d -b main -b system -b crash -v threadtime > (Join-Path $evidence 'launch-log.txt')
& $adb shell dumpsys package $package > (Join-Path $evidence 'package.txt')
Write-Host "Captured Quest menu evidence in $evidence"
