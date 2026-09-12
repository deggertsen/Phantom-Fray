# Production Status — 2026-07-18

## Implemented in `production-roadmap-through-phase-5`

- Finite three-rift mission with countdown, score, combo, timer, victory, defeat, timeout, results, and retry
- Life-force drain/recovery/fail-state integration
- Yellow left-hand and Blue right-hand resonance-point rules
- Green two-hand block and Pink telegraphed physical dodge
- Honest rift health/closure shader path
- Wrist score/progress/time HUD
- RSF training-chamber presentation and ERM gauntlet overlays
- Audio buses, music pressure hooks, and Critical life-force routing
- Main menu, tutorial, pause, persistent audio/haptic settings, and session flow
- XR focus-loss suspension hook and debug performance monitor
- Automated validation runner and GitHub Actions import/test workflow
- Quest export, release, performance, known-issues, and store-asset documentation

## Build artifact produced

- Signed ARM64 Meta Quest debug APK: `builds/phantom-fray-debug.apk` (generated artifact, ignored by Git)
- Debug SHA-256: `67577d91353ef873128e3e4e097f1aa6f41ccd8bd8593f28896ec7a310012332`
- Production-signed ARM64 Meta Quest release APK: `builds/phantom-fray-release.apk`
- Release SHA-256: `cd0f3e98b0f007f5ca8cb867823ed9fea20d0345f748411d4ff5b778b2bd2ee9`
- Release package: `com.phantomfray.resonancerising`, version `1.0.0`, target SDK 36
- APK Signature Scheme v2 verified with the 4096-bit Phantom Fray production certificate
- OpenXR Vendors 5.1.0 Meta plugin packaged
- Manifest contains `org.khronos.openxr.intent.category.IMMERSIVE_HMD`, `com.oculus.intent.category.VR`, Quest supported-device metadata, and `android.hardware.vr.headtracking`

## Cannot be completed without external resources

- Physical Quest installation, validation, and balance (no ADB headset connected)
- Secure off-machine backup of the release keystore and its password
- Meta dashboard/VRC/store submission
- Closed playtest recruitment and recorded results
- Final bespoke art, logo/key art, trailer capture, and professional audio mastering

These are documented as release gates rather than represented as complete.
