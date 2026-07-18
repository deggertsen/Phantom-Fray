# Phantom-Fray — Production Roadmap

**Last updated:** 2026-07-18  
**Current stage:** Playable mechanics prototype (pre-vertical-slice)  
**Engine:** Godot 4.5 + OpenXR / godot-xr-tools  
**Target:** Ship a focused VR combat experience (Quest-class headset first)

---

## Where We Are (Snapshot)

| Area | Status |
|------|--------|
| VR bootstrap (OpenXR, controllers, gloves) | Working |
| Punch → kill → dissolve loop | Working |
| Rift spawn / damage / close | Working (base phantoms only) |
| Music + basic SFX | Working |
| Life force / fail state | Not started |
| HUD / menus / win condition | Not started |
| Colored phantom variants | Yellow partial; Blue/Green/Pink shells |
| Custom art (phantoms, arena, gauntlets) | Placeholders |
| Platform build / store readiness | Not started |

The combat sandbox exists. What turns it into a *game* — stakes, feedback, variety, and a clear round — mostly does not.

---

## Guiding Principles

1. **Vertical slice before breadth.** One complete round that feels good beats four half-built systems.
2. **Mechanics before Meshy.** Capsule phantoms are fine until the loop is addictive.
3. **Quest-first performance.** Every feature must survive a mobile VR budget.
4. **Ship a short, sharp experience.** Training + one mission + score chase is enough for v1. Story campaigns and DLC wait.

---

## Phase 0 — Reorientation (1–2 sessions)

Get the headset on and confirm nothing bit-rotted after the Godot 4.5 upgrade and the long pause.

- [ ] Launch on target headset; confirm OpenXR session, hands, punch haptics
- [ ] Play a few minutes: spawn → punch → rift close → music
- [ ] Note jank (rift health visuals, orphan scripts, yellow stubs)
- [ ] Decide v1 scope freeze (recommended below)

**Exit criteria:** Confident the prototype still runs; agreed v1 feature cut.

---

## Phase 1 — Vertical Slice: “One Round That Matters”

**Goal:** A player can start a round, take damage, die or win, and understand why — without menus polish.

### 1A. Life Force + Fail State ✅ *(implemented — verify in headset)*
- [x] Wire `player_hit` → life force drain → recovery → game over
- [x] Minimal visual + audio feedback (wrist meter + heartbeat + camera tint)
- See [Next_Step_Life_Force_Breakdown.md](Next_Step_Life_Force_Breakdown.md) for package details
- **Next:** 1B Win Condition + Round Loop

### 1B. Win Condition + Round Loop
- Stop infinite rift refill; define win (e.g. close N rifts, or survive X minutes while closing rifts)
- Restart / return-to-ready after win or death
- Simple score tally (rift points already flow from punches)

### 1C. Minimal HUD
- Life force meter (peripheral, VR-safe)
- Score + rifts remaining (or progress)
- Brief win / lose messaging in world space

### 1D. First Real Variant — Yellow Phantom
- Finish left-hand + sweet-spot scoring
- Spawn Yellow from rifts (mix with base)
- Visible hit quality feedback

### 1E. Rift Visual Honesty
- Health/close effects use actual `ShaderMaterial` / dissolve path (current StandardMaterial checks are dead)
- Portal reads as weakening as health drops

**Exit criteria:** A friend can play a 3–5 minute round, understand life/death, and want one more try.

---

## Phase 2 — Combat Depth (Core Fantasy)

Make punching feel intentional, not just “touch to delete.”

- [ ] Blue Phantom (right hand + sweet spot)
- [ ] Green Phantom (two-hand block)
- [ ] Pink Phantom (dodge / projectile)
- [ ] Punch SFX + stronger hit feedback (particles, rumble tiers)
- [ ] Combo / multiplier (light version — consecutive sweet spots)
- [ ] Difficulty curve (spawn rates, mix weights, rift HP)

**Exit criteria:** All four color fantasies readable in VR within 30 seconds of first encounter.

---

## Phase 3 — Presentation Pass

Still not “AAA art,” but no longer placeholder-void.

- [ ] Phantom models or strong stylized meshes (Meshy prompts already drafted)
- [ ] ERM gauntlet look (even if collision stays the same)
- [ ] Arena identity (training room / black box with atmosphere)
- [ ] Life force aura / infection look (from Life Force design doc)
- [ ] SFX completeness: punch, hit, proximity, UI confirm
- [ ] Music intensity hooks (low life / climax) — hooks already sketched in music controller

**Exit criteria:** Screenshots/trailer look like a *product*, not a physics demo.

---

## Phase 4 — Meta & UX (Ship Shape)

- [ ] Main menu (VR laser/point or simple gaze/button)
- [ ] Pause + settings (comfort: vignette?, turn mode if any locomotion added, volume)
- [ ] Short tutorial / training room (no fail, phantom select optional)
- [ ] Session flow: Menu → Play → Results → Retry
- [ ] Accessibility / comfort options appropriate for stationary combat

**Exit criteria:** Someone who never saw the project can play without you narrating.

---

## Phase 5 — Platform & Production Hardening

- [ ] Quest (or primary store) export pipeline documented
- [ ] Performance budget: consistent frame rate under max phantom/rift load
- [ ] Crash / edge-case pass (XR session loss, pause during dissolve, etc.)
- [ ] Build automation or at least a release checklist
- [ ] Store assets: trailer, screenshots, description, age rating notes
- [ ] Closed playtest → balance pass → open beta if desired

**Exit criteria:** Installable build on a clean headset; known issues list only contains non-blockers.

---

## Phase 6 — Launch & Immediate Post-Launch

- [ ] v1.0 release
- [ ] Hotfix window for comfort / crash / progression bugs
- [ ] Telemetry-lite or playtest notes → backlog for 1.1

**Explicitly out of v1 (park for later):**
- Full story campaign / Overseer finale
- Hand tracking as primary input
- Boss phantoms, power-ups, environmental hazards
- Leaderboards / achievements / mod support
- Multiplayer

---

## Suggested Sequencing (Broad)

```
Phase 0  Reorient
   ↓
Phase 1  Vertical slice  ←── you are about to enter here
   ↓
Phase 2  Combat depth
   ↓
Phase 3  Presentation
   ↓
Phase 4  Meta UX
   ↓
Phase 5  Platform hardening
   ↓
Phase 6  Launch
```

Phases 2 and 3 can overlap lightly (e.g. Blue phantom + better SFX), but **do not start Phase 4 menus until Phase 1 exit criteria are met.** Menus without a round are a trap.

---

## Rough Effort Framing (Solo / small team)

| Phase | Relative size | Notes |
|-------|---------------|-------|
| 0 | XS | Hours |
| 1 | M | Highest ROI; unblocks everything |
| 2 | L | Most design iteration |
| 3 | L | Art + audio bandwidth |
| 4 | M | UX polish |
| 5 | M–L | Headset/store unknowns dominate |
| 6 | S | Ops + hotfix |

Absolute calendar time depends on hours/week; the order matters more than the dates.

---

## Definition of “Production Ready” (v1)

A build is production-ready when:

1. Player can complete a full session without developer intervention  
2. Win and lose states are clear and restartable  
3. All four phantom types teach their fantasy  
4. Frame rate holds on the target headset at intended spawn density  
5. Comfort and input feel acceptable to non-developer playtesters  
6. Store package installs and launches cleanly  

---

## Related Docs

- [Next Step: Life Force Breakdown](Next_Step_Life_Force_Breakdown.md) — Phase 1A detailed tasks
- [Life Force System Design](Life_Force_System.md) — original design intent
- [High Level Implementation Plan](High_level_implementation_plan.md) — older checklist (partially stale)
- [Phantom Enemy Breakdown](Phantom_Enemy_Breakdown.md) — variant design
- [Phantom Implementation Checklist](Phantom_Implementation_Checklist.md) — older checklist (partially stale)
