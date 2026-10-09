# Known Issues and Open Questions

Updated 2026-10-09.

## Content and design gaps

1. **Thin replay loop.** Best scores and fastest victory times are stored per operation. Results show the completion time and call a new best time, and the Operations list shows the best time beside each expected range. The best score is not shown anywhere yet. There are no medals, session stats, endless mode, or leaderboards. A full campaign run is about 20 minutes with little reason to return. Phase 6 in the roadmap.
2. **No narrative hook.** Six operations with debrief lines, but nothing larger at stake and no payoff for the Overseer thread. The Maw differs from other rifts only in size and spawn rate. Phase 7.
3. **One arena.** Every operation is the same dead-city breach site, and the briefing panel still reads "RSF // ERM TRAINING CHAMBER 07" (`Scripts/Presentation/arena_builder.gd`). Phase 8.
4. **OP-04 and OP-05 share one wave table.** Only rift placement differs (`_paired_assault_waves` in `Scripts/Core/mission_catalog.gd`).
5. **Every phantom aims at head height.** Targets land 18 to 30 cm below the eyes. No low approaches, so squats and uppercuts come only from the Angler's lure position.
6. **Expected mission times are estimates.** Each operation's `expected_minutes` pair in `Scripts/Core/mission_catalog.gd` comes from the wave tables (rift health over roughly 13 rift damage per kill, times the spawn interval, plus misses and rift openings), not from timed play. Time real runs on the headset and replace them, and again after the five-to-ten-minute retune from OP-02 on.

## Audio

- Chen's clips are generated; listen through once in headset and run `tools/check_vo.ps1` after any script change. Any clip the check flags gets regenerated with `-Only <event>`.
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
