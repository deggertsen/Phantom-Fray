# Phantom Implementation Checklist

Status as of 2026-10-08. Design detail is in [Phantom_Enemy_Breakdown.md](Phantom_Enemy_Breakdown.md).

## 1. Base phantom
- [x] `CharacterBody3D` base with collision, mesh, contact `Area3D`
- [x] Inheritance: `ResonancePhantom` (yellow, blue), green, pink
- [x] Procedural creature meshes, three forms per species, prewarmed
- [x] Per-species material tuning (sway, flap, snap)

## 2. Collision and strikes
- [x] Grip-gated strike spheres on both hands with velocity quality
- [x] Strike window: in reach or commit phase only
- [x] Lure sweet spot for Anglers in hook, uppercut, jab positions
- [x] Possession on core proximity to head, lunge point, or body
- [x] Signals: `resolved`, `player_contact`, `strike_rejected`, `feedback_requested`

## 3. Behavior
- [x] One continuous bezier arc into reach with speed ramp
- [x] Lateral bow per color, height jitter
- [x] Homing near the head, pass-through and recover, re-approach
- [x] Stall and lifetime cleanup
- [x] Pressure scaling per wave (speed, telegraph)
- [ ] Low approaches for uppercuts and squats
- [ ] Boss or finale behavior

## 4. Variants
- [x] Yellow: left hand, lure crit
- [x] Blue: right hand, lure crit
- [x] Green: faster, two-hand block window
- [x] Pink: telegraph, floor lane, charge, dodge resolve
- [x] Drifter base (unused in waves)
- [ ] New species (shield, ranged drain, projectile)

## 5. Spawning
- [x] RiftDirector: rift count, concurrency, placement modes (random ring, clustered pair, front arc)
- [x] RiftManager: timer spawns from wave pool, live cap, health, flash, dissolve
- [x] Beacon column, floor ring, label, compass chevron, phantom bearings
- [x] Six operations as wave tables

## 6. Health and scoring
- [x] Rift health and damage per resolve
- [x] Score, crit bonus, on-beat bonus, chain multiplier to 3x
- [x] Life force drain on possession
- [x] Strike VFX (sparks, shockwave, flash), haptic tiers, death and siphon takes
- [ ] Score popups beyond the wrist delta
- [ ] Persisted best scores and medals

## 7. Integration
- [x] Chen comms for first contact, wrong hand, chain, life force, outcome
- [x] Music intensity by pressure and life state
- [ ] Difficulty tiers
- [ ] Endless hold mode
- [ ] Session stats

## 8. Performance and polish
- [x] One mesh per creature, shaders compiled during the menu
- [x] No per-phantom raycasts in steady state
- [ ] Final SFX mix on headset
- [ ] Movement and attack sounds per species
