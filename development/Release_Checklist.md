# Phantom Fray Release Checklist

## Automated and desktop validation

- [ ] Clean Godot 4.7.1 import succeeds.
- [ ] `tools/validate_project.sh` passes.
- [ ] Main scene starts in desktop fallback without project script or resource errors.
- [ ] Menu, Operations, Training, Training Complete, Settings, Deploy, pause (operation and training), abort confirm, results, Next Operation, Retry, and Review Training after a defeat work. A fresh profile highlights Training; Deploy still works.
- [ ] Every operation seals its listed rift count and spawns no extra rift. Paired operations keep at most two rifts open.
- [ ] Sealing a rift leaves its phantoms in play; the mission ends in victory only after the last straggler is resolved or reaches the player.
- [ ] Victory and defeat each emit once and show the operation's debrief line.
- [ ] The wrist clock counts up from 0:00 when the round goes live, holds while paused, and never ends the mission.
- [ ] Victory results show the completion time; a faster victory reads NEW BEST TIME, and Reset Progress clears best times.
- [ ] Clearing an operation unlocks the next and records a best score; Reset Progress relocks them, clears best scores, and leaves audio and training settings alone.
- [ ] Yellow rejects the right hand; blue rejects the left. The lure grants the crit score and rift damage.
- [ ] A harder punch does more rift damage (0.85x at 2 m/s up to 1.3x at 6 m/s) and flashes the rift harder; score does not change.
- [ ] Green needs both hands inside its block window; the first hand reads as a catch.
- [ ] Pink cannot be punched and resolves on a successful dodge.
- [ ] Rift shader health, damage flash, beacon, and dissolve visibly change.
- [ ] Chen captions appear on the wrist panel for mission start (first, retry, replay), rift bearings, first contact per species, wrong hand, chain, life force, possession, and outcome.
- [ ] Training runs start to finish: every beat advances only on the right action, a wrong hand or one-hand catch or punched pink gets a correction and does not advance, the possession beat drains 20, life never drops below 20, the live wave ends on a seal and its straggler, and Training Complete appears. End Training from pause marks training done. Training records no clear, score, or time.
- [ ] `tools/check_vo.ps1` reports no clips needing a listen.
- [ ] `art_capture.tscn` and `play_capture.tscn` (including `-- --tutorial`) produce stills without errors.

## Quest hardware matrix

- [ ] Clean install and cold launch.
- [ ] Upgrade install over the previous candidate.
- [ ] Both controllers track and align with the gauntlets.
- [ ] Haptic settings persist and all feedback remains comfortable.
- [ ] Play My Own Music: a playlist started in Spotify (or another music app) keeps playing through launch, a mission, pause, and results, with the soundtrack silent and Dr. Chen still audible.
- [ ] Bracer panel is readable without strain; Chen captions are legible mid-fight.
- [ ] Chen's voice is audible over music at default settings and ducks the music while speaking.
- [ ] Standing-height sanity check.
- [ ] Physical side-step and duck both resolve pink.
- [ ] In training, a paused Angler's lure sits inside a comfortable jab, the paused green inside a two-hand catch, and the floating cards and tags are readable without blocking the phantom.
- [ ] A tap and a full-power punch land at opposite ends of the punch power band on Quest controllers.
- [ ] Possession tint and distortion are strong but comfortable; Reduced Flashes visibly reduces them.
- [ ] Headset removal pauses timers, spawning, damage, and haptics.
- [ ] Resume requires an explicit player action.
- [ ] Controller disconnect and reconnect is recoverable.
- [ ] Results panel responds to both lasers after victory and after defeat.
- [ ] Maximum-load profile (OP-04 or OP-06, two rifts or The Maw's four live phantoms) meets the performance budget.
- [ ] Thirty-minute soak across retries and Next Operation has no rising node or audio voice counts and no repeating errors.
- [ ] Session recorded in [Playtest_Log.md](Playtest_Log.md).

## Content gates

- [ ] Chen's generated takes have been listened to once end to end in headset.
- [ ] Best score per operation shows on Operations and results.
- [ ] At least one replayable mode beyond the campaign (endless hold or difficulty tiers) ships in 1.0.
- [ ] The "TRAINING CHAMBER 07" sign shows only under the training dome, never at the breach site.

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
