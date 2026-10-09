# Meta Quest Export Guide

## Pinned baseline

- Godot 4.7.1 stable
- godot-xr-tools 4.5.1
- OpenJDK 17
- Android SDK Platform Tools and current Godot-supported Build Tools
- Android NDK r28b
- ARM64 Android target
- OpenXR with the Khronos Android loader 1.0.34 or later
- Godot OpenXR Vendors plugin matching Godot 4.7.x

## First-time workstation setup

1. Install Godot 4.7.1 export templates.
2. Install OpenJDK 17, Android Studio/SDK, platform tools, and NDK r28b.
3. In Godot Editor Settings, set the Java SDK and Android SDK paths.
4. Install Android build templates through **Project → Install Android Build Template**.
5. Install the Godot OpenXR Vendors plugin under `addons/` and enable it.
6. Create an Android export preset named `Quest Debug`:
   - Use Gradle Build: enabled
   - XR Mode: OpenXR
   - Meta vendor: enabled
   - Architecture: ARM64 only
   - Package: `com.phantomfray.resonancerising` until a final studio namespace is selected
   - Runnable: enabled
7. Create a second `Quest Release` preset with release signing. Never commit the keystore or credentials.

`export_presets.cfg` should be committed after generating it in Godot. This repository does not hand-author the preset because Android export property keys vary by Godot/plugin version and an invalid preset is worse than an explicit setup gate.

## Renderer and performance baseline

The project uses the Compatibility renderer for standalone Quest reliability. Begin at:

- Quest 2-class minimum: 72 Hz, 13.9 ms frame budget
- Quest 3/3S target: validate 90 Hz only after the 72 Hz maximum-load gate passes
- Maximum active gameplay load: 2 concurrent rifts (OP-04, OP-05) or one double-size rift with 4 live phantoms (OP-06)
- No real-time shadows in the launch arena
- MSAA 2x (`msaa_3d=1` in Godot project settings); raise only with device measurements

Tune render-target multiplier and foveation only on device.

## Build commands

The tracked presets use Gradle and the OpenXR Vendors Meta plugin. The generated `android/` directory remains ignored; recreate it from the installed Godot 4.7.1 source template before building:

```powershell
powershell -File tools/install_android_template.ps1
powershell -File tools/build_quest_debug.ps1
```

Equivalent commands after template installation:

```bash
godot --headless --path . --export-debug "Quest Debug" builds/phantom-fray-debug.apk
godot --headless --path . --export-release "Quest Release" builds/phantom-fray-release.apk
adb install -r builds/phantom-fray-debug.apk
adb logcat -c
adb logcat | grep -i -E "godot|openxr|phantom"
```

## Required package checks

- Immersive HMD launch intent is present.
- OpenXR loader is version 1.0.34 or later.
- ARM64 native libraries are present.
- Debug symbols and signing credentials are absent from the release package.
- Music under `Assets/Audio/Music/` and Chen takes under `Assets/Audio/VO/chen/` are included by the export preset.
- The application launches from a clean installation and after an upgrade installation.

## Hardware-only acceptance

Desktop fallback does not validate VR. A release candidate must be tested for controller tracking, fist alignment, haptics, wrist readability, head/body collision, pause on headset removal, resume, frame pacing, and clean shutdown on the minimum supported Quest headset.
