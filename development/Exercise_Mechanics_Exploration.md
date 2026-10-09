# Exercise Mechanics Exploration: Squats, Jumps, Push-ups

**Written:** 2026-10-09
**Status:** Exploration. Nothing here is scheduled except where the roadmap links it. A squat detector prototype exists behind a debug flag (`Scripts/Player/squat_detector.gd`, off by default).
**Question:** How could Phantom Fray require squats, jumps, and push-ups, with harder tiers that demand them, using only a Quest 3 headset and its controllers?

## The short answer

Build squats first, as a detected movement with its own hazard: the Overseer's **resonance sweep**, a horizontal blade of rift energy that crosses the arena at head height and has to be squatted under. It needs no body tracking, it scales to every player's height on its own, it is the safest of the three, and it fits the existing rules (it resolves like the pink dodge, so it already scores, chains, and damages the rift). Jumps are a top-tier option at most, after headset testing, because landing blind in a 515 g headset is the riskiest thing in this document. Push-ups belong in a separate, phantom-free "ground the gauntlets" seal phase, and only after a tracking test proves Quest 3 can see the controllers and the floor with the headset 40 cm above it.

The one design fact that shapes everything below: **a target's position cannot force a squat.** A phantom at knee height can be reached by bending at the waist, which is worse exercise and harder on the back. What we can measure is the head. So every mechanic here is a rule about where the head is, not where the fist lands, and the detector's job is to tell a squat from a bend.

---

## 1. What we can measure

| Signal | Godot API | Confidence |
|---|---|---|
| Head position | `XRCamera3D.position`, in `XROrigin3D` space | Certain. `xr_player.gd` already uses it. |
| Floor | `y = 0` of the `XROrigin3D` | Holds under the Stage reference space. `project.godot` does not set `xr/openxr/reference_space`, and Godot's documented default is Stage, which places the origin on the Guardian floor. Confirm in Project Settings → XR → OpenXR on 4.7.1. |
| Head velocity | Finite difference of `XRCamera3D.position` per physics frame (what the prototype does). Alternatively `XRServer.get_tracker(&"head").get_pose(&"default").linear_velocity`. | The finite difference is certain. I believe Godot's OpenXR interface fills the head pose velocity from `xrLocateSpace`, but I have not confirmed it on 4.7.1. Log both on device and compare before relying on the tracker velocity. |
| Head pitch | `-XRCamera3D.transform.basis.z`, its `y` gives where the face points | Certain. |
| Controller position and velocity | `XRController3D.position`, `XRController3D.get_pose().linear_velocity` | Certain. `hand_collision.gd` uses the velocity for strikes. |
| Tracking quality | `XRPose.tracking_confidence` (`TRACKING_CONFIDENCE_NONE`, `LOW`, `HIGH`) on the controller and head poses | The enum exists in Godot 4. What Quest 3 reports for a controller held 10 cm off the floor under the headset is unknown. This is the push-up question. |
| Grip | `XRController3D.is_button_pressed("grip_click")` | Certain, used today. |

Physics runs at the project's physics rate; on Quest the display runs at 72, 90, or 120 Hz. The prototype is written per physics frame and does not assume a rate.

Things to check on device that I cannot answer from the docs:

1. Does recentering (holding the Meta button) change `XRCamera3D.position.y`? It should not under Stage, but log it before and after a recenter.
2. Does Quest's head pose prediction smear a jump's takeoff? The prototype overlay shows `peak up` velocity for exactly this.
3. What does `tracking_confidence` read for controllers lying on the floor, and for the headset pointed at the floor from 40 cm?

### Calibrating standing height

Standing eye height is the reference for squats and jumps. Every threshold is a share of it, so a 1.50 m player and a 1.95 m player are judged against their own legs.

Recommended, and what the prototype does:

- **Initial:** the median head height over the first second of stillness (vertical speed under 0.15 m/s) once the detector is on. In the shipped version this happens during the existing three-second pre-mission countdown (`RoundController.countdown_seconds`), which already asks the player to stand and wait. Chen's countdown can say "stand tall" on the top tier.
- **Rolling:** still, upright samples within 6 % of the current estimate pull it with a three-second time constant, so posture drift and fatigue slouch are followed. Squats and jumps are never still, so they never pull it.
- **Recovery:** if the head never comes back within 6 % for 15 seconds (calibrated on tiptoe, or a bad first second), standing height resets to the highest still sample in that time.
- **Not in the training module.** Training is optional and players skip it. Calibration must happen every mission without asking.
- **Sanity floor:** eye heights under 1.0 m are ignored. Nobody standing in a Quest has eyes that low; if they read that low, the floor is wrong.

### Squat

**Rule (prototype defaults):**
- A dip starts when the head drops 6 % of standing height.
- It is a squat once the head has been at least **20 %** below standing for **120 ms**. For a 1.63 m eye height that is 33 cm, roughly a half squat. For 1.40 m it is 28 cm.
- The rep counts when the head comes back above the 6 % line.
- Held below the squat line for more than 6 s, it is a kneel or a sit, not a rep.

**False positives:**
- **Bending at the waist** (to pick something up, or to duck lazily): the head moves forward more than it drops, and the face points at the floor. Rejected when horizontal head travel divided by the drop is over **1.0**, or the face pitch is below **-50°** at the bottom. A squat keeps the head roughly over the feet (10 to 15 cm of forward travel for a 30 to 40 cm drop) and the eyes near level.
- **Side-step ducks** (the pink dodge): the head travels sideways more than it drops. Same travel rule. This is deliberate: the pink duck stays a dodge, not a squat rep.
- **Crouch-walking:** fails the same travel rule unless the player shuffles very slowly. Acceptable: it is still squatting.
- **Shallow ducks:** below 20 % they are reported as `too_shallow` and never count.

**Degradation:**
- **Short or tall players:** handled by the ratio. The validation runner checks a 1.30 m eye height.
- **Miscalibrated Guardian floor:** a squat is a change in head height, so a floor 10 cm off only shifts the denominator; a 1.63 m eye height read as 1.73 m makes a 33 cm squat read as 19 % instead of 20 %. That is close to the line, so the shipped threshold should come from headset data, but it degrades gently.
- **Long sessions:** the rolling estimate follows a tired, slouched stance down, so a tired player is judged against how they actually stand now.
- **What it cannot see:** knees. A player who sits back onto a chair or kneels will register. The 6 s limit catches the obvious cases; the rest is the player's own workout.

### Jump

**Rule (proposed, untested):**
- Head rises at least **5 %** of standing height above standing (8 cm at 1.63 m), and
- peak upward head speed is at least **1.0 m/s** (a 5 cm vertical jump needs about 1.0 m/s at takeoff; a 10 cm jump about 1.4 m/s), and
- the head returns to standing within **0.2 to 0.8 s**.
- Optional stronger check: during the flight, vertical acceleration is close to free fall (about -9.8 m/s²). Only a body in the air does that.

**False positives:**
- **Rising onto the toes** lifts the head 5 to 8 cm but at well under 0.5 m/s. The speed rule rejects it.
- **Standing up fast out of a squat** overshoots standing by a centimetre or two. The 5 % rise rejects it.
- **Countermovement:** every real jump starts with a quick dip that the squat detector will see. A dip followed by takeoff inside 0.4 s should be labelled a jump preparation, not a squat. (Or counted as a squat jump on the tier that wants them.)

**Degradation:** like the squat, it is a change in height, so floor error barely matters. The risk is the tracking itself: if head pose prediction rounds off the takeoff, the speed rule fails and jumps go unseen. The overlay's `peak up` readout is there to measure this before any jump mechanic is designed.

### Push-up

**Rule (proposed, untested):**
- **Plank:** both controllers below **0.20 m**, head below **35 %** of standing height (57 cm at 1.63 m), face pitched below **-50°**, and the head horizontally within 45 cm of the midpoint between the controllers.
- **Rep:** from the plank, the head drops at least **12 cm** (or 7 % of standing height, whichever is larger) and returns.
- **Floor reference:** at the start of the plank, when both controllers are still for half a second, take their height as the local floor and judge the rest relative to it. Push-ups are the only movement here that depends on the absolute floor, and a 10 cm Guardian error is half the margin. Measuring the floor from the resting controllers removes it.

**Gauntlets in hand or not:** a fist push-up on a Touch Plus controller puts body weight through the handle and thumb on the stick. I would not ship that. The alternative to test: release grip, let the controllers rest on the floor beside the palms on their wrist straps, and push up on flat palms. The controllers lying still give an exact floor and a clear "gauntlets planted" signal (both still, both low, grip released), and the head alone counts reps.

**False positives:** kneeling and bobbing the head will count. So will knee push-ups. Without body tracking we cannot tell the difference, and I recommend not trying: knee push-ups are a legitimate easier form, and the player who bobs is only cheating their own workout.

**Unknowns (all need the headset):** whether Quest 3 holds 6DoF tracking with the headset pointed at a featureless floor from 30 to 50 cm, whether the controllers stay tracked on the floor directly under the headset, and whether Quest's automatic switch to hand tracking fires when the controllers are let go. The project does not enable the hand tracking extension (validation logs `Property not found: 'xr/openxr/extensions/hand_tracking'`), so I expect the app to keep seeing controllers, but that is a guess.

---

## 2. Mechanics

Each candidate is scored 1 (poor) to 5 (strong). **Cost** is reversed: 5 means cheap against the current phantom and rift code.

| Candidate | Movement | Readable in VR | Safety | ERM fit | Cost | Sweat | Notes |
|---|---|---|---|---|---|---|---|
| **A. Resonance sweep** | Squat | 5 | 5 | 4 | 4 | 4 | Best first mechanic. |
| **B. Brace for the roar** | Squat hold | 4 | 4 | 5 | 4 | 4 | A Maw finale beat. |
| **C. Skitter swarm** | Squat + uppercut | 4 | 4 | 4 | 3 | 4 | The Phase 9 "low approaches", made honest. |
| **D. Ground the gauntlets** | Squat to floor touch, or push-ups | 4 | 3 (slam) / 2 (push-up) | 5 | 2 | 5 | The seal ritual. Strongest fiction. |
| **E. Breach wave** | Jump | 3 | 2 | 3 | 4 | 4 | Top tier only, if ever. |
| **F. High lure** | Jump | 3 | 1 | 3 | 4 | 3 | Reject. Replace with a reach. |
| **G. Push-up exorcism** | Push-ups | 2 | 1 | 4 | 3 | 4 | Reject. |

### A. Resonance sweep (squat under it)

The Overseer drags a horizontal blade of rift energy across the breach at head height. The rift flares and draws a glowing line across the pylons on both sides of the player 1.2 s before it fires, the same tell length as the pink lane; the blade then crosses the arena. If the head is above the line as it passes, it drains life force like a possession. If the head is under it, it resolves as a dodge: score, chain, and rift damage, exactly like the pink Spearfin.

- **Why it reads:** a horizontal plane at eye level is the most legible threat in VR. Supernatural's squat walls prove players read and enjoy it.
- **Why it is honest:** the line sits at the tier's squat ratio below the player's own standing height, so it asks a 1.50 m player and a 1.95 m player for the same squat. On Standard it can sit at duck depth (12 %), which a bend also clears. On the movement tier it sits at 20 %, and the detector's lean test decides whether the bonus pays.
- **Fit:** it is a rift attack, not a phantom. It gives the rifts teeth and makes the Overseer feel present.
- **Code:** a new scene in `MissionCatalog.SCENE_BY_ID` (`"sweep"`), so it enters through the existing wave `pool`. `RiftManager._spawn_phantom` only needs a `Node3D` with `resolved` and `player_contact` signals and an optional `apply_pressure`. It must join the `phantom` group and implement `set_interactions_enabled` so pause still freezes it. No change to `phantom.gd`.

### B. Brace for the roar (squat hold)

The Maw roars before a surge; a shockwave rolls out. Chen: "Brace. Get low and hold it." The player holds a squat (head 20 % down) for two to three seconds while the shockwave passes, and gets a resonance burst (bonus rift damage) for holding. An isometric hold is safe, cheap to detect (the SQUAT state already exists), and gives the Maw the distinct behaviour the roadmap asks for in Phase 7.

### C. Skitter swarm (squat and uppercut)

Small ground-hugging phantoms run in along the floor in twos and threes, targeting shin height instead of the eyes. They break only to an uppercut thrown **while the head is below the squat line**; an uppercut from a bend is rejected like a wrong hand (`too_high`, a buzz, the chain resets). This is the roadmap's Phase 9 "lower approaches" with the squat made a rule instead of a hope.

- **Code:** a new variant on `resonance_phantom.gd` that overrides `_lock_target()` to aim at a floor-relative height (`standing_height * 0.35`) instead of 18 to 30 cm under the eyes, and overrides `_evaluate_strike()` to check the detector state. `_core_reaches_player()` checks the live head, a point under the eyes, and the body capsule centre, none of which a shin-height skitter reaches, so it needs its own bite: possession when it gets within 35 cm horizontally of the head's floor position. Cost 3 because the arc and possession code in `phantom.gd` is tuned for head height and needs testing at floor level.
- **Note:** today, squatting under a head-height phantom is a weak dodge. A punchable phantom's lunge target is locked under the eyes when its arc is built, but possession checks the **live** head. A 45 cm squat leaves the head 21 cm from a target 24 cm under the old eye line, inside the 30 cm radius. Only a deep squat escapes. That is fine as it is, but nothing should teach "squat to dodge" until this is decided.

### D. Ground the gauntlets (floor touch or push-ups)

The fiction is the best of the set: as a rift's health falls to zero, it fights the seal, and the operator has to ground the ERM through the breach floor itself. A glowing seal opens at the player's feet. Spawning stops and live phantoms hold back (the round pauses phantom physics, as pause does today) for the length of the ritual. Each rep pushes a pulse of resonance into the seal; the rep count drives the seal's progress bar on the floor and on the bracer.

Two forms, by tier:

- **Ground slam (squat to the floor):** squat and touch both gauntlets to the seal (both controllers below 0.25 m at once, head below the squat line). Every slam is a rep. Six slams seal it. Safe, keeps the grip, keeps the controllers off the floor.
- **Push-ups:** plank on the seal, gauntlets resting beside the palms, four to eight push-ups. Top tier only, and only after the tracking test.

Cost 2: it is a new round phase (a rift that will not close until the ritual ends, a floor seal visual, a rep target, phantom hold and release), not just a pool entry. It must never run with a phantom able to reach the player.

### E. Breach wave (jump over it)

A ring of energy runs out from the rift along the floor; the player jumps it. We cannot see feet, so the rule is "the head rose and fell like a jump while the wave passed". Readable enough, but it asks for repeated blind landings, and a missed detection punishes a player who really jumped. Top tier only, never more than one every 20 seconds, never combined with a punch, and only if the headset test in section 3 says detection is reliable.

### F. High lure (jump to punch)

An Angler whose lure hangs above the head. Punching upward in the air and landing off balance is the worst combination in this document. **Reject.** If we want height, put the lure at full reach so the player rises onto the toes and extends: a calf raise and a reach, no flight.

### G. Possession shaken off by push-ups

A possession that pins the player until they do push-ups. The player goes to the floor with frosted, distorted vision while phantoms may still be arriving. **Reject.** If possession should cost a movement, make it a squat purge (three squats to clear the frost early), which keeps the player upright and facing the threat.

---

## 3. Safety and comfort

### What Meta's guidance covers

Meta's store comfort ratings (Comfortable, Moderate, Intense) describe **motion**: camera movement, player motion, and disorienting effects. They do not describe physical exertion ([Meta Help: comfort ratings](https://www.meta.com/help/quest/331713305046406/)). I found no Meta developer policy that sets limits on exertion or requires an exertion warning ([Meta Horizon developer policies](https://developers.meta.com/horizon/policy/)). That is my reading of what I could find, not a confirmed absence; ask Meta developer support before submission. Phantom Fray is stationary with no artificial locomotion, so the comfort rating should stay where it is whatever we add here. What protects players is our own design: opt-in, warned, and capped.

### Squats

- The safest of the three: the feet stay planted and the player can see the threat coming.
- Fatigue risk is volume. Budget them: no more than about 12 squat demands per minute on the movement tier, and at least 20 seconds without one after every minute of them. Starting numbers to tune, not research.
- Deep squats are not required. 20 % of eye height is about a half squat.
- Rising fast from a deep squat, head-down, with a headset can cause light-headedness. Leave a beat after each sweep.

### Jumps

- **Landing:** every jump lands blind, on whatever is under the feet. Rugs, pets, cables, and furniture inside a badly drawn boundary are real. Downstairs neighbours too.
- **Headset:** Quest 3 is about 515 g on the face. Each landing pushes it down onto the nose and cheeks, shifts the lenses, and blurs the view for a moment, right when the player needs to see. The stock strap makes this worse; it needs testing with the stock strap and with an aftermarket strap.
- **Guardian drift:** players drift a few centimetres per jump. Twenty jumps can carry them toward the boundary. Stationary boundary users have a small circle.
- **Ceilings and fans** when jumping with the arms up.
- **Not jumping is not always a choice:** knees, pregnancy, balance conditions. A mechanic that punishes not jumping must be avoidable.
- Cable-free on Quest, but Link players have a cable around their ankles.

### Push-ups

- **Controllers:** do not put body weight through them. Test the palms-flat, gauntlets-resting form. Wrist straps on, tightened.
- **Tracking:** the headset faces the floor from 30 to 50 cm. Inside-out tracking may struggle on a plain floor; the controllers are close and directly under the cameras. Unknown.
- **Getting down and up:** a 500 g headset, eyes down, then standing quickly. Light-headedness is likely in a long session. Leave a long beat after a floor phase before any threat arrives.
- **No threats** while the player is on the floor. Ever.
- **Hygiene:** a face in a sweaty gasket, facing down, fogs lenses. Test it.

### Across a 20-minute session

- Movement demands are opt-in (section 4), introduced in training before they appear in an operation.
- A warm-up first operation on the movement tier: fewer squats, no jumps or push-ups.
- Chen gives the boundary and space check before the first floor phase or jump, not buried in a menu.
- A comfort setting separate from difficulty: **Movement intensity** (Off, Squats, Squats and floor, Everything). Off must exist and must leave every operation winnable.

### What needs the headset before anything ships

1. **Calibration:** turn on `debug_enabled` on the Player's `SquatDetector` and stand still. Standing height on the overlay matches eye height (floor to eyes, measured) within 3 cm. Repeat after a recenter: it does not move.
2. **Squat rules, five players if possible, at least two heights:** 20 squats, 20 waist bends, 20 pink-style side ducks, 20 shallow ducks. Squats count at least 19 of 20; bends, side ducks, and shallow ducks count at most 1 of 20 each. Note every false reason on the overlay.
3. **Jump signal:** 10 small jumps and 10 calf raises. Write down the `peak up` reading for each. If the two sets do not separate by at least 0.3 m/s, jump detection is not viable with head tracking alone.
4. **Push-up tracking:** plank with gauntlets in hand, then palms flat with gauntlets resting. Log `tracking_confidence` for head and both controllers through 10 reps, on carpet and on a plain floor. Any `NONE` or position jump over 5 cm kills that form.
5. **Landing comfort:** 10 jumps in the stock strap. Does the view blur, does the headset shift, does it hurt?
6. **Fatigue:** one 20-minute run of the movement tier draft. Heart rate if a watch is handy, and a written note on what hurt.

---

## 4. Difficulty tiers

### Shape

Mission tables stay authored once, at Standard. A tier is a transform applied to each wave when the rift is configured, so OP-01 to OP-06 do not grow four copies each. Something like:

```gdscript
# Scripts/Core/difficulty_tier.gd (proposed)
const TIERS := {
	"assist":   {"speed": 0.85, "telegraph": 1.25, "health": 0.80, "contact": 0.6, "squat_depth": 0.12, "movement": []},
	"standard": {"speed": 1.00, "telegraph": 1.00, "health": 1.00, "contact": 1.0, "squat_depth": 0.12, "movement": []},
	"operator": {"speed": 1.12, "telegraph": 0.85, "health": 1.15, "contact": 1.25, "squat_depth": 0.12, "movement": []},
	"full_resonance": {"speed": 1.00, "telegraph": 1.00, "health": 1.10, "contact": 1.0, "squat_depth": 0.20,
		"movement": ["sweep", "skitter", "brace", "ground_slam"]},
}

static func apply(wave: Dictionary, tier: String) -> Dictionary
```

`apply` multiplies `speed_scale`, `telegraph_scale`, and `health` as the roadmap's Phase 6 entry already plans, and adds movement entries to `pool` by weight. New optional wave fields, all defaulting to "nothing":

| Field | Meaning | Default |
|---|---|---|
| `squat_depth` | Head drop ratio a sweep or skitter asks for | 0.12 (duck) |
| `movement_weight` | Share of spawns that are movement entries (`sweep`, `skitter`) | 0.0 |
| `movement_cap_per_min` | Ceiling on squat demands per minute | 12 |
| `seal_ritual` | On a rift: `{"kind": "slam" or "pushup", "reps": 6}` when its health reaches zero | none |
| `rest_after_ritual` | Seconds of no threat after a ritual | 4.0 |

The `contact` multiplier is a change to `Phantom.contact_damage` at spawn, alongside `apply_pressure`.

### The tiers

- **Assist, Standard, Operator** stay about speed, tell length, health, and damage, as the roadmap says. No detected movement is required. A Standard sweep can appear at duck depth (12 %), which any duck or bend clears, the same as the pink lane today.
- **Full Resonance** (new, top): the movement tier. It is an intensity, not a harder Operator: speed and tells stay at Standard so the extra work is the body, not reaction time. It is unlocked from the start (it is a workout choice, not a reward) and labelled with what it asks for.

### Should Standard stay movement-free?

Yes, with one exception I would argue for: the Phase 9 low approaches. A shallow sweep at duck depth asks nothing the pink lane does not already ask, and it makes the standard campaign move more without gating anyone. Real squats, floor touches, and anything that leaves the ground stay in Full Resonance and behind the Movement intensity setting.

### What Chen says

Chen reads the operator's vitals through the gauntlets, so this tier is hers to explain. In her voice, short, under three seconds:

- **Tier select:** "Full resonance. The gauntlets draw on your whole body. Legs too." / "More power. More cost. Clear the space around you."
- **First sweep:** "It's sweeping at head height. Get under it."
- **A bend instead of a squat:** "Not from the back. From the legs." (on a cooldown, like wrong-hand corrections)
- **Brace:** "Brace. Get low and hold it."
- **Seal ritual:** "It's fighting the seal. Ground the gauntlets." / "Three more. It's holding." / "Sealed. Up. Slowly."
- **Space check before the first floor phase:** "Check your space. You're going to the floor."
- **Debrief:** "Your resonance never dropped. Good." / "I logged forty squats. Your legs will tell you tomorrow."

---

## 5. Recommended order

### Squats first, and here is the case

- **Detection is the cheapest and the most robust.** One signal (head height), relative to the player's own standing height, nearly immune to floor error. Jumps need a takeoff speed that head pose prediction may smear. Push-ups need an absolute floor and tracking in a pose nobody has tested.
- **It is the safest.** Feet planted, eyes forward, the threat in view.
- **It is already half in the game.** The pink duck is a squat that nobody counts. Phase 9 already asks for "lower approaches that ask for uppercuts and squats".
- **It serves every tier.** Duck depth on Standard, real squats on Full Resonance.
- **It sweats.** Squats are the large muscle groups; repeated squats raise heart rate faster than anything the arms do.

Jumps are cheap to detect if the signal holds but have the worst safety case. Push-ups have the best fiction but the most unknowns. Both wait for headset data.

### Prototype plan

**Step 1. Detector and overlay. Built.**
- `Scripts/Player/squat_detector.gd` (`SquatDetector`), a `Node` on `Scenes/Player/player.tscn`. Off unless `debug_enabled` is true and the build is a debug build.
- Signals: `calibrated(standing_height)`, `squat_reached(depth_ratio)`, `squat_completed(depth_ratio, seconds)`, `squat_rejected(reason)`.
- A `Label3D` over the right wrist shows the state, rep count, depth, standing and head height, vertical speed, peak rising speed, and the last rejection reason (`too_shallow`, `leaned_or_stepped`, `looking_at_floor`, `held_too_long`).
- `Tests/validation_runner.gd` `_validate_squat_detector` drives recorded-shape motions: a clean squat counts; a shallow duck, a waist bend, a side-step duck, and a hop do not; a 1.30 m eye height squat counts.

**Step 2. Headset tuning session (no gameplay).** Turn on `debug_enabled` in the Player scene, build debug to the Quest, and run tests 1 to 3 from section 3. Write the results into [Playtest_Log.md](Playtest_Log.md) and tune `squat_ratio`, `max_travel_per_drop`, and `min_pitch_degrees`.

**Step 3. Resonance sweep, debug mission only.**
- `Scripts/Hazards/resonance_sweep.gd` and `Scenes/Hazards/resonance_sweep.tscn`: telegraph lines on the pylons, a blade that crosses at `standing_height * (1 - squat_depth)`, `resolved` on a clear (score 150, rift damage 14, `on_beat` true), `player_contact` if the head is above the blade as it crosses.
- `"sweep"` in `MissionCatalog.SCENE_BY_ID`. In the `phantom` group, with `set_interactions_enabled` and `apply_pressure`.
- Read the detector from the Player (group or node path) for the standing height; if the detector is off, fall back to the camera height at spawn.
- A debug-only operation that mixes `["yellow", "blue", "sweep"]` so it never reaches the campaign.
- Validation: a sweep over a head below the line resolves; over a head above it, it damages.

**Step 4. Headset test of the sweep.** Success looks like: first-time players read the telegraph and get under it without being told, in at least 4 of 5 first encounters; nobody bends at the waist more than once after Chen's correction; a three-minute debug operation with a sweep every 10 to 15 seconds leaves the player breathing hard and wanting another go; nobody reports dizziness.

**Step 5, if step 4 passes.** Brace for the Maw and the skitter, then the ground slam ritual. Push-ups and jumps only after section 3's tests 3 to 5.

---

## 6. Open questions for David

1. **Is Full Resonance a tier or a separate setting?** Recommended: both. A tier in the operation picker, backed by a Movement intensity setting in Settings (Off, Squats, Squats and floor, Everything) that caps what the tier may ask for.
2. **Should Standard include duck-depth sweeps?** Recommended: yes, as part of the Phase 9 low approaches. Nothing deeper than the pink duck already asks.
3. **Push-ups with gauntlets in hand, or palms flat with them resting on the straps?** Recommended: palms flat, gauntlets resting, if the tracking test passes. Never weight through the controllers.
4. **Are jumps in scope at all?** Recommended: not for 1.0. Revisit after the jump signal test and only for Full Resonance.
5. **Should a bend instead of a squat fail the sweep, or just lose the bonus?** Recommended: lose the bonus. Never punish a player's body for the safer-looking choice it made in the moment; correct with Chen instead.
6. **Should squats count in the Phase 6 session stats?** Recommended: yes. "Squats: 42" on the after-action report is the cheapest fitness payoff in this document.
7. **Is Chen's "I can read your vitals" a heart rate claim?** Recommended: no real heart rate unless Horizon OS fitness integration exposes it. She reads "resonance", which the game computes from movement.
8. **Full Resonance unlock:** from the start or after OP-02? Recommended: from the start, labelled clearly. It is a workout choice.
9. **Where does calibration live in the shipped flow?** Recommended: the three-second countdown every mission, plus the rolling estimate. No separate calibration screen.
