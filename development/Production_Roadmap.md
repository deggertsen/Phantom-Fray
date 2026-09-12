# Phantom-Fray — Production Roadmap

**Last updated:** 2026-07-18  
**Current stage:** Software-complete launch candidate; Quest hardware/store gates outstanding
**Engine:** Godot 4.7.1 + OpenXR / godot-xr-tools 4.5.1
**Target:** Meta Quest-class standalone headset

---

## Scope Freeze for v1

One short, replayable RSF operation:

`Main Menu → Tutorial or Deploy → 3–5 minute three-rift mission → Results → Retry`

The player is stationary, physically punches, blocks, ducks, and side-steps. There is no artificial locomotion. Full campaign progression, bosses, powers, multiplayer, online leaderboards, and hand tracking as the primary input remain post-launch work.

---

## Current Status

| Area | Status |
|---|---|
| OpenXR bootstrap, tracked controllers, ERM glove overlays | Implemented; headset verification required |
| Life force, recovery, infection feedback, fail state | Implemented |
| Finite round, score, combo, timer, win/lose/timeout, retry | Implemented |
| Yellow/Blue/Green/Pink mechanics | Implemented; headset balance required |
| Rift weakening and closure shader | Implemented |
| Wrist HUD and world-space messaging | Implemented |
| Main menu, tutorial, pause, settings, results flow | Implemented |
| RSF arena presentation and audio buses/intensity | Implemented procedural launch-candidate pass |
| Automated import/rule validation and CI | Implemented |
| Android/Quest export and signed package | Blocked on local Android/export toolchain |
| Meta VRC/store submission and closed playtest | External release gate |

See [Production_Status.md](Production_Status.md) and [Known_Issues.md](Known_Issues.md) for the exact boundary between implemented work and external gates.

---

## Phase 0 — Reorientation

- [x] Upgrade and clean-import under Godot 4.7.1
- [x] Confirm desktop fallback startup and gameplay scene loading
- [x] Audit orphaned architecture, variant shells, shader paths, audio, UI, and build configuration
- [x] Freeze the focused v1 scope
- [ ] Launch and verify on the minimum supported Quest headset

**Status:** Software complete; hardware check remains.

---

## Phase 1 — Vertical Slice: One Round That Matters

### Life force and fail state

- [x] Phantom contact drains life force
- [x] Recovery after a clear interval
- [x] Wrist meter, heartbeat, danger tint, damage cue
- [x] Clear depletion state

### Win condition and round loop

- [x] Three-rift finite mission; no infinite refill
- [x] Countdown, four-minute window, victory, defeat, and timeout
- [x] Score, combo multiplier, rift progress, and retry

### Minimal HUD

- [x] Life force
- [x] Score and multiplier
- [x] Rifts closed and remaining time
- [x] World-space mission/result messaging

### Yellow and rift visual honesty

- [x] Yellow requires the left hand
- [x] Visible resonance point and bonus score/rift damage
- [x] Rift shader reads health, damage flash, and closure dissolve

**Status:** Implemented. The 3–5 minute feel target requires headset playtesting.

---

## Phase 2 — Combat Depth

- [x] Blue: right-hand resonance strike
- [x] Green: two-hand timed block
- [x] Pink: telegraphed locked-lane physical dodge
- [x] Normal/sweet/rejected haptic tiers
- [x] Sweet-spot combo multiplier
- [x] Bounded mixed spawn pool and global launch load
- [ ] Tune timings, sensor alignment, and mix weights through headset playtests

**Status:** Mechanically implemented; ergonomic balance remains.

---

## Phase 3 — Presentation Pass

- [x] Variant colors and mechanic-specific silhouettes/telegraphs
- [x] ERM energy overlays on the low-poly glove rigs
- [x] RSF training-chamber identity, safe-space ring, pylons, and briefing
- [x] Rift and phantom dissolve correction
- [x] Life-force tint/heartbeat presentation
- [x] Music/SFX/Critical/UI bus architecture and pressure hooks
- [ ] Replace procedural launch-candidate art with final authored models/key art if budget permits
- [ ] Final impact/UI/proximity sound design and mastering

**Status:** Coherent procedural product pass implemented. Bespoke production art/audio is a quality upgrade, not silently marked complete.

---

## Phase 4 — Meta and UX

- [x] Main menu
- [x] Tutorial explaining stationary space, grip punches, all four variants, rifts, and life force
- [x] Menu → Play → Results → Retry flow
- [x] Pause and explicit resume
- [x] Persistent music and haptic settings
- [x] Keyboard fallbacks for desktop validation
- [ ] Validate controller button labels, text distance, readability, and seated use in headset
- [ ] Optional laser-pointer panel polish after hardware UX findings

**Status:** Implemented with controller-button world-space UI; hardware UX pass remains.

---

## Phase 5 — Platform and Production Hardening

- [x] Compatibility renderer and Quest-first content budget
- [x] Explicit audio buses
- [x] XR focus/session-loss suspension hooks
- [x] Debug performance monitor and documented 72/90 Hz gates
- [x] Automated resource/rule validation runner
- [x] GitHub Actions validation workflow pinned to Godot 4.7.1
- [x] Quest export guide, release checklist, store asset plan, and known issues
- [x] Signing/build-output ignore rules and portable editor configuration
- [x] Install JDK/Android SDK/NDK/export templates/OpenXR Vendors plugin
- [x] Generate tracked Godot Android export presets from the pinned toolchain
- [x] Produce a signed, ARM64 Meta Quest debug APK
- [x] Produce the release-signed package with the private production keystore
- [ ] Complete on-device performance, suspend/resume, soak, and clean-install matrices
- [x] Record release artifact signing, package, ABI, and Meta/OpenXR manifest evidence
- [ ] Run closed playtest and balance pass

**Status:** Build tooling and a Meta-packaged debug artifact are complete. Hardware validation, private release signing, playtesting, and store-account operations remain external gates.

---

## Phase 6 — Launch and Immediate Post-Launch

- [ ] Complete the Meta Quest VRC test plan against the exact signed release build
- [ ] Submit store listing, privacy/age-rating declarations, screenshots, and trailer
- [ ] Release v1.0.0
- [ ] Monitor the hotfix window for comfort, crash, input, and progression defects
- [ ] Convert playtest/support evidence into a 1.1 backlog

Phase 6 is not representable as complete from source code alone. The repository contains the launch procedure; release requires an authorized Meta developer account, signing identity, target hardware, store assets, and human playtest evidence.

---

## Definition of Production Ready

A release build is ready when:

1. A first-time player can learn and complete the mission without developer narration.
2. Victory, defeat, timeout, pause, resume, results, and retry are reliable.
3. All four Phantom rules are readable and physically comfortable.
4. The maximum-load mission meets the documented frame budget on the minimum headset.
5. Three retries and a ten-minute soak do not leak gameplay nodes, timers, or audio voices.
6. The signed package installs and launches cleanly on a factory-clean Quest profile.
7. The exact release build passes Meta's current VRC test plan.
8. Known issues contain non-blockers only.

---

## Production References

- [Production status](Production_Status.md)
- [Quest export guide](Quest_Export_Guide.md)
- [Performance budget](Performance_Budget.md)
- [Release checklist](Release_Checklist.md)
- [Store asset plan](Store_Asset_Plan.md)
- [Known issues](Known_Issues.md)
- [Life force design](Life_Force_System.md)
- [Phantom enemy design](Phantom_Enemy_Breakdown.md)
