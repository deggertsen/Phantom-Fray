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
   - Package: `com.phantomfury.resonancerising` until a final studio namespace is selected
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
godot --headless --path . --export-debug "Quest Debug" builds/phantom-fury-debug.apk
godot --headless --path . --export-release "Quest Release" builds/phantom-fury-release.apk
adb install -r builds/phantom-fury-debug.apk
adb logcat -c
adb logcat | grep -i -E "godot|openxr|phantom"
```

`powershell -File tools/build_quest_debug.ps1 -HandTrackingTest` builds `builds/phantom-fury-handtest.apk`, the hand tracking measurement build for tests 7 and 8 in `development/Exercise_Mechanics_Exploration.md` (section 3, "Running tests 7 and 8"). Hand tracking and simultaneous hands and controllers are on in every build; the switch adds only the probe overlay setting to `project.godot` for that export and restores the file afterwards. The export stops the adb server, which ends any running `adb logcat`; start the capture again after a build. The device keeps its own log buffer, so `adb logcat -d` recovers what was missed.

## Credentials

Every secret lives outside Git, in one of two places that the scripts already read:

- `export_credentials.cfg` in the project root (ignored; `export_credentials.example.cfg` shows the keys). It holds the release keystore path, user, and password for `tools/build_quest_release.ps1`, and the Meta App ID and App Secret (or a user token) for `tools/upload_quest_build.ps1`.
- `%APPDATA%\PhantomFray\` for machine-wide tools: `elevenlabs_key.txt` for Chen's voice, and `ovr-platform-util.exe` if it is not on PATH.

Environment variables `META_APP_ID`, `META_APP_SECRET`, and `META_TOKEN` override the file, which is the path to use from CI. The App ID and App Credentials come from the Meta Horizon developer dashboard, under your app, Development, API. Treat the App Credentials like a password: it lets anyone upload builds as you.

## Release channel upload

The short way is the deploy skill (`.claude/skills/deploy/SKILL.md`) or its script, which does every step below in order from the main clone:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/deploy_quest.ps1 -Channel alpha -Notes "what changed"
```

By hand:

1. Bump `version/code` in `export_presets.cfg` under the Quest Release preset. Meta rejects an upload whose version code is not higher than the last one on any channel.
2. Build: `powershell -File tools/build_quest_release.ps1`.
3. Upload: `powershell -File tools/upload_quest_build.ps1 -Channel alpha -Notes "what changed"`. The script passes `--age-group TEENS_AND_ADULTS`; without an age group Meta leaves the build in draft.
4. In the dashboard, add testers to the channel by email. They install from Library, My Preview Apps.
5. Record the version code, commit, and channel in `development/Playtest_Log.md` so tester reports can be matched to a build.

Production goes through the same utility with `--channel store`, but only after the VRC pass and store listing in [Release_Checklist.md](Release_Checklist.md).

## Required package checks

- Immersive HMD launch intent is present.
- OpenXR loader is version 1.0.34 or later.
- Android target SDK is 34 or lower (`gradle_build/target_sdk="34"` in both presets). Meta's upload check rejected target SDK 36 on 2026-10-25; the Godot 4.7 template defaults to 36, so the preset must override it.
- ARM64 native libraries are present.
- Debug symbols and signing credentials are absent from the release package.
- Music under `Assets/Audio/Music/` and Chen takes under `Assets/Audio/VO/chen/` are included by the export preset.
- The application launches from a clean installation and after an upgrade installation.

## Hardware-only acceptance

Desktop fallback does not validate VR. A release candidate must be tested for controller tracking, fist alignment, haptics, wrist readability, head/body collision, pause on headset removal, resume, frame pacing, and clean shutdown on the minimum supported Quest headset.
