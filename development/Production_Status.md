# Production Status — 2026-10-13

## Implemented on `main`

### Combat
- Phantom base: one continuous accelerating bezier arc into reach, lunge at the head, homing on the live head close in, an immediate turn back after a miss, recover and re-approach. Strikes count once in reach. Stall and lifetime cleanup.
- Angler (yellow left, blue right): lure as the resonance crit in hook, uppercut, or jab position. Wrong hand rejects and breaks the chain.
- Carapace (green): first hand is a catch, second hand inside 0.55 s is the block.
- Spearfin (pink): telegraph, floor lane shader, charge; resolved by leaving the lane. Cannot be punched.
- Three body forms per species, built as one mesh each and prewarmed with the combat shaders while the menu is up.
- Pressure scaling per wave: speed and telegraph scales applied to every phantom, and the difficulty's contact scale to every contact.
- Possession: head or body within 0.30 m of the phantom core. Drains 20 life force, plays the siphon sound, frost and veins, distortion and impact slam.
- Strike VFX: sparks, shockwave, flash. Haptic tiers for normal, crit, guard, and rejected.
- Punch power: a valid strike's rift damage scales from 0.85x at 2 m/s or slower to 1.3x at 6 m/s or faster (`Phantom.strike_power`). Score is unchanged; the rift's damage flash and the hand haptic scale with it. A soft lure hit still beats the hardest plain hit.
- Training hold: `Phantom.hold_in_reach` pauses a phantom in punching reach in its commit phase, unable to possess, until a valid strike resolves it or `release_hold` sends it in; `SpearfinPhantom.hold_at_lane_lock` pauses a pink as its lane locks.

### Rifts and missions
- Six operations in `Scripts/Core/mission_catalog.gd` with per-rift wave tables, pressure labels, open barks, seal lines, mop-up line, and debriefs.
- Rift director: single, clustered pair, or front-arc placement; up to two concurrent rifts; staggered first spawns.
- Rift manager: health, damage flash scaled by punch power, health shader, beacon column with floor ring and label, orbiting debris, scale for The Maw, dissolve on seal.
- Stragglers: a sealed rift stops spawning but its phantoms stay in play and still score or hurt. The rift reports `drained` when they are gone; the director reports `all_clear` when every rift is sealed and drained, and only then is the operation won. Status reads "SEALED • CLEAR PHANTOMS" meanwhile. Scene teardown is never read as a clear.
- Rift compass chevron at the edge of view and phantom bearing markers.
- Round controller: pre-round countdown, elapsed mission clock (counts up, holds on pause, never ends the round), chain multiplier to 3x with crit and on-beat gains, victory, defeat, pause and resume. It applies the chosen difficulty to a copy of the mission before any rift opens. Victory records the completion time as the best time for that operation and difficulty when it is faster.

### Difficulty and the movement tier
- Four difficulties in `Scripts/Core/difficulty_tier.gd`: Assist, Standard, Operator, Full Resonance. Each multiplies a wave's speed, tells, rift health, and spawn interval, and scales contact damage; Standard is the catalog exactly. Chosen beside Deploy on the city map (four buttons), saved in `GameSettings.difficulty_tier`, default Standard, Full Resonance open from the start. Deploy, the site panel, and results show it. Best score and time are kept per mission and difficulty.
- Full Resonance: rift health x1.1, and Chen says a Full Resonance line in the countdown. Ordinary rifts send no sweeps; the boss carries the movements. The Maw (OP-06) carries its boss there and only there: the break odds (`MawBoss.decide_break`), the false seal and turn, then high sweeps to squat, low sweeps to jump, slams to side-step, push-ups on the spent tentacle (`PushUpDetector`, head height), and escort volleys, until the anchor runs out and it retreats. Every other difficulty keeps the seal and the occasional tentacle glimpse.
- Squat detector (`SquatDetector`, every build) with the bend check; push-up detector; jump tracking for the low sweep. Debug builds: B (Shift+B forces a break) or `--mission=the_maw_boss` deploys The Maw at Full Resonance; `--tier=<id>` sets a command-line deploy's difficulty; the Sweep Drill stays a debug mission.

### Player and presentation
- XR origin with tracked hands, grip-gated strike spheres, haptics.
- ERM gauntlet armor with color-coded bracers.
- Bracer wrist panel: operation, timer, life force bar, rift hexes, score, multiplier, Chen caption.
- Breach-site arena: hex floor with rift-driven corruption veins, pylons, procedural dead city and rubble, night sky.
- Dr. Chen comms: 108 events in `Assets/Audio/VO/chen/chen_lines.json` (49 for operations, 59 for training), one to eight takes each, 254 clips voiced with ElevenLabs (`elevenlabs_manifest.json` tracks what was generated). Pacing by per-event cooldown and a script-wide max wait; priority 3 lines play as soon as she is free; stale lines are dropped. Opening line varies by history (first, retry after failsafe, replay); victory line varies by outcome (flawless, at critical, new record, plain). No timer callouts; missions have no time limit. Training's 59 `tutorial_` lines (she calls the player Recruit there, and Striker from the first operation on) play back to back under a prefix lock (`lock_prefix`), and her pause holds a line mid-word while training is paused. The wrist caption pages a line too long for its two rows, in step with her voice.
- Music manager with six tracks and an intensity controller driven by pressure and life state. Own-music switch mutes the Music bus and stops the manager.
- Radio treatment on the Voice bus; music ducks under Chen.

### Flow and platform
- World-space holographic menu with dual lasers and trigger-release selection: main (Deploy shows the next mission, its time, and the difficulty), Operations (difficulty row and six contracts), Training (Chen's training chamber; see below), Training Complete, Settings (Play My Own Music, music volume when applicable, effects, haptics, reduced flashes, reset progress), pause, abort confirm, reset confirm, XR suspended, results with Next Operation, and Review Training after a failed operation. A new profile leads with Training.
- Training chamber (`Scripts/Core/tutorial_director.gd`, `Scripts/Presentation/training_chamber.gd`): thirteen scripted beats on the real round, rift, and life force systems, under a holographic dome with the RSF chamber sign. Chen introduces herself, pauses each phantom's hologram in reach to teach it (yellow, blue, the chain, green, pink at lane lock), lets one possession through and has the recruit look at their left glove to find their life force, shows the rift's health, demonstrates punch power with damage readouts, runs a live wave that ends on a straggler, and signs off into Training Complete. Training cannot fail (life floor 20) and records no clear, score, or time. Ending it from pause counts it as done. Plan and line drafts in [Tutorial_Plan.md](Tutorial_Plan.md).
- Persistent settings, difficulty, cleared missions, the Maw break counters, and best scores and times per mission and difficulty in `user://phantom_fury_settings.cfg`. Standard records keep the bare mission id, so records from before difficulties stay put.
- XR focus-loss suspension, debug performance monitor.
- Validation runner covering resources, SFX takes, variant rules, life force, strike window, mission catalog, elapsed timer and best time, difficulty tiers (Standard unchanged, each tier on a spawned phantom, its rift, and the life force, no sweeps in ordinary rifts, persistence and per-tier records, only Full Resonance reaching the boss turn), menu surfaces (Training Complete, training pause, settings), the city map and results wrap panels (new recruit, sites, difficulties, the front moving, Review Training, everything fitting), the front line at every sealed count, the presenter aiming at wrap panels in 3D, own-music settings view, rift stragglers, pink dodge, squat, push-up, and jump detection, the resonance sweep, and The Maw's break odds, boss fight, and glimpse, the training hold, punch power, and a full training run. GitHub Actions on Godot 4.7.1.
- Desktop art, play, and menu capture scenes writing stills to `reports/`. The play capture runs the whole training chamber with a stand-in recruit (`-- --tutorial`).
- Quest debug and release build scripts, Android template installer, export presets.
- Voice tooling: `tools/generate_elevenlabs_vo.ps1` (find voices, audition reels, generate changed lines) and `tools/check_vo.ps1` (speech-to-text comparison against the script).

## Build artifacts

The signed debug and release APKs recorded in [Meta_VRC_Evidence.md](Meta_VRC_Evidence.md) were built before the October content. Rebuild and re-sign before any distribution.

## Playtesting

Headset playtesting has happened throughout, on Quest 3, but was not recorded. Standing verdicts are in the roadmap. Future sessions go in [Playtest_Log.md](Playtest_Log.md).

## Not done

- Best scores are stored but not shown on Operations or results.
- No medals, session stats, endless mode, leaderboards, or war map. These are the Phase 6 and 7 work. Difficulty is picked in the menus until the war map exists.
- One arena for all six operations. The "TRAINING CHAMBER 07" sign now shows only in training.
- Final audio mix, key art, trailer, store copy, and Meta dashboard work.
