# Phantom Fray — Production Roadmap

**Last updated:** 2026-10-09
**Current stage:** Combat system complete and fun in headset. Chen fully voiced. Six-operation campaign plays as an extended tutorial. Replay value and narrative hooks are the gap before launch.
**Engine:** Godot 4.7.1 + OpenXR / godot-xr-tools 4.5.1
**Target:** Meta Quest-class standalone headset
**Positioning:** Gamified fitness. Supernatural-class workout intensity with a save-the-world story that gives the sweat a purpose. Standing play only.

Ideas that are not scheduled live in [Ideas_Backlog.md](Ideas_Backlog.md).

---

## What the game is today

`Main Menu → Training or Deploy → one of six operations (no time limit; the clock counts up) → After-action report → Next operation / Retry`

- Stationary, physical play: punch, two-hand block, side-step or duck. No artificial locomotion.
- Four phantom rules on three creature species with three body forms each: Angler (yellow left, blue right, lure is the crit), Carapace (green, two-hand block), Spearfin (pink, floor lane, dodge).
- Phantoms arrive on one continuous accelerating arc and lunge for the head. A strike counts once the body is in reach.
- Rifts have health, a damage flash, a beacon column, and a dissolve on seal. Up to two can be open at once. The Maw is a double-size rift that opens twice. Every operation runs twice the rifts it did before 2026-10-09 (4, 12, 12, 16, 16, 2). A sealed rift's phantoms stay in play; the operation is won when the last one is dealt with.
- Life force: 100, minus 20 per possession, plus 1 per second after 3 clear seconds. Frost and veins close in, vision distorts on a hit, heartbeat and music duck by state. At zero the gauntlets' failsafe fires and the recovery team pulls the operator out. Operators never die.
- Score with a chain multiplier up to 3x. Crit, on-arrival and dodge bonuses. Best score and fastest victory per operation are stored; results show the completion time and call a new best time. Each Operations card shows an expected time range and the best time beside it.
- Dr. Chen on comms: 33 moments, 4 to 5 takes each, voiced with ElevenLabs. Cooldown and max-wait pacing so she never cuts herself off. Opening line knows if this is a first attempt, a retry after the failsafe, or a replay; victory line knows if it was flawless, at critical, or a new best.
- Play My Own Music: a settings switch silences the soundtrack so any music app plays through.
- Breach-site arena: hex floor with corruption veins that follow open rifts, RSF pylons, dead-city skyline, rubble, sky crack.
- Bracer wrist panel: operation, elapsed time, life force, rift hexes, score, multiplier, Chen caption.
- World-space menu with dual lasers: main (next mission with its expected time), Operations (six contracts with lock state, expected time, and best time), six-page Training, Settings (own music, music, effects, haptics, reduced flashes, reset progress), pause, abort confirm, XR-suspended, results with Next Operation.
- Mission progress, best scores, best times, and settings persist. Validation runner and GitHub Actions cover resources, rules, catalog, menus, own-music settings, rift stragglers, and the pink dodge.
- Quest debug and release build scripts, signed-package evidence, export guide, ElevenLabs generation and transcription check for Chen's lines.

See [Production_Status.md](Production_Status.md) for the implemented list and [Known_Issues.md](Known_Issues.md) for what is open.

---

## Playtest verdicts so far

Headset sessions through 2026-10-08 were not written down. Record future ones in [Playtest_Log.md](Playtest_Log.md). The standing verdicts:

- The combat feels good. Direction of the code is right.
- A full run of all six operations takes about 40 minutes and there is no reason to return.
- The campaign reads as a tutorial for a game that does not exist yet.
- There is no narrative hook. Chen's lines carry flavor, but nothing is at stake beyond the current rift.

---

## Phases 0 to 5 — Done

Everything the earlier roadmap called the launch candidate is implemented and has been played in headset. Kept here as a record.

- Phase 0 Reorientation: Godot 4.7.1, desktop fallback, scope freeze, audit.
- Phase 1 Vertical slice: life force, fail state, finite round, HUD, yellow rule, rift honesty.
- Phase 2 Combat depth: blue, green, pink, haptic tiers, chain multiplier, wave pools, pressure scaling.
- Phase 3 Presentation: creature species and forms, ERM gauntlet armor, breach city, strike VFX, frost and veins, audio buses and pressure.
- Phase 4 Meta and UX: menu, operations, training, pause, settings, results, Chen comms voiced with ElevenLabs, own-music switch.
- Phase 5 Platform: compatibility renderer, buses, XR suspend, performance monitor, validation, CI, Quest export, signed package.

Still open from those phases:

- [ ] Final impact, UI, and proximity mix on headset speakers, with Chen in the mix.
- [ ] Rebuild and re-sign the release APK from current `main`; the recorded artifact predates the October content.

---

## Phase 6 — Make it a workout you return to

Fitness is the product. The campaign is the on-ramp.

- [ ] Session stats on the after-action report: punches thrown, resolves by type, crits, longest chain, active minutes, calorie estimate.
- [x] Persist a best score per operation (`GameSettings.record_score`; Chen's "new record" victory line uses it).
- [ ] Show the best score on Operations and on results, so a player can see that lures and chains pay.
- [ ] Medals per operation (bronze, silver, gold) from score thresholds that reward crits and unbroken chains.
- [ ] Endless "Hold the Breach" mode: cycle the existing wave tables with rising speed and shrinking telegraph scale until the failsafe fires. Length options 10, 20, 30 minutes.
- [x] Expected mission time on every mission card: an `expected_minutes` range per operation ("6 TO 8 MIN") with the player's best time beside it once they have one. The ranges are estimates from the wave tables; replace them from timed headset runs.
- [ ] Workout-length framing in the menu: a quick 10-minute hold, a 20-minute operation set, a 30-minute campaign.
- [ ] Meta fitness tracking tag for the store listing and Horizon OS Move integration if the SDK exposes it.
- [ ] Difficulty tiers: Assist, Standard, Operator. Implemented as multipliers on the wave fields `speed_scale`, `telegraph_scale`, rift health, and contact damage.

## Phase 7 — Narrative hooks and the war

Give the sweat a purpose. The Overseer is winning unless operators show up.

- [ ] Campaign restructure: the current six operations become the RSF onboarding arc. Each clear is also a story beat with a Chen debrief that reveals one thing about the Overseer.
- [ ] War map: a world map of breach sites with a front line. Sealing rifts in an operation pushes the line. Early version is local-only; later versions aggregate across players, in the spirit of Helldivers 2's galactic war.
- [ ] Daily and weekly breach: a seeded operation on the map everyone fights that day.
- [ ] Leaderboards per operation and for the endless hold.
- [ ] A real finale for The Maw: distinct behavior rather than only faster spawns, and an Overseer presence.
- [ ] Intelligence operations from the lore: target a relay phantom, capture a signal, hold a position while Chen's team works.

## Phase 8 — Location variety

- [ ] Breach-site presets per operation: sky color and crack, pylon state, city density and height, floor palette, rubble. All of it is already procedural.
- [ ] Remove the training-chamber briefing text from the dead-city arena, or make the first operation a chamber and move the rest outside.
- [ ] Two or three distinct sites for the map: dead city, coastal breach, mountain relay, and a training chamber.

## Phase 9 — Comfort and feel

- [ ] Validate the strike-window rule with testers: punches only count once the phantom is within `strike_reach` or in its commit phase. The developer has not felt this as a problem. Confirm with players who have not been told the rule before changing anything.
- [ ] Cap the full-screen damage tint and distortion in headset, and make Reduced Flashes cap them harder.
- [ ] Phantom approach heights: currently every phantom aims just below the eyes. Add lower approaches that ask for uppercuts and squats.

## Phase 10 — Launch

- [ ] Rewrite the store copy for the fitness-combat position and the current campaign ([Store_Asset_Plan.md](Store_Asset_Plan.md)).
- [ ] Key art, icon, trailer captured from a release build on headset.
- [ ] Complete the Meta Quest VRC test plan against the exact signed release build.
- [ ] Soft launch: a free first operation or an early-access listing to gather reviews before 1.0.
- [ ] Release v1.0.0, hotfix window, turn feedback into the 1.1 backlog.

---

## Definition of Production Ready

A release build is ready when:

1. A first-time player can learn and complete the first two operations without developer narration.
2. Victory, defeat, pause, resume, results, next operation and retry are reliable.
3. All four phantom rules are readable and physically comfortable at every difficulty tier.
4. A player who finishes the campaign has a reason to come back tomorrow: a best score to beat, a hold to survive, or a front line to push.
5. The maximum-load operation meets the documented frame budget on the minimum headset.
6. Three retries and a thirty-minute hold do not leak gameplay nodes, timers, or audio voices.
7. The signed package installs and launches cleanly on a factory-clean Quest profile.
8. The exact release build passes Meta's current VRC test plan.
9. Known issues contain non-blockers only.

---

## Production References

- [Production status](Production_Status.md)
- [Known issues](Known_Issues.md)
- [Ideas backlog](Ideas_Backlog.md)
- [Playtest log](Playtest_Log.md)
- [Quest export guide](Quest_Export_Guide.md)
- [Performance budget](Performance_Budget.md)
- [Release checklist](Release_Checklist.md)
- [Store asset plan](Store_Asset_Plan.md)
- [Life force design](Life_Force_System.md)
- [Phantom enemy design](Phantom_Enemy_Breakdown.md)
- [Chen voice script](Chen_VO_Script.md)
