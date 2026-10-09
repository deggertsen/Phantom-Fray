# Phantom Fray Release Checklist

## Automated and desktop validation

- [ ] Clean Godot 4.7.1 import succeeds.
- [ ] `tools/validate_project.sh` passes.
- [ ] Main scene starts in desktop fallback without project script/resource errors.
- [ ] Menu, tutorial pages, settings, Deploy, pause, results, and retry work.
- [ ] Three rifts close and no fourth rift spawns.
- [ ] Victory, defeat, and timeout emit once.
- [ ] Yellow rejects right hand; Blue rejects left hand.
- [ ] Green requires both hands inside its block window.
- [ ] Pink cannot be punched and resolves on a successful dodge.
- [ ] Rift shader health and dissolve parameters visibly change.

## Quest hardware matrix

- [ ] Clean install and cold launch.
- [ ] Upgrade install over the previous candidate.
- [ ] Both controllers track and align with visible fists.
- [ ] Haptic settings persist and all feedback remains comfortable.
- [ ] Play My Own Music: a playlist started in Spotify (or another music app) keeps playing through launch, a mission, pause, and results, with the soundtrack silent and Dr. Chen still audible.
- [ ] Wrist life/score/time HUD is readable without strain.
- [ ] Standing and seated-height sanity checks.
- [ ] Physical side-step and duck both work for Pink.
- [ ] Headset removal pauses timers, spawning, damage, and haptics.
- [ ] Resume requires an explicit player action.
- [ ] Controller disconnect/reconnect is recoverable.
- [ ] Five-minute maximum-load profile meets the performance budget.
- [ ] Ten-minute soak test has no rising node/audio counts or repeating errors.

## Store submission

- [ ] Release package is ARM64, signed, versioned, and installs cleanly.
- [ ] Meta Quest VRC test plan is completed against the exact release build.
- [ ] Privacy declaration matches local-only settings and no telemetry.
- [ ] Age rating notes mention fantasy violence and physical exertion.
- [ ] Comfort statement identifies stationary standing/seated play and physical dodging.
- [ ] Boundary/space requirements are explicit.
- [ ] Trailer and screenshots are captured from release settings.
- [ ] App icon, title treatment, hero art, and store description are final.
- [ ] Known issues contain non-blockers only.
- [ ] At least five unfamiliar players complete the tutorial and one mission without narration.

## Release operations

- [ ] Tag the exact export commit as `v1.0.0`.
- [ ] Archive signed package, symbols, checksums, store copy, and test evidence.
- [ ] Reserve a hotfix window for comfort, crash, and progression defects.
