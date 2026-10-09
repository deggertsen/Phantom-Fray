# Phantom Enemy System

How phantoms work in the code today, and what is still planned. Updated 2026-10-08.

## Species and rules

| Color | Species | Script | Rule | Base score | Rift damage |
|---|---|---|---|---|---|
| Yellow | Angler | `yellow_phantom.gd` on `resonance_phantom.gd` | Left hand. Lure is the crit. | 100 (crit 220) | 10 (crit 20) |
| Blue | Angler | `blue_phantom.gd` on `resonance_phantom.gd` | Right hand. Lure is the crit. | 100 (crit 220) | 10 (crit 20) |
| Green | Carapace | `green_phantom.gd` | Both hands inside 0.55 s. First hand is a catch. | 180 | 16 |
| Pink | Spearfin | `pink_phantom.gd` | Cannot be punched. Leave its lane. | 200 | 18 |
| none | Drifter | `phantom.gd` base | Any hand. Not in any wave pool today. | 100 | 10 |

A valid strike during the phantom's commit phase is "on beat": score times 1.25, rift damage times 1.15. Because strikes only count in reach, nearly every valid hit is on beat. Pink's dodge is always on beat.

Every phantom that reaches the player drains 20 life force (`contact_damage`).

## Body forms

`Scripts/Presentation/creature_mesh.gd` builds each species as one mesh, shared by every phantom of that shape and prewarmed during the menu.

- Angler: Lantern (round), Gulper (long jaw, whip tail), Thornback (squat, spined). The lure stalk is built to reach wherever the sweet spot sits.
- Carapace: Crab, Horseshoe (dome shell, tail spike), Mantis (upright, raptor arms). Two crystal claws say "both hands".
- Spearfin: Needle, Sailfish (huge sail, long bill), Ribbon (long eel, frilled fin). The bill says "charge".
- Drifter: jellyfish trailing tentacles.

A phantom picks a form at random unless `creature_form` is set. Materials come from `Resources/Materials/creature.tres` with per-species sway, flap, and snap parameters.

## Movement: one arc into reach

`Scripts/Phantoms/phantom.gd`

1. **Approach.** On spawn the phantom locks a target just under the player's eyes (18 to 30 cm below the camera) and builds a cubic bezier from its position to that point. The bow is sideways: yellow bows left, blue bows right, green stays near center. Speed ramps from `move_speed` toward `pattern_commit_speed` along the curve. There is no stop-then-dash.
2. **Commit.** Within `strike_reach` (1.7 m) the phase is COMMIT, the body shows its alert glow, and a punch counts. This is also when it homes on the head.
3. **Possession.** If the phantom core passes within `possession_radius` (0.30 m) of the head, the lunge target point, or the body node, it possesses the player: it dissolves, plays the siphon, and emits `player_contact`.
4. **Recover.** If it passes through without possessing, it retreats for `recover_seconds` and builds a new arc. A phantom that stalls twice or lives past 22 s cleans itself up.

Strikes outside the window buzz the hand and return `not_open`. Wrong-hand strikes return `wrong_hand`, emit `strike_rejected`, and break the chain.

### Angler specifics
The lure (`SweetSpotVisual`) sits in one of three places relative to the face that travels toward the player: hook (out on the punching side), uppercut (under the chin), or jab (in front of the mouth). A strike within `sweet_spot_radius` (0.32 m) of the lure is the crit. The lure flashes white on a crit, the species color on a plain hit, red on a wrong hand.

### Carapace specifics
Approaches lower and faster, widens its body in the commit phase. The first hand to touch it starts a 0.55 s window and returns `block_half`; the other hand inside that window completes the block. The same hand again, or a late second hand, restarts the window.

### Spearfin specifics
Does not use the arc. It telegraphs for `telegraph_seconds` (1.15 s) while a chevron lane shader draws on the floor from the fish to the player and a little past. The aim starts bowed to one side and straightens as the telegraph completes, then it charges at `charge_speed` (7 m/s). Passing its locked target without possessing resolves it as a dodge.

## Pressure

`apply_pressure(speed_scale, telegraph_scale)` is called per spawn from the rift's wave entry. Speed multiplies `move_speed`, `pattern_commit_speed`, and pink's `charge_speed`. The telegraph scale divides acceleration (a longer tell is a gentler ramp) and scales the telegraph time with a floor of 0.35 s (0.45 s for pink).

## Spawning

`Scripts/Rifts/rift_manager.gd` spawns on a timer from its wave's `pool`, up to `max_live` live phantoms, offset in front of the portal. `Scripts/Rifts/rift_spawn_manager.gd` (the RiftDirector) decides how many rifts are open, where they sit, and when the next one replaces a sealed one. Wave fields: `health`, `interval`, `max_live`, `speed_scale`, `telegraph_scale`, `pool`, `scale`.

Sealing a rift stops its spawning and dissolves the portal, but phantoms already out keep their course and still score or possess. The rift emits `drained` once they are gone, the director emits `all_clear` once every rift is sealed and drained, and only then does the round end in victory. Phantoms dissolving from a stall or round cleanup no longer count as live.

## Feedback

- `feedback_requested(kind, position, intensity)` drives `Scripts/Presentation/combat_vfx.gd`: hit, sweet, guard, rejected.
- Hand haptics in `Scripts/Player/hand_collision.gd`: normal, crit or on-beat, half block, rejected.
- Death and possession sounds pick from takes in `Assets/Audio/SFX/` via `sfx_variations.gd`.
- Chen calls the first sighting of each species once per session, and wrong-hand corrections on a cooldown.

## Planned

- Low approaches that ask for uppercuts and squats. Everything currently aims at head height.
- A finale behavior for The Maw and an Overseer presence.
- Intelligence targets from the lore: relay phantoms, captures.
- Further species ideas kept from the original design: a shield phantom needing a punch sequence, phantoms that drain from range, projectile phantoms to punch away.
- The Drifter is built but unused. It could seed a mixed "any hand" wave for warmups or the endless hold.
