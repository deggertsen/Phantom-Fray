# Meta Quest Release Evidence

## Exact release artifact

- Package: `com.phantomfray.resonancerising`
- Version: `1.0.0` (`versionCode` 1)
- Artifact: `builds/phantom-fray-release.apk` (ignored generated output)
- SHA-256: `cd0f3e98b0f007f5ca8cb867823ed9fea20d0345f748411d4ff5b778b2bd2ee9`
- Size: approximately 119 MiB
- Native ABI: ARM64-v8a only
- Minimum SDK: 24
- Target/compile SDK: 36
- Renderer: Godot Compatibility (`gl_compatibility`)

## Signing evidence

- APK Signature Scheme v2: verified
- Certificate DN: `CN=Phantom Fray Release, OU=Resonance Strike Force, O=Phantom Fray, C=US`
- Key: RSA 4096-bit
- Certificate SHA-256: `c9bec7680d2491103204d2c7e7cc26ddb17f071d7d0f4a8bddf4dc4097d2bbba`
- The keystore and ignored credentials are outside source control. They must be backed up securely before distribution.

## Meta/OpenXR manifest evidence

Verified in the release APK:

- `org.khronos.openxr.permission.OPENXR`
- `org.khronos.openxr.permission.OPENXR_SYSTEM`
- `android.hardware.vr.headtracking`
- `com.oculus.supportedDevices`
- `com.oculus.intent.category.VR`
- `org.khronos.openxr.intent.category.IMMERSIVE_HMD`
- OpenXR Vendors Meta loader/activity metadata
- OpenXR Vendors 5.1.0 native ARM64 library
- No `android:debuggable=true` declaration in the release manifest audit

## Automated/source evidence

- Godot 4.7.1 project import succeeds.
- Automated variant/life-force validation reported `PHANTOM FRAY VALIDATION PASSED` after the final gameplay review pass.
- `git diff --check` passes.
- Debug and release Gradle exports complete from the tracked presets and documented local toolchain.

## VRC checks that require a physical Quest

These cannot be honestly marked complete without a connected headset:

- Fresh install and cold launch from the Horizon OS library
- Controllers, haptics, recentering, and tracked-fist alignment
- Head/body hurtbox and physical dodge ergonomics
- Headset-removal/system-menu suspend and explicit resume
- Sustained frame pacing, thermal behavior, and reprojection metrics
- Three retries and ten-minute soak without resource growth
- Guardian/boundary and seated/standing comfort checks
- Audio loudness and critical-cue audibility on headset speakers
- Upgrade install over the previous candidate

## VRC/store checks requiring Meta dashboard access

- Application entitlement/integrity integration if required by the selected distribution channel
- Current Quest VRC automated upload checks
- Data Use Checkup/privacy declaration
- Age rating and content descriptors
- Final store title, package ownership, pricing, supported devices, and regions
- Screenshots, trailer, hero/key art, and app icon review
- Release channel upload, closed testing, staged rollout, and submission

The release package is technically prepared for device installation and VRC testing. It is not represented as having passed headset or Meta dashboard review until those external checks are performed against this exact SHA-256 artifact.
