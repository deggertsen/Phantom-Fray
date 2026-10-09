# Quest Performance Budget

Updated 2026-10-08.

## Launch targets

| Metric | Minimum gate | Preferred target |
|---|---:|---:|
| Refresh rate | 72 Hz | 90 Hz on Quest 3/3S |
| Frame budget | 13.9 ms | 11.1 ms |
| Missed frames | <1% over 5 minutes | <0.25% |
| Concurrent rifts | 2 | 2 |
| Live phantoms | 4 (8 in The Maw) | 4 (8 in The Maw) |
| Real-time shadow lights | 0 | 0 |
| Simultaneous dissolve VFX | 4 | 4 |
| Simultaneous strike VFX | 4 | 4 |

Paired operations run two rifts at `max_live` 2 each. The Maw runs one rift at a time, twice in a row, at `max_live` 8 with a 0.875 s spawn interval and 800 health, so it is the phantom-count stress case and the only place eight phantoms are live at once. Double Breach is the rift and beacon stress case.

## Content budgets

- Every creature species and form is one `ArrayMesh`, shared across instances, built and shader-prewarmed while the menu is up (`CreatureMesh.prewarm`, `shader_warmup.gd`).
- The dead city and rubble are each one merged mesh and one draw call.
- Prefer opaque or cutout materials; transparent exceptions are the portal, glow sprites, beacon, debris, and the pink lane.
- No per-phantom raycasts or allocations during steady-state combat. Pink's lane is one quad with a shader.
- Particle systems are short-lived and below 40 particles per effect.
- Low-poly XR Tools hands plus the ERM gauntlet armor.
- Music, SFX, Voice, Critical, and UI stay on explicit buses. Cap simultaneous one-shot voices during stress tests. Chen plays one line at a time.
- No runtime video texture is used for the rift.

## Test scenarios

1. **OP-04 Double Breach**, two rifts open, both beacons, full color mix, maximum chain feedback, low-life frost and heartbeat, Chen talking. Five minutes.
2. **OP-06 The Maw**, eight live phantoms at double rift scale, repeated damage flashes. Play it to the seal.
3. **Thirty-minute soak** across Next Operation and Retry transitions, standing in for the planned endless hold.

Record for each:

- CPU and GPU frame time
- FPS distribution
- Missed and reprojected frames
- Draw calls and primitives
- Node count before and after each transition
- Memory before and after each transition
- Audio voice count
- Thermal throttling symptoms

The built-in `PerformanceMonitor` warns below 68 FPS in debug builds. Device profiling remains the source of truth. Log results in [Playtest_Log.md](Playtest_Log.md).
