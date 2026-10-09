# Life Force System

Player vitality and the stakes of a possession. Updated 2026-10-08 to match `Scripts/Player/life_force_manager.gd` and `Scripts/Player/life_force_feedback.gd`.

## Numbers in the code

| Property | Value |
|---|---|
| Maximum | 100 |
| Drain per possession | 20 (every phantom; `contact_damage`) |
| Recovery | 1 per second after 3 clear seconds |
| Healthy | above 70% |
| Caution | 40% to 70% |
| Danger | 10% to 40% |
| Critical | 10% and below |
| Depleted | 0, ends the operation |

Five possessions without recovery end a run. Recovery resets on every hit. Damage is ignored once depleted so the fail state fires once.

The original design had tiered drain (basic 5, elite 10, boss 20). The code settled on a flat 20 because the campaign's pressure comes from the number of phantoms, and a possession needs to hurt enough to matter. Tiers return if elite or boss phantoms arrive.

## Signals

- `life_force_changed(current, maximum)`
- `life_force_state_changed(state)` with `healthy`, `caution`, `danger`, `critical`, `depleted`
- `life_force_depleted`
- `damage_applied(amount, current)`

The manager owns the numbers only. Presentation listens.

## Feedback that ships

### Visual
- **Bracer panel bar.** Life force readout and bar on the left wrist.
- **Frost and veins.** A camera overlay that closes in from the edges as state worsens, glowing veins over frost.
- **Camera tint.** Danger tint by state.
- **Possession hit.** A screen distortion pulse and an impact slam on `damage_applied`, plus a flash of the possession color.

### Audio
- **Heartbeat.** Procedural loop on the Critical bus. Silent when healthy, quiet in caution, clear in danger, fast and loud in critical.
- **Drain blip** on each hit and a **depletion stinger** at zero.
- **Siphon sound** from the phantom on possession, with takes from `Assets/Audio/SFX/` or a procedural fallback.
- **Music** drops to its low-life level in danger and critical.
- **Chen** calls caution, danger, and critical as the state falls, and a possession line on each hit.

### Haptics
- Possession rumble on both controllers.

## Debug
- `H` applies a hit, `R` resets, in debug builds only.

## Planned

- Reduced Flashes should cap the tint and distortion harder; confirm strength on headset.
- Directional damage indicator if testers lose track of where the possession came from.
- Elite and boss drain tiers when those phantoms exist.
- Life force restore power-up from the original design.
- Session stats will count possessions and recoveries for the after-action report.
