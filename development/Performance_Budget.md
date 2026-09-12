# Quest Performance Budget

## Launch targets

| Metric | Minimum gate | Preferred target |
|---|---:|---:|
| Refresh rate | 72 Hz | 90 Hz on Quest 3/3S |
| Frame budget | 13.9 ms | 11.1 ms |
| Missed frames | <1% over 5 minutes | <0.25% |
| Active rifts | 1 | 1 |
| Active phantoms | 4 | 4 |
| Real-time shadow lights | 0 | 0 |
| Simultaneous dissolve VFX | 4 | 4 |

## Content budgets

- Prefer opaque or cutout materials; transparent portals and resonance markers are the exceptions.
- Avoid per-phantom raycasts and allocations during steady-state combat.
- Keep particle systems short-lived and below 40 particles per effect.
- Use low-poly XR Tools hands plus lightweight ERM overlays.
- Keep music and SFX on explicit buses and cap simultaneous one-shot voices during stress tests.
- No runtime video texture is used for the rift.

## Test scenario

Run a five-minute mission containing the full Yellow/Blue/Green/Pink mix, four live phantoms, repeated rift damage flashes, maximum combo feedback, low-life heartbeat, and three retries. Record:

- CPU and GPU frame time
- FPS distribution
- missed/reprojected frames
- draw calls and primitives
- node count before and after retries
- memory before and after retries
- audio voice count
- thermal throttling symptoms

The built-in `PerformanceMonitor` warns below 68 FPS in debug builds. Device profiling remains the source of truth.
