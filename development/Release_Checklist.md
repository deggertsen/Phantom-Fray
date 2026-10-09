# Phantom Fray Release Checklist

## Automated and desktop validation

- [ ] Clean Godot 4.7.1 import succeeds.
- [ ] `tools/validate_project.sh` passes.
- [ ] Main scene starts in desktop fallback without project script or resource errors.
- [ ] Menu, Operations, six Training modules, Settings, Deploy, pause, abort confirm, results, Next Operation, and Retry work.
- [ ] Every operation seals its listed rift count and spawns no extra rift. Paired operations keep at most two rifts open.
- [ ] Victory, defeat, and timeout each emit once and show the operation's debrief line.
- [ ] Clearing an operation unlocks the next; Reset Progress relocks them and leaves audio and training settings alone.
- [ ] Yellow rejects the right hand; blue rejects the left. The lure grants the crit score and rift damage.
- [ ] Green needs both hands inside its block window; the first hand reads as a catch.
- [ ] Pink cannot be punched and resolves on a successful dodge.
- [ ] Rift shader health, damage flash, beacon, and dissolve visibly change.
- [ ] Chen captions appear on the wrist panel for mission start, rift bearings, first contact per species, wrong hand, chain, life force, time, and outcome.
- [ ] `art_capture.tscn` and `play_capture.tscn` produce stills without errors.

## Quest hardware matrix

- [ ] Clean install and cold launch.
- [ ] Upgrade install over the previous candidate.
- [ ] Both controllers track and align with the gauntlets.
- [ ] Haptic settings persist and all feedback remains comfortable.
- [ ] Bracer panel is readable without strain; Chen captions are legible mid-fight.
- [ ] Chen's voice is audible over music at default settings and ducks the music while speaking.
- [ ] Standing-height sanity check. (Seated mode is deferred; note seated behavior if observed.)
- [ ] Physical side-step and duck both resolve pink.
- [ ] Possession tint and distortion are strong but comfortable; Reduced Flashes visibly reduces them.
- [ ] Headset removal pauses timers, spawning, damage, and haptics.
- [ ] Resume requires an explicit player action.
- [ ] Controller disconnect and reconnect is recoverable.
- [ ] Results panel responds to both lasers after victory and after defeat.
- [ ] Maximum-load profile (OP-04 or OP-06, two rifts or The Maw's four live phantoms) meets the performance budget.
- [ ] Thirty-minute soak across retries and Next Operation has no rising node or audio voice counts and no repeating errors.
- [ ] Session recorded in [Playtest_Log.md](Playtest_Log.md).

## Content gates

- [ ] Chen's text-to-speech placeholders replaced by generated or recorded takes.
- [ ] Best score per operation persists and shows on Operations and results.
- [ ] At least one replayable mode beyond the campaign (endless hold or difficulty tiers) ships in 1.0.
- [ ] Training-chamber text removed from the breach-site arena or made true by the scene.

## Store submission

- [ ] Release package is ARM64, signed, versioned, built from the tagged commit, and installs cleanly.
- [ ] Meta Quest VRC test plan is completed against the exact release build.
- [ ] Privacy declaration matches local-only settings and no telemetry (revisit when leaderboards or the war map ship).
- [ ] Age rating notes mention fantasy violence and physical exertion.
- [ ] Comfort statement identifies stationary standing play and physical dodging.
- [ ] Boundary and space requirements are explicit.
- [ ] Fitness positioning and any Horizon OS fitness tagging are set.
- [ ] Trailer and screenshots are captured from release settings on headset.
- [ ] App icon, title treatment, hero art, and store description are final.
- [ ] Known issues contain non-blockers only.
- [ ] At least five unfamiliar players complete Training and the first two operations without narration.

## Release operations

- [ ] Tag the exact export commit as `v1.0.0`.
- [ ] Archive signed package, symbols, checksums, store copy, and test evidence.
- [ ] Back up the release keystore and password off-machine.
- [ ] Reserve a hotfix window for comfort, crash, and progression defects.
