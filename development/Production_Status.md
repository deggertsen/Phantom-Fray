# Production Status — 2026-10-08

## Implemented on `main`

### Combat
- Phantom base: one continuous accelerating bezier arc into reach, lunge at the head, recover and re-approach. Strikes count once in reach. Stall and lifetime cleanup.
- Angler (yellow left, blue right): lure as the resonance crit in hook, uppercut, or jab position. Wrong hand rejects and breaks the chain.
- Carapace (green): first hand is a catch, second hand inside 0.55 s is the block.
- Spearfin (pink): telegraph, floor lane shader, charge; resolved by leaving the lane. Cannot be punched.
- Three body forms per species, built as one mesh each and prewarmed with the combat shaders while the menu is up.
- Pressure scaling per wave: speed and telegraph scales applied to every phantom.
- Possession: head or body within 0.30 m of the phantom core. Drains 20 life force, plays the siphon sound, frost and veins, distortion and impact slam.
- Strike VFX: sparks, shockwave, flash. Haptic tiers for normal, crit, guard, and rejected.

### Rifts and missions
- Six operations in `Scripts/Core/mission_catalog.gd` with per-rift wave tables, pressure labels, open barks, seal lines, and debriefs.
- Rift director: single, clustered pair, or front-arc placement; up to two concurrent rifts; staggered first spawns.
- Rift manager: health, damage flash, health shader, beacon column with floor ring and label, orbiting debris, scale for The Maw, dissolve on seal.
- Rift compass chevron at the edge of view and phantom bearing markers.
- Round controller: countdown, timer, chain multiplier to 3x with crit and on-beat gains, victory, defeat, timeout, pause and resume.

### Player and presentation
- XR origin with tracked hands, grip-gated strike spheres, haptics.
- ERM gauntlet armor with color-coded bracers.
- Bracer wrist panel: operation, timer, life force bar, rift hexes, score, multiplier, Chen caption.
- Breach-site arena: hex floor with rift-driven corruption veins, pylons, procedural dead city and rubble, sky crack.
- Dr. Chen comms: 29 events in `Assets/Audio/VO/chen/chen_lines.json`, 4 to 5 takes each, priority and cooldown queue, radio treatment on the Voice bus, music ducking.
- Music manager with six tracks and an intensity controller driven by pressure and life state.

### Flow and platform
- World-space holographic menu with dual lasers and trigger-release selection: main, Operations, Training (six modules), Settings, pause, abort confirm, reset confirm, XR suspended, results with Next Operation.
- Persistent settings and cleared-mission progress in `user://phantom_fray_settings.cfg`.
- XR focus-loss suspension, debug performance monitor.
- Validation runner covering resources, SFX takes, variant rules, life force, strike window, mission catalog, menu surfaces, results menu, pink dodge. GitHub Actions on Godot 4.7.1.
- Desktop art and play capture scenes writing stills to `reports/`.
- Quest debug and release build scripts, Android template installer, export presets.

## Build artifacts

The signed debug and release APKs recorded in [Meta_VRC_Evidence.md](Meta_VRC_Evidence.md) were built before the October content (campaign, creatures, city, comms). Rebuild and re-sign before any distribution.

## Playtesting

Headset playtesting has happened throughout, on Quest 3, but was not recorded. Standing verdicts are in the roadmap. Future sessions go in [Playtest_Log.md](Playtest_Log.md).

## Not done

- Chen's takes are Windows text-to-speech placeholders. The ElevenLabs generator is ready and has not been run.
- No best scores, medals, session stats, endless mode, leaderboards, war map, or difficulty tiers. These are the Phase 6 and 7 work.
- One arena for all six operations, still labeled as a training chamber.
- Final audio mix, key art, trailer, store copy, and Meta dashboard work.
