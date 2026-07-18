# Next Step Breakdown — Life Force + Fail State

**Last updated:** 2026-07-18  
**Roadmap phase:** 1A (see [Production_Roadmap.md](Production_Roadmap.md))  
**Why this first:** Phantoms already emit `player_hit` and vanish on contact, but nothing listens. Without drain and game over, the Fray has no stakes — just a glowing punching bag dimension.

**Design source:** [Life_Force_System.md](Life_Force_System.md)  
**Scope for this step:** Vertical-slice life force — enough to feel danger and die. Full Iron Man HUD / aura art can wait for Phase 3.

---

## Goal

When a phantom touches the player:

1. Life force decreases  
2. The player sees and hears that they’re in trouble  
3. At 0, the round ends (game over)  
4. Life force can recover if the player stays clear for a short window  

**Exit criteria:** In a headset, take hits until death; recover from near-death by clearing phantoms; no console spam / soft-locks.

---

## Current Code Hooks (Use These)

| Existing piece | Relevance |
|----------------|-----------|
| `phantom.gd` → `player_hit` signal | Emit on body contact; **currently unconnected** |
| `xr_player.gd` / `Player` group | Natural home for life force owner or listener |
| `music_controller.gd` → `on_life_force_low()` | Stub ready for intensity hook (optional this pass) |
| Design drain numbers | Basic −5 / elite −10 / boss −20; max 100; recover +1/s after 3s clear |

For the slice, treat all current phantoms as **basic (−5)** until variants exist.

---

## Work Packages

### Package A — Life Force Manager (core data) ✅

**Intent:** One source of truth for vitality. Keep it dumb and signal-driven.

- [x] **A1.** Create `Scripts/Player/life_force_manager.gd` (or attach to player scene)
  - Properties: `max_life_force`, `current_life_force`, `drain_on_basic_hit`, `recovery_per_second`, `recovery_delay`
  - Defaults from design doc: 100 / −5 / +1/s / 3s delay
- [x] **A2.** API
  - `apply_damage(amount: float)`
  - `start_recovery_timer()` / tick recovery in `_process` or `_physics_process`
  - Reset helper for round restart: `reset()`
- [x] **A3.** Signals
  - `life_force_changed(current, max)`
  - `life_force_state_changed(state)` — healthy / caution / danger / critical (thresholds from design)
  - `life_force_depleted`
- [x] **A4.** Guardrails
  - Clamp 0…max
  - Ignore damage after depleted (prevent double game-over)
  - Reset recovery delay on every hit

**Done when:** Unit-testable in isolation (even via print/debug keys) without phantoms.

---

### Package B — Wire Phantom Contact → Damage ✅

**Intent:** Make the existing collision path matter.

- [x] **B1.** Phantom finds `LifeForceManager` via group on hit (works for late spawns)
- [x] **B2.** Call `apply_basic_hit()` / `apply_damage(drain_on_basic_hit)` on hit
- [x] **B3.** `_has_hit_player` guard + immediate collision disable in `disappear()`
- [x] **B4.** Debug keys: `H` damage, `R` reset (debug builds); wrist meter shows value

**Done when:** Touching a phantom reliably subtracts life force once per phantom.

---

### Package C — Game Over ✅

**Intent:** Depletion ends the round. Keep it brutal and simple.

- [x] **C1.** Listen for `life_force_depleted` (`Scripts/game_over_manager.gd`)
- [x] **C2.** Enter game-over state
  - Stop rift spawning (`RiftSpawnManager.stop_spawning`)
  - Stop per-rift phantom timers + freeze remaining phantoms
- [x] **C3.** World-space “LIFE FORCE DEPLETED” Label3D
- [x] **C4.** Trigger / A / B (or Enter/Space in editor) → `reload_current_scene()`

**Done when:** Hitting 0 stops the fight and offers a clear retry.

---

### Package D — Minimal Visual Feedback

**Intent:** Readable in peripheral vision. Not the full aura system yet.

Pick **one** primary + **one** secondary:

**Primary (required):**
- [x] **D1.** Life force meter on left wrist (`LifeForceMeter` under LeftHandController)
  - Bar fill + LIFE label
  - Color shift by state: blue → purple → red

**Secondary (pick one for this pass):**
- [x] **D2a.** Camera tint quad intensifies in danger/critical  
  - [ ] **D2b.** Soft body outline / emission on player capsule (deferred)

**Defer to Phase 3:** full particle aura, glitch HUD, directional damage indicators.

**Done when:** You can tell approximate life force without looking at the console.

---

### Package E — Minimal Audio Feedback

**Intent:** Heartbeat sells urgency better than another UI widget.

- [x] **E1.** Looping heartbeat `AudioStreamPlayer` (procedural WAV if no asset)
- [x] **E2.** Volume / playback rate by state
  - Healthy: silent / stopped  
  - Caution (&lt;70%): quiet  
  - Danger (&lt;40%): clear  
  - Critical (&lt;10%): fast + louder
- [x] **E3.** Drain blip on `damage_applied`
- [ ] **E4.** Optional: call music intensity stub when entering danger (nice-to-have, not blocking)

**Asset note:** May need a short heartbeat loop if none exists under `Assets/Audio/SFX/`. Placeholder silence with a metronome tick is OK until a real sample lands.

**Done when:** Eyes closed, you can still feel “I’m almost dead.”

---

### Package F — Recovery

**Intent:** Reward clearing space; punish panic flailing into crowds.

- [x] **F1.** On damage: set `time_since_hit = 0`
- [x] **F2.** Each frame: if `time_since_hit >= recovery_delay` and not depleted, add `recovery_per_second * delta`
- [x] **F3.** Emit `life_force_changed` while recovering
- [x] **F4.** Cap at max; heartbeat follows state improvements

**Done when:** Surviving a scare and resetting to healthy is possible without cheats.

---

### Package G — Integration Polish (still in this step)

Small glue so the feature doesn’t feel bolted on.

- [x] **G1.** Heartbeat on Master at moderate volume (music untouched for now)
- [x] **G2.** Gated noisy hand-pose prints in `Scripts/main.gd` (script still orphaned from main scene)
- [ ] **G3.** Smoke-test: 1 rift, many phantoms, die; restart; recover path *(needs headset / play session)*
- [x] **G4.** Update [Life_Force_System.md](Life_Force_System.md) checklist boxes for what shipped in the slice vs deferred
- [x] **G5.** Roadmap Phase 1A marked implemented; exit criteria pending headset verify

---

## Suggested Build Order

```
A (manager) → B (wire hits) → F (recovery)
        ↓
   D (meter) + E (heartbeat)   ← can parallelize
        ↓
        C (game over + restart)
        ↓
        G (polish / docs)
```

Do **not** start Yellow phantom finish-work until A–C work in the headset. Variants without fail state still feel like a toy.

---

## Acceptance Test Script (Playtest)

1. Start game, note full life meter, silent heartbeat.  
2. Let one phantom touch you → meter drops ~5%, brief feedback, recovery delay starts.  
3. Stay clear 3+ seconds → meter ticks up.  
4. Tank hits to &lt;40% → heartbeat clearly audible; colors shift.  
5. Tank to 0 → spawning stops, game over message, phantoms stop being a threat.  
6. Restart → fresh life force, rifts/phantoms behave normally.  
7. Repeat once more to catch “second death” bugs.

---

## Explicitly Not In This Step

| Deferred | Why |
|----------|-----|
| Full aura particle system | Art time; meter + heartbeat carry the slice |
| Iron Man arc-reactor HUD art | Same |
| Elite/boss drain tiers | No elite/boss yet |
| Directional damage indicators | Needs more UX design |
| Win condition / score HUD | Phase 1B / 1C — immediately after |
| Yellow phantom completion | Phase 1D — after stakes exist |

---

## File Touch Map (Expected)

| Path | Change |
|------|--------|
| `Scripts/Player/life_force_manager.gd` | **New** |
| `Scenes/Player/player.tscn` | Attach manager + meter + audio |
| `Scripts/Phantoms/phantom.gd` and/or spawn path | Ensure hit → damage bridge |
| `Scripts/Rifts/rift_spawn_manager.gd` | Pause on game over |
| `Scripts/` round/game-over helper | **New** (small) or scene-reload only |
| `Assets/Audio/SFX/` | Heartbeat (+ optional drain) |
| `development/Life_Force_System.md` | Check off shipped items |

---

## Risk Notes

- **Signal connection timing:** Phantoms spawn at runtime — connecting only in `_ready` of the player will miss them. Prefer group lookup on hit or connect-at-spawn.
- **Multi-damage frames:** If contact can fire more than once before the phantom frees, life force melts unfairly. Verify one damage event per phantom.
- **VR HUD placement:** World-space UI that clips the floor or sits in dead center will annoy. Prefer wrist, lower-peripheral, or slight follow offset.
- **Game over + dissolve:** Freeing everything at once can hitch; stagger or disable AI first if needed.

---

## After This Step

Return to [Production_Roadmap.md](Production_Roadmap.md) Phase **1B** (win condition + round loop), then **1C** (score/progress HUD). Life force makes death real; win condition makes the fight *about* something.
