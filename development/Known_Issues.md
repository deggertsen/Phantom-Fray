# Known Issues and Open Questions

Updated 2026-10-13.

## Content and design gaps

1. **Thin replay loop.** Best scores and fastest victory times are stored per operation and difficulty. Results show the completion time and call a new best time, and the Operations list shows the best time beside each expected range. The best score is not shown anywhere yet. There are no medals, session stats, endless mode, or leaderboards. A full campaign run is about 40 minutes with little reason to return. Phase 6 in the roadmap.
2. **No narrative hook.** Six operations with debrief lines, but nothing larger at stake and no payoff for the Overseer thread. The Maw's boss fight is reached at Full Resonance; at other difficulties The Maw differs from other rifts only in size and spawn rate, with the occasional tentacle glimpse. Phase 7.
3. **One arena.** Every operation is the same dead-city breach site. The "RSF // ERM TRAINING CHAMBER 07" sign (`Scripts/Presentation/arena_builder.gd`) now shows only while training runs, under the chamber dome. Phase 8.
4. **OP-04 and OP-05 share one wave table.** Only rift placement differs (`_paired_assault_waves` in `Scripts/Core/mission_catalog.gd`).
5. **Every phantom aims at head height.** Targets land 18 to 30 cm below the eyes. No low approaches, so below Full Resonance squats and uppercuts come only from the Angler's lure position; at Full Resonance The Maw's boss asks for them.
6. **Expected mission times are estimates.** Each operation's `expected_minutes` pair in `Scripts/Core/mission_catalog.gd` comes from the wave tables (rift health over roughly 13 rift damage per kill, times the spawn interval, plus misses and rift openings), not from timed play. Mission lengths doubled on 2026-10-09 (twice the rifts, and twice the health on The Maw's single rift) and the ranges doubled with them. Punch power (2026-10-13) moves rift damage between 0.85x and 1.3x of the old values, so a hard puncher seals up to about 15 percent faster and a soft one slower; the ranges predate it. Time real runs on the headset and replace them.
7. **Difficulty numbers are first guesses.** `Scripts/Core/difficulty_tier.gd`: Assist is 0.85 speed, 1.25 tells, 0.8 rift health, 1.15 spawn interval, 0.6 contact; Operator 1.12, 0.85, 1.15, 0.9, 1.25; Full Resonance 1.0, 1.0, 1.1, 1.0, 1.0. None has been played on a headset. The Operations cards show the same time ranges at every difficulty except The Maw at Full Resonance (4 to 7 minutes); Assist and Operator should land within a few percent of Standard (health and spawn rate offset each other), Full Resonance about a tenth longer. Time runs at each tier and retune.
8. **The sweep's bend check runs at every difficulty.** Below Full Resonance a sweep is duck-depth only (`squat_depth` capped at 0.12), where the exploration doc says a bend should clear with the bonus; `ResonanceSweep` still withholds the bonus for a bend whenever the squat detector is calibrated. Only the debug Sweep Drill has sweeps below Full Resonance today, so nothing in the campaign hits it. Decide before Standard maps get duck sweeps (decision 2).
9. **Full Resonance on the tutorial operations.** The exploration doc keeps the six operations at Standard with no detected movement; until the war map exists they are the only missions, so Full Resonance applies to them too: a tenth more rift health on OP-01 to OP-05, and the boss at The Maw. Outside The Maw it asks nothing extra of the body. Squat-depth sweeps in every rift were tried and removed the same day (2026-10-13): nothing in the fiction swings a blade from an ordinary rift, and "bosses carry the movements" stands. If Full Resonance needs movement outside bosses before the war map, the candidate with a source is a short tentacle lash from the rift (the boss tentacle driving a sweep), which would foreshadow the bosses. Hand tracking is not required at Full Resonance yet: push-ups count from head height with controllers. A Full Resonance Maw that holds seals without the glimpse.
10. **Training has had one headset session.** On 2026-10-17 the developer played it through once and was happy with it apart from timing: Chen's instructions came after the recruit could act. They now play while the phantom flies in (Playtest_Log.md); not yet re-checked. Still to feel on Quest: whether 0.95 m is the right distance for a paused Angler's lure to sit inside a jab, the glove check, where the floating cards and tags sit against the paused phantom, whether the punch power band (2 to 6 m/s) matches real controller speeds so a tap and a hard hit really land at each end, and how training reads at Full Resonance (it always runs at Standard). See [Tutorial_Plan.md](Tutorial_Plan.md).

## Audio

- Chen's clips are generated; listen through once in headset and run `tools/check_vo.ps1` after any script change. Any clip the check flags gets regenerated with `-Only <event>`.
- Training's 59 `tutorial_` events (70 clips) and the 12 lines that changed "operator" to "Striker" were voiced on 2026-10-13 and pass `check_vo.ps1`. Not yet heard in headset; listen to the introduction especially, the one long speech.
- Missions have no time limit and no timeout outcome, so Chen has no clock lines. If completion time later feeds medals or a race mode, decide whether she should call a pace.
- Impact, UI, and proximity audio have not had a final mix on headset speakers.

## Comfort and feel to validate

- **Strike window.** A punch only counts once the phantom is within `strike_reach` (1.7 m) or in its commit phase; earlier hits buzz and are rejected (`Scripts/Phantoms/phantom.gd`). The developer has not felt this as a problem in headset. Validate with testers who have not been told the rule before deciding whether early hits should become a reduced-score deflect.
- **Damage tint.** The possession tint and distortion fill the whole view at full saturation in desktop captures. Confirm the strength in headset and make sure Reduced Flashes caps it.

## Technical follow-up

- Results pointer selection after defeat was unreliable on Quest 3. Fixes landed on 2026-10-03 and 2026-10-04 (pointer reset on results entry, trigger-release selection). Retest victory and defeat on headset and close this item.
- The recorded release APK predates the October content. Rebuild and re-sign from current `main` before distribution. Back up the release keystore and password off-machine first.
- Android export automation can be added to CI only after the export preset and build template versions are established on a trusted workstation.
- The validation runner now covers stragglers and the own-music view; round and rift integration fixtures for whole operations are still missing.
- `_validate_arc_motion` in `Tests/validation_runner.gd` is flaky: "Yellow arc stalled during approach" failed 2 of 5 headless runs on 2026-10-09 with no code change between runs. The arc is built from random side, bow, and control-point values, and 120 physics steps is not always enough for every curve to clear 1 m at 0.3 m/s. Seed the RNG in the test or lengthen the run.
- The project targets Compatibility rendering for standalone Quest reliability. Reassess Mobile/Vulkan only with device measurements on the pinned Godot release.

## External launch gates

- Meta developer account, VRC evidence, age rating, privacy declaration, store listing, and upload require authorized dashboard access.
- Key art, icon, trailer, and store copy for the fitness-combat position are not started.
