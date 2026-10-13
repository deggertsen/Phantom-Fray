# Production Status — 2026-10-13

## Implemented on `main`

### Combat
- Phantom base: one continuous accelerating bezier arc into reach, lunge at the head, recover and re-approach. Strikes count once in reach. Stall and lifetime cleanup.
- Angler (yellow left, blue right): lure as the resonance crit in hook, uppercut, or jab position. Wrong hand rejects and breaks the chain.
- Carapace (green): first hand is a catch, second hand inside 0.55 s is the block.
- Spearfin (pink): telegraph, floor lane shader, charge; resolved by leaving the lane. Cannot be punched.
- Three body forms per species, built as one mesh each and prewarmed with the combat shaders while the menu is up.
- Pressure scaling per wave: speed and telegraph scales applied to every phantom, and the difficulty's contact scale to every contact.
- Possession: head or body within 0.30 m of the phantom core. Drains 20 life force, plays the siphon sound, frost and veins, distortion and impact slam.
- Strike VFX: sparks, shockwave, flash. Haptic tiers for normal, crit, guard, and rejected.

### Rifts and missions
- Six operations in `Scripts/Core/mission_catalog.gd` with per-rift wave tables, pressure labels, open barks, seal lines, mop-up line, and debriefs.
- Rift director: single, clustered pair, or front-arc placement; up to two concurrent rifts; staggered first spawns.
- Rift manager: health, damage flash, health shader, beacon column with floor ring and label, orbiting debris, scale for The Maw, dissolve on seal.
- Stragglers: a sealed rift stops spawning but its phantoms stay in play and still score or hurt. The rift reports `drained` when they are gone; the director reports `all_clear` when every rift is sealed and drained, and only then is the operation won. Status reads "SEALED • CLEAR PHANTOMS" meanwhile. Scene teardown is never read as a clear.
- Rift compass chevron at the edge of view and phantom bearing markers.
- Round controller: pre-round countdown, elapsed mission clock (counts up, holds on pause, never ends the round), chain multiplier to 3x with crit and on-beat gains, victory, defeat, pause and resume. It applies the chosen difficulty to a copy of the mission before any rift opens. Victory records the completion time as the best time for that operation and difficulty when it is faster.

### Difficulty and the movement tier
- Four difficulties in `Scripts/Core/difficulty_tier.gd`: Assist, Standard, Operator, Full Resonance. Each multiplies a wave's speed, tells, rift health, and spawn interval, and scales contact damage; Standard is the catalog exactly. Chosen on the Operations screen (a row of four), saved in `GameSettings.difficulty_tier`, default Standard, Full Resonance open from the start. Deploy, Operations, and results show it. Best score and time are kept per mission and difficulty.
- Full Resonance: squat-depth resonance sweeps (`Scripts/Hazards/resonance_sweep.gd`) join every rift's pool, never closer than 8 s apart, and Chen says a Full Resonance line in the countdown. The Maw (OP-06) carries its boss there and only there: the break odds (`MawBoss.decide_break`), the false seal and turn, then high sweeps to squat, low sweeps to jump, slams to side-step, push-ups on the spent tentacle (`PushUpDetector`, head height), and escort volleys, until the anchor runs out and it retreats. Every other difficulty keeps the seal and the occasional tentacle glimpse.
- Squat detector (`SquatDetector`, every build) with the bend check; push-up detector; jump tracking for the low sweep. Debug builds: B (Shift+B forces a break) or `--mission=the_maw_boss` deploys The Maw at Full Resonance; `--tier=<id>` sets a command-line deploy's difficulty; the Sweep Drill stays a debug mission.

### Player and presentation
- XR origin with tracked hands, grip-gated strike spheres, haptics.
- ERM gauntlet armor with color-coded bracers.
- Bracer wrist panel: operation, timer, life force bar, rift hexes, score, multiplier, Chen caption.
- Breach-site arena: hex floor with rift-driven corruption veins, pylons, procedural dead city and rubble, sky crack.
- Dr. Chen comms: 49 events in `Assets/Audio/VO/chen/chen_lines.json`, one to eight takes each, 184 clips voiced with ElevenLabs (`elevenlabs_manifest.json` tracks what was generated). Pacing by per-event cooldown and a script-wide max wait; priority 3 lines play as soon as she is free; stale lines are dropped. Opening line varies by history (first, retry after failsafe, replay); victory line varies by outcome (flawless, at critical, new record, plain). No timer callouts; missions have no time limit.
- Music manager with six tracks and an intensity controller driven by pressure and life state. Own-music switch mutes the Music bus and stops the manager.
- Radio treatment on the Voice bus; music ducks under Chen.

### Flow and platform
- World-space holographic menu with dual lasers and trigger-release selection: main (Deploy shows the next mission, its time, and the difficulty), Operations (difficulty row and six contracts), Training (six modules), Settings (Play My Own Music, music volume when applicable, effects, haptics, reduced flashes, reset progress), pause, abort confirm, reset confirm, XR suspended, results with Next Operation.
- Persistent settings, difficulty, cleared missions, the Maw break counters, and best scores and times per mission and difficulty in `user://phantom_fray_settings.cfg`. Standard records keep the bare mission id, so records from before difficulties stay put.
- XR focus-loss suspension, debug performance monitor.
- Validation runner covering resources, SFX takes, variant rules, life force, strike window, mission catalog, elapsed timer and best time, difficulty tiers (Standard unchanged, each tier on a spawned phantom, its rift, and the life force, sweep spacing, persistence and per-tier records, only Full Resonance reaching the boss turn), menu surfaces, results menu, own-music settings view, rift stragglers, pink dodge, squat, push-up, and jump detection, the resonance sweep, and The Maw's break odds, boss fight, and glimpse. GitHub Actions on Godot 4.7.1.
- Desktop art, play, and menu capture scenes writing stills to `reports/`.
- Quest debug and release build scripts, Android template installer, export presets.
- Voice tooling: `tools/generate_elevenlabs_vo.ps1` (find voices, audition reels, generate changed lines) and `tools/check_vo.ps1` (speech-to-text comparison against the script).

## Build artifacts

The signed debug and release APKs recorded in [Meta_VRC_Evidence.md](Meta_VRC_Evidence.md) were built before the October content. Rebuild and re-sign before any distribution.

## Playtesting

Headset playtesting has happened throughout, on Quest 3, but was not recorded. Standing verdicts are in the roadmap. Future sessions go in [Playtest_Log.md](Playtest_Log.md).

## Not done

- Best scores are stored but not shown on Operations or results.
- No medals, session stats, endless mode, leaderboards, or war map. These are the Phase 6 and 7 work. Difficulty is picked in the menus until the war map exists.
- One arena for all six operations, still labeled as a training chamber.
- Final audio mix, key art, trailer, store copy, and Meta dashboard work.
