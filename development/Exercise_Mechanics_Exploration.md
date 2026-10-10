# Exercise Mechanics Exploration: Squats, Jumps, Push-ups

**Written:** 2026-10-09. **Updated** the same day with five rounds of David's answers, his boss proposal, and the merge of `main` (no mission time limit).
**Status:** Exploration. Nothing here is scheduled except where the roadmap links it. A squat detector prototype exists behind a debug flag (`Scripts/Player/squat_detector.gd`, off by default), the resonance sweep is built as a debug-only drill (`Scripts/Hazards/resonance_sweep.gd`, prototype plan Step 3), and The Maw's boss phase is built as a debug-only mission (`Scripts/Bosses/maw_boss.gd`, Step 6).
**Question:** How could Phantom Fray require squats, jumps, and push-ups, with harder difficulties that demand them, using a Quest 3 headset with its controllers or tracked hands?

## The short answer

Bosses carry the movements. A boss attacks with its tentacles, and each attack has one physical answer: squat under a high sweep, jump a low sweep, and side-step out of a slam. A slam costs the boss so much that the tentacle lies spent on the floor afterwards, and the operator does push-ups on it to drive ERM resonance through the ground into it. A boss cannot hold its shape in our world for long, so the fight is a survival interval with a known length, which is exactly the shape of a workout block; it ends when the boss retreats through its rift. Bosses demand far more exertion than anything else in the game, so they appear only at the movement difficulties; Assist, Standard, and Operator never meet one. The current six operations become the tutorial that teaches the combat rules first, and missions run five to ten minutes.

Build squats first: the detector exists, the high sweep is the safest and most readable attack, and it fits the existing rules (it resolves like the pink dodge, so it scores, chains, and damages). Jumps are in scope and Full Resonance assumes the player can jump, but a headset test has to show head tracking can see a jump before the low sweep is built. Push-ups are done on hand tracking, which is required at Full Resonance as the first thing we try.

The one design fact that shapes everything below: **a target's position cannot force a squat.** A phantom at knee height can be reached by bending at the waist, which is worse exercise and harder on the back. What we can measure is the head. So every mechanic here is a rule about where the head is, not where the fist lands, and the detector's job is to tell a squat from a bend.

## Decisions (David, 2026-10-09)

First round:

1. **Difficulty is chosen per mission on the world map.** The six current operations become the tutorial that introduces every mechanic. After that, the player picks missions from the war map by difficulty, not by number. Movement demands live only at the higher difficulties, which some players will never choose.
2. **Standard missions include duck-depth sweeps.** Nothing deeper than the pink duck already asks.
3. **Push-ups are done palms flat, never with weight on the controllers.** The direction is hand tracking instead of controllers.
4. **Jumps are in scope.**
5. **A bend instead of a squat loses the bonus,** it does not fail the dodge. Chen corrects it.
6. **Squats (and the other movements) count in the session stats.**
7. **No heart-rate claim.** Chen reads resonance, computed from movement.
8. **The movement difficulty is available from the start** of the world map.
9. **Calibration happens in the three-second countdown** every mission, plus the rolling estimate. No calibration screen.

Second round, on bosses:

10. **No "No jumps" switch for now.** Full Resonance assumes the player can jump. It may come later.
11. **What a boss's retreat means on the war map is open.** Decide it while building the map.
12. **One boss first,** with attacks later bosses can reuse.
13. **The Maw is probably the first boss.** Described below. (Refined in decision 18.)
14. **Phantoms during a boss fight: maybe at the highest difficulties.** David's idea to explore: phantoms circle the boss, and the boss sends them at the operator as one of its attacks.
15. **Bosses never die.** A boss always retreats through the rift it came through, before that rift closes. Lore: bosses are gathering enough energy to establish a permanent presence in our world. No banish.
16. **Hand tracking is required at Full Resonance, as the first try.** Decide after the headset tests. Losing haptics is acceptable. Simultaneous hands and controllers is an acceptable fallback.

Third round:

17. **Bosses only at the higher difficulties.** They require much more physical exertion, so Assist, Standard, and Operator never meet one. Every boss attack is answered with a detected movement; there is no punch-only version.
18. **The Maw has two phases, and only its tentacles come through.** Phase one is today's behaviour: phantoms pour through and the operator fights them. Phase two is the tentacles.
19. **A spent tentacle is down for up to 20 seconds or 10 push-ups,** whichever comes first.
20. **Missions run five to ten minutes each.** Since `main` removed the time limit (missions now count elapsed time up and record the fastest victory), this is a target for actual play, set by rift health and spawns.

Fourth round:

21. **The start of phase two has to feel like the opening of a boss fight.** The player should feel the intensity of the moment. See "The turn".
22. **The Maw does not always let a boss through,** so facing The Maw never guarantees a boss fight.
23. **Show players an expected mission time range,** now that missions have no time limit.
24. **A retreat holds the line at that breach for now,** and the boss can rise again at another one. Revisit with the war map.
25. **The tutorial keeps The Maw's phase one and ends on the tentacle glimpse.** The two-phase Maw is a war-map mission.
26. **One movement difficulty for now.**
27. **The five-to-ten-minute length applies from OP-02 onward;** OP-01 stays short.
28. **Feeding (the boss eating its escort) is not decided.** Talk it through before committing.

Fifth round:

29. **The Maw's break odds as recommended, as a first pass:** the first Maw at the movement difficulty always breaks, then about one in three, never three in a row without a boss, with a readings hint on the war map.
30. **The tentacle glimpse appears rarely at Assist, Standard, and Operator** as foreshadowing.
31. **The weaker silence beat with Play My Own Music is accepted.** It is a power-user feature; by the time a player reaches a boss they have heard the game's own music through many missions.

---

## Bosses carry the movements

### The attacks

| Attack | Telegraph | Answer | Detected as |
|---|---|---|---|
| **High sweep** | The tentacle draws back to one side; the pylons light a line at the sweep height; Chen: "Low!" | Squat under it | Head below `standing_height * (1 - 0.20)` as it crosses. A bend survives but loses the bonus. |
| **Low sweep** | It runs in along the floor from one side, so its arrival is visible, like a skipping rope | Jump it | The detected flight covers the moment `T` it crosses the player, or takeoff happened in the 0.35 s before. Runs of up to three, then a rest. |
| **Slam** | The tentacle rises overhead and an impact ring paints the floor around the player, the way the pink lane paints a line | Side-step out of the ring | The pink dodge rule: the head leaves the ring before impact |
| **Spent tentacle** | After a slam it lies on the floor, dimmed, for up to 20 seconds | Push-ups on it | Push-up rule, palms flat, hand tracking. The window ends at 20 seconds or the 10th push-up, whichever comes first. |
| **Escort volley** | The phantoms circling the boss break formation | The existing phantom rules | Strikes, blocks, and dodges as today |

The boss frame beats my first pass for three reasons:

- **Readability.** A tentacle you watch rear back is a clearer tell than an abstract blade of energy. The body is the telegraph.
- **The movements become answers, not exercises.** Nobody squats because the game asked for squats; they squat because a limb the size of a bus is coming through the space their head is in.
- **Pacing is authored.** Pool spawns are random; a boss's attack pattern is scripted. We control exactly how many squats and jumps a minute asks for, and when the rests come. That is the safety budget from section 3, built into the encounter.

The low sweep needs a generous window because a detector that misses a real jump punishes a player who did the right thing, which is the worst failure in this document. The numbers come from the jump signal test (section 3, test 3). Chen gives the space check before the first one in a mission: "It's going for your feet. Check your space."

### The slam: dodge it, then work on it

David's version is the right one: the slam is dodged, not caught, and the push-ups happen on the tentacle afterwards. Dodging out of a painted ring is a rule players already know from the pink Spearfin, it keeps the player upright and watching, and it means the push-up window is earned by the dodge.

**Why the tentacle is spent.** The drain lore answers this. Everything a boss does in our world costs it energy, and holding its shape here already costs almost everything it has. A slam is its most expensive move: it pours itself into one limb, and when the limb hits the ground there is nothing left in it. It lies limp until the boss can push energy back into it. That is the classic big-attack recovery window of every boss fight, explained by the same rule that forces the retreat. It also explains why the boss's other attacks hold back while the tentacle is spent: it cannot afford them.

**Why push-ups hurt it.** Chen built the ERM to discharge through the ground, like a lightning rod. A spent tentacle lying in the breach floor is touching the operator's circuit. Palms flat on the floor, on or beside the tentacle, every push-up drives a pulse of resonance through the ground into it. The pulses drain the boss's anchor (below), so push-ups are how an operator makes it retreat sooner.

**Where it lands.** The slam comes down where the player was standing. After a side-step it lies about half a metre away, in reach, so the player turns to it and gets down. No walking.

**How long it stays down.** Up to 20 seconds or 10 push-ups, whichever comes first (decision 19). Ten push-ups in 20 seconds is a steady two seconds a rep, so a strong player ends the window early with every pulse landed, and nobody is asked for more than ten at a time. The tenth pulse makes the tentacle convulse and tear back into the rift, the visible payoff for finishing the set.

**When the window ends.** The tentacle twitches, Chen calls "Up. It's waking.", and it recoils into the rift 1.5 seconds later. The boss then holds every attack for another two to three seconds so the player can stand up before anything comes. Nothing can reach a player who is on the floor.

Why this works:

- **The lore holds.** The stun and the retreat come from the same rule, and "ground the gauntlets" becomes a weapon with a target.
- **The floor phase is safe by construction.** The boss cannot afford to attack, so nothing arrives while the player is down. That was the hard requirement from section 3.
- **The player sets the pace.** Push-ups are controlled reps, not a race to the floor.
- **The floor is the readout.** Face down, the player sees each pulse run from their palms into the tentacle. No need to look up.
- **It is a reward, not a toll.** The boss drains on its own, so a player who skips the push-ups still survives the fight. They just face it for longer.

Ideas set aside: an overhead two-hand brace to catch the slam (worth keeping for a later slam too wide to dodge), push-ups to recharge life force (exertion should cost life force, not restore it), and push-ups to get up after a knockdown (a punishment that puts the player on the floor while the boss is free).

### The drain and the retreat

**Lore.** Bosses do not die. They are trying to gather enough energy to establish a permanent presence in our world, and every crossing is an attempt to hold on. A boss can only come through at all by draining a city's worth of life force first, which is why they rise at dead cities. Holding that shape here burns it out, so an operator who outlasts it forces it back through the rift it came from, and the rift closes behind it. Phantoms already "consume positive life energy to maintain their form in our dimension"; a boss is the extreme case.

**Mechanic.** The boss has an **anchor**. In a boss mission the rift's health bar is the anchor: the rift is open only because the boss is holding it open. That reuses the existing rift health, the rift hexes on the bracer, and the seal dissolve.

- The anchor drains steadily on its own.
- **Possessions feed it.** Every time the boss or its phantoms drain the operator, the anchor refills a little. Mistakes keep it here longer.
- **Work drains it faster.** Resolved phantoms (as they damage rifts today) and pulses into a spent tentacle take anchor directly.
- **At zero it retreats** through the rift, the rift closes, and the mission is won. A faster retreat is a better score and medal (Phase 6 medals).

For fitness: with no hits taken and no work done, the anchor sets a maximum length for the tentacle phase (three to four minutes is a good first number). That is a known interval a player can plan a session around, and the work they put in shortens it.

What a retreat means on the war map is open (decision 11).

### Phantoms in a boss fight

David's escort idea is the strongest of the options:

- **A. Escort and volley.** Phantoms circle the boss in a ring. One of its attacks breaks the ring and flings them at the operator, arriving one after another in a readable rhythm. The ring is the telegraph: the player can count the volley before it comes. This makes the phantoms part of the boss's pattern rather than a separate stream, keeps the arena readable, and scales by difficulty through volley size and speed.
- **B. Feeding.** When its anchor runs low, the boss pulls an escort in and eats it to buy time. Clearing a volley quickly keeps it hungry. It fits the lore exactly, and it gives the player a reason to care about the escort.
- **C. Shield.** Escorts close around the spent tentacle and must be punched away before push-ups pay. **Reject:** it sends phantoms at a player on the floor.
- **D. A stream from the rift,** as in an ordinary mission. The simplest, and the least boss-like.

Recommended: A in every boss fight, since it is the boss's own attack, and D not at all for now. B is undecided (decision 28): it adds a reason to clear volleys fast, but it also makes a struggling player's fight longer, which may feel like a punishment stacked on a punishment. Talk it through before building it. The escort holds still while a tentacle is spent.

### The Maw

**Today.** OP-06, the last of the six operations. One rift at double size (the portal is 8 m across) that pours a steady flood: a phantom every 0.875 s, up to eight live, drawn from all four phantom rules, and 1600 health to seal. Its card estimates 4 to 6 minutes. (The other operations now open twice as many rifts; The Maw stays a single rift.) Missions have no time limit; the bracer counts the elapsed time up, and results record the fastest victory. Chen opens with "One mouth. Twice the teeth. Twice the hunger." and closes with "The Maw is shut. It will remember how long you made it chew."

**As the first boss.** The Maw is that wide because something enormous is trying to come through it. Only its tentacles reach out; the body stays on the far side, because it cannot yet afford our world. That gives the first boss one thing to read, limbs to dodge and punish, and keeps the full creature back for a later reveal. It also keeps the art cost to tentacles rather than a whole creature.

**Phase one: the flood** (decision 18). Today's Maw: the vast rift pours phantoms and the operator fights them, each resolve damaging the rift as it does now.

**Phase two: the tentacles.** High sweeps, low sweeps, slams, spent tentacles for push-ups, and escort volleys, on an authored pattern. The anchor drains; outlast it and the tentacles pull back, the Maw closes behind them, and the mission is won. Chen's current victory line ("It will remember how long you made it chew") already fits a retreat. Three to four minutes.

**Length.** With no time limit, length is set by rift health, the spawn rate, `max_live`, and the anchor. On a Maw that will break, phase one's health is scaled down (the player cannot tell from the bar) so the whole mission stays inside five to ten minutes (decision 20).

### The turn: opening phase two

The turn has to land like the opening of a boss fight (decision 21). The trick is that the player thinks they have won. Phase one ends exactly the way every rift in the game has ended so far, and the boss takes that away from them. Beat by beat, about twelve seconds:

1. **The false seal (0 s).** The last resolve takes the rift to zero. The seal starts as it always does: the portal begins to dissolve, the music resolves, Chen starts her seal line: "That's it, it's clos..."
2. **Silence (0.5 s).** She cuts off. The music stops dead. Every sound in the arena ducks except a low rumble from the rift that the player feels more than hears. The dissolve freezes, then runs backwards.
3. **They run (1 to 3 s).** The phantoms still out stop mid-lunge, turn, and flee back to the rift. The player sees the things they have been fighting for five minutes afraid of something. They settle into a slow ring around the Maw: the escort.
4. **It tears (3 to 5 s).** The Maw rips wider than its 8 m. The sky crack spreads. The corruption veins in the floor race from the rift to the player and run under their feet. The pylons flicker and dim. The light shifts toward the boss's colour.
5. **The first tentacle (5 to 8 s).** One tentacle slides out along the floor toward the player, slowly, and stops two or three metres away. Then it rises until the player has to tilt their head back to see the top of it. In VR, scale is the most powerful tool we have; this is the moment to use it.
6. **Chen (8 to 10 s).** A breath, then quietly: "It's not closing. Something's holding it open." Then: "Operator. That is not a phantom."
7. **The roar (10 to 11 s).** A sound from the rift, low and spatial. A shockwave ring rolls out across the arena, lifting dust and rubble. It is harmless, and it passes through the player.
8. **The fight (12 s).** The boss music hits. The rift hex on the bracer refills and its label changes to the boss's name: the anchor. Chen: "Get ready to move." The first attack is always a slow high sweep with a long tell, so the first thing the boss asks is the easiest thing it asks.

Why it works:

- **The false seal.** Every operator has watched rifts seal dozens of times. Undoing that is the scare.
- **The phantoms flee.** Fear is shown, not told: the enemy the player has been beating is afraid.
- **Silence before sound.** A hard cut to near-silence is more intense than any loud sting.
- **Scale.** Looking up at something is the moment VR does better than any other medium.
- **A breather that does not feel like one.** Twelve seconds with no threat after a five-minute flood is exactly the rest a workout wants before its hardest block, and it plays as the most tense moment of the mission.

Comfort rules for the turn:

- **No camera shake and no forced motion.** The world shakes; the player's view never does.
- **Nothing passes through the head.** The tentacle stops short of the player; the shockwave is a ground ring below eye level.
- **Reduced Flashes caps the light shifts,** as it does the damage tint.
- **No control taken away.** The player can look anywhere; nothing is a cutscene.

What exists to build it with: the rift's dissolve and scale (`rift_manager.gd`), the corruption veins (`arena_builder.gd`) and sky crack, the music intensity controller (`music_intensity_controller.gd`) for the duck and the cut, Chen's comms, and a boss theme prompt already written in [Music_Prompts.md](Music_Prompts.md). New: the tentacle itself, the phantoms' flee-to-ring behaviour, the reversed dissolve, and the shockwave ring. With Play My Own Music on, the player's music keeps playing; the silence beat is then carried by the game's SFX ducking, which is weaker. Worth testing whether the turn should briefly ask the system to pause the other app's audio, if Horizon OS allows it (unknown).

### Does The Maw always break?

No (decision 22). Not every Maw lets a boss through, so facing The Maw is never a guarantee of a boss. That makes the false seal work every time: the player cannot know until the seal either holds or does not.

- **Only at the movement difficulty.** At Assist, Standard, and Operator, The Maw always seals after phase one (decision 17). Sometimes it ends on the tentacle glimpse, as foreshadowing.
- **At the movement difficulty, sometimes.** Recommended:
  - **The first Maw a player takes on at the movement difficulty always breaks,** so everyone who chose it meets the boss.
  - **After that, about one in three,** decided when the mission starts.
  - **A pity rule:** never three Maws in a row without a boss.
  - **A hint, not an answer:** the war map shows a reading for each Maw ("Readings behind the rift: elevated"). Elevated readings raise the odds; they never make it certain. That ties the boss to the lore (it comes through when it has gathered enough) without spoiling the turn.

**The tutorial** (open question 2, agreed). The tutorial keeps The Maw as phase one only and ends with a glimpse: as the Maw closes, one tentacle reaches out, grips the edge of the rift, and is dragged back through. Chen: "Did you see that? Something bigger was holding it open." A story beat, no fight. The full two-phase Maw is the first boss mission on the war map, at the movement difficulty.

### Showing an expected mission time

Missions have no time limit now, so players need a sense of how long a mission takes before they pick it (decision 23). **Built on `main`:** every Operations card shows an `expected_minutes` range and the best time once there is one; the ranges are estimates from the wave tables until timed headset runs replace them. What is left for bosses:

- **The war map** uses the same range on its mission cards.
- **For a Maw that might break,** the range covers both outcomes and does not say why; the readings hint carries that. With phase one shortened on a breaking Maw, the card can keep one honest range.

### Hand tracking

Decision 16: required at Full Resonance as the first try. For push-ups it is plainly the right input: palms flat with nothing in them, and the palm joints on the floor give a precise floor height. For the fighting, the headset tests in section 3 (tests 7 and 8) decide it:

- **Punch speed.** Strikes need hand velocity up to 10 m/s (`hand_collision.gd`). Hand tracking is weakest on fast motion; a full-speed hook may lose the hand or arrive late.
- **Field of view.** Hands are only tracked where the headset cameras see them. Wide hooks and blocks close to the face are at the edges.
- **The strike rule.** "Grip held and moving fast" becomes "fist closed and moving fast", read from finger curl.
- **Haptics.** Lost, and that is accepted. Audio and VFX carry the strike feedback tiers.

The fallback is `XR_META_simultaneous_hands_and_controllers`, which the bundled `godotopenxrvendors` 5.1.0 lists in its changelog: fight with controllers, let them hang on the straps for the floor, hands tracked, no menu switch. Untested. `tools/build_quest_debug.ps1 -HandTrackingTest` builds it in for tests 7 and 8 (section 3, "Running tests 7 and 8").

### Where bosses sit

- **Tutorial.** No boss fight. The Maw's phase one, ending with the tentacle glimpse.
- **Assist, Standard, and Operator missions on the war map.** No bosses. Duck-depth sweeps from ordinary rifts at most (decision 2).
- **Full Resonance (and any difficulty above it).** Bosses, starting with the two-phase Maw: squat-depth sweeps, low sweeps to jump, side-stepped slams, push-ups on spent tentacles with hand tracking, escort volleys.

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

**With hand tracking** (the direction since the update): the same head rule counts reps, and the plank test becomes "both palms within 8 cm of the floor and flat", read from the hand joints. The palm joints at rest give the local floor directly. Godot 4.7 exposes tracked hands through `XRHandTracker` (from `XRServer.get_tracker(&"/user/hand_tracker/left")` and `right`, confirmed on 4.7.1). It gives per-joint flags (position tracked or only valid) and one tracking confidence for the hand, not a confidence per joint; `Scripts/Player/hand_tracking_probe.gd` reads both.

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

Since the update, the boss attacks absorb the best of these: A becomes the tentacle's high sweep, D becomes the push-ups on a spent tentacle, and E its low sweep. B stays a candidate for a later boss. The candidate notes below still hold for the detection and code underneath.

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

A ring of energy runs out from the rift along the floor; the player jumps it. We cannot see feet, so the rule is "the head rose and fell like a jump while the wave passed". Readable enough, but it asks for repeated blind landings, and a missed detection punishes a player who really jumped. Top tier only, never more than one every 20 seconds, never combined with a punch, and only if the headset test in section 3 says detection is reliable. (Update: jumps are in scope, as the boss's low sweep. The tentacle reads better than a ring because its arrival is visible from the side; a run of up to three sweeps counts as one demand, followed by at least 20 seconds without one.)

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
- **Not jumping is not always a choice:** knees, pregnancy, balance conditions. Full Resonance assumes the player can jump (decision 10), so its description on the map must say so plainly before the player picks it.
- Cable-free on Quest, but Link players have a cable around their ankles.

### Push-ups

- **Controllers:** do not put body weight through them. Test the palms-flat, gauntlets-resting form. Wrist straps on, tightened.
- **Tracking:** the headset faces the floor from 30 to 50 cm. Inside-out tracking may struggle on a plain floor; the controllers are close and directly under the cameras. Unknown.
- **Getting down and up:** a 500 g headset, eyes down, then standing quickly. Light-headedness is likely in a long session. Leave a long beat after a floor phase before any threat arrives.
- **No threats** while the player is on the floor. Ever.
- **Volume:** at most 10 push-ups per spent window (decision 19). Space the slams so one boss fight asks for no more than about 30 push-ups to start with, and tune from the fatigue test.
- **Hygiene:** a face in a sweaty gasket, facing down, fogs lenses. Test it.

### Across a 20-minute session

- Movement demands are opt-in (section 4), introduced in training before they appear in an operation.
- A warm-up first operation on the movement tier: fewer squats, no jumps or push-ups.
- Chen gives the boundary and space check before the first floor phase or jump, not buried in a menu.
- The opt-in is the difficulty a player picks on the world map (decision 1). Every mission must have a difficulty with no detected movement, and the tutorial operations never ask for one. A **No jumps** switch inside Full Resonance was considered and deferred (decision 10).

### What needs the headset before anything ships

1. **Calibration:** turn on `debug_enabled` on the Player's `SquatDetector` and stand still. Standing height on the overlay matches eye height (floor to eyes, measured) within 3 cm. Repeat after a recenter: it does not move.
2. **Squat rules, five players if possible, at least two heights:** 20 squats, 20 waist bends, 20 pink-style side ducks, 20 shallow ducks. Squats count at least 19 of 20; bends, side ducks, and shallow ducks count at most 1 of 20 each. Note every false reason on the overlay.
3. **Jump signal:** 10 small jumps and 10 calf raises. Write down the `peak up` reading for each. If the two sets do not separate by at least 0.3 m/s, jump detection is not viable with head tracking alone.
4. **Push-up tracking:** palms flat, first with the gauntlets resting on their straps, then with controllers put aside and hand tracking on. Log `tracking_confidence` for the head and both hands or controllers through 10 reps, on carpet and on a plain floor. Any `NONE` or position jump over 5 cm kills that form.
5. **Landing comfort:** 10 jumps in the stock strap. Does the view blur, does the headset shift, does it hurt?
6. **Fatigue:** one 20-minute run of the movement tier draft. Heart rate if a watch is handy, and a written note on what hurt.
7. **Hand tracking at punch speed:** 20 full-speed jabs, hooks, and uppercuts with hand tracking. Count dropped or late hand poses, and log the hand velocity the tracker reports. If more than 2 in 20 drop, hand tracking cannot be required for combat. Build and procedure: "Running tests 7 and 8" below.
8. **Simultaneous hands and controllers:** enable `XR_META_simultaneous_hands_and_controllers` from `godotopenxrvendors` and check whether letting the controllers hang on their straps switches those hands to tracked hands without a menu, and back again on grip.

### Running tests 7 and 8: the hand tracking build

A debug-only build with hand tracking and a measurement overlay. Combat is unchanged: strikes still come from the controllers (`hand_collision.gd`), and nothing reads the tracked hands except the overlay.

**Build and install**

```
powershell -File tools/build_quest_debug.ps1 -HandTrackingTest
adb install -r builds/phantom-fray-handtest.apk
adb logcat -c
adb logcat -s godot
```

For that one export the switch appends these settings to `project.godot`, then puts the file back byte for byte: `xr/openxr/extensions/hand_tracking`, both hand tracking data sources (`..._unobstructed_data_source`, `..._controller_data_source`), `xr/openxr/extensions/meta/simultaneous_hands_and_controllers`, and `phantom_fray/debug/hand_tracking_probe` (the overlay). It cannot be a feature-tag override or an `override.cfg`: the vendors plugin's Meta exporter adds the `com.oculus.permission.HAND_TRACKING` permission and the frequency meta-data only when the setting is on in the exporting editor, and the editor reads neither. The `Quest Debug` preset now has `meta_xr_features/hand_tracking=1` (optional) and `hand_tracking_frequency=1` (high); they do nothing without the setting, so a plain debug build is unchanged. The `Quest Release` preset is untouched. If a hand tracking build is interrupted and leaves the settings in `project.godot`, both build scripts refuse to run until `git checkout -- project.godot`.

Before the session: turn on hand tracking in the Quest settings (Movement tracking), and light the room well.

**High frequency is Meta's Fast Motion Mode,** made for fitness and rhythm apps, and it needs good light. Meta says it cannot run alongside simultaneous hands and controllers: when both are on, simultaneous wins. So test 7 runs with simultaneous off. If test 7 fails, a second run with `hand_tracking_frequency=0` (low) in the `Quest Debug` preset tells whether Fast Motion Mode was helping.

**The overlay** floats at waist height, 0.7 m ahead of the play-space centre, and works from the main menu, so no round is needed. A yellow sphere follows the left palm and a blue one the right, from the hand trackers rather than the controllers; watch them to judge lag. Left thumbstick click pauses or resumes simultaneous hands and controllers; right thumbstick click resets the counters. For each hand it shows:

| Line | Meaning |
|---|---|
| `using HAND / CONTROLLER / BOTH / NONE` | `BOTH` = the controller is tracked (held or hanging on its strap) and the cameras see the hand. |
| `TRACKED / LOST`, `optical / from-controller` | The hand tracker's data and its source. `from-controller` is a hand pose made up from a held controller. |
| `conf HIGH / LOW / NONE`, `joints n/26` | Godot gives one confidence for the hand tracker, not one per joint; `joints` counts joints whose position is actually tracked rather than guessed. |
| `palm x rep  y calc` | Palm speed in m/s: as the runtime reports it (`--` when it reports none), and calculated from frame-to-frame position. |
| `curl n% FIST / open` | Mean bend of the four fingers. 65% or more reads as a closed fist. |
| `peak 1s` | The highest of each speed in the last second. |
| `punches  dropped` | A punch is a palm move that peaks at 2.5 m/s or more. `dropped` counts punches during which tracking was lost. |
| `drops  jumps` | Times tracking was lost; times the palm moved over 25 m/s between two frames (a teleport, not a hand). |
| `controller` | Whether the controller tracker has a pose, and its interaction profile. |

Each punch, drop, jump, reset, and simultaneous toggle is also printed to logcat as a `HANDTEST` line with its time and speeds, so the numbers can be copied afterwards.

**Test 7 procedure.** Simultaneous off. Put both controllers down on a surface (not on the straps) and check that both hands show `using HAND`, `optical`, `conf HIGH`. Reset. With one hand, throw 20 full-speed punches with a closed fist: 7 jabs, 7 hooks, 6 uppercuts, a second's pause between them so each counts on its own. Read that hand's `punches` and `dropped`, then reset and do the other hand. Missed punches count as dropped or late: a hand fails if `dropped` plus `20 − punches` is more than 2. Also note the typical `peak 1s` for each punch type, whether `FIST` held through the punch, and whether the palm sphere lagged behind the fist by eye. The overlay cannot time lag; that one is a judgement. For a baseline, five jabs holding the controllers (source `from-controller`) show the speed the controllers would have reported.

**Test 8 procedure.** Hold both controllers (`using CONTROLLER`). Click the left stick: the header must read `simultaneous: ON`. If it reads `unsupported`, the runtime does not offer the extension in this build: write that down, and the fallback is out. Let the right controller hang on its strap and open the hand: it should reach `using BOTH` with an `optical` hand within about a second, with no system menu. Make a few slow punches and watch the sphere follow. Grip the controller again and note how long it takes to go back to `CONTROLLER` and whether it needs anything else. Then let both controllers hang, put both palms flat on the floor in a push-up position for 10 seconds, and note `drops` and `conf`. Last, click the left stick to turn simultaneous off and repeat the strap test, to see what the headset does without it.

**What could not be checked without the headset.** The build, the settings, and the counting logic are checked on the desktop (`_validate_hand_tracking_probe` in `Tests/validation_runner.gd` drives a clean punch, a dropped punch, a pose jump, and finger curls through it). These are still unknown until the first session: whether the Quest runtime reports a palm velocity at all (`rep` stays `--` if not), whether it supports the hand tracking data source extension (the source then shows `source?`), whether `is_simultaneous_hands_and_controllers_supported()` is true on Quest 3 with this runtime, whether resuming it succeeds (a failure shows only in logcat as a Godot error), and whether the 65% fist threshold matches a real fist.

**What to write in `development/Playtest_Log.md`.** One entry under Sessions:

```
### YYYY-MM-DD — self, Quest 3, handtest build <commit>
Tests 7 and 8 (hand tracking build), room light:
Test 7, simultaneous off, frequency high:
  Right: jabs counted /7, hooks /7, uppercuts /6; dropped ; drops ; jumps
  Left:  jabs counted /7, hooks /7, uppercuts /6; dropped ; drops ; jumps
  Typical peak speed per punch type (rep / calc):
  Controller baseline jab speed:
  FIST held through punches (always / mostly / no):
  Palm sphere lag by eye (none / visible / bad):
  Verdict: dropped + missed per 20, right / left; 2 or fewer means hand tracking can be required for combat
Test 8:
  simultaneous: supported / unsupported
  Controller on strap -> optical hand, no menu (yes / no, how long):
  Grip again -> controller (yes / no, how long):
  Palms on floor, controllers hanging, 10 s: drops, conf:
  Without simultaneous, controller on strap:
  Verdict:
Odd readings or crashes:
```

Then record the outcome as a decision here: test 7 decides whether decision 16 holds for the fighting, and test 8 whether the fallback exists.

---

## 4. Difficulty on the world map

### Shape

Since decision 1, difficulty is not a campaign setting. The six current operations are the tutorial, run at Standard (Assist available) with no detected movement. After the tutorial, the war map offers missions, each with a difficulty the player picks. Mission tables stay authored once, at Standard, and a difficulty is a transform applied to each wave when the rift is configured, so a map mission does not need four copies. Something like:

```gdscript
# Scripts/Core/difficulty_tier.gd (proposed)
const TIERS := {
	"assist":   {"speed": 0.85, "telegraph": 1.25, "health": 0.80, "contact": 0.6, "squat_depth": 0.12, "movement": []},
	"standard": {"speed": 1.00, "telegraph": 1.00, "health": 1.00, "contact": 1.0, "squat_depth": 0.12, "movement": []},
	"operator": {"speed": 1.12, "telegraph": 0.85, "health": 1.15, "contact": 1.25, "squat_depth": 0.12, "movement": []},
	"full_resonance": {"speed": 1.00, "telegraph": 1.00, "health": 1.10, "contact": 1.0, "squat_depth": 0.20,
		"movement": ["sweep", "skitter"], "bosses": true},
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

A boss mission adds a `boss` entry. Only the movement difficulties offer boss missions (decision 17):

```gdscript
"boss": {
	"phases": ["flood", "tentacles"],   # The Maw: phase one is today's rift, phase two the boss
	"break_chance": 0.33,      # chance the flood turns into the boss; first time and pity rule override
	"expected_minutes": [6, 10],   # shown on the mission card
	"anchor_seconds": 210.0,   # tentacle phase length with no hits taken and no work done
	"possession_feed": 8.0,    # anchor seconds regained per possession
	"attacks": ["high_sweep", "low_sweep", "slam", "volley"],
	"spent_seconds": 20.0,     # a spent tentacle is down this long at most
	"spent_max_reps": 10,      # or until this many push-ups, whichever comes first
	"escort": 4,               # phantoms circling the boss; a volley sends them in
	"phantom_waves": [],       # a stream from the rift, only at the very highest difficulty
}
```

### The difficulties

- **Assist, Standard, Operator** stay about speed, tell length, health, and damage, as the roadmap says. No detected movement is required. Sweeps appear at duck depth (12 %), which any duck or bend clears, the same as the pink lane today (decision 2). They never meet a boss (decision 17).
- **Full Resonance** (new, top): the movement difficulty. It is an intensity, not a harder Operator: speed and tells stay at Standard so the extra work is the body, not reaction time. Squat-depth sweeps, low sweeps to jump, push-ups on spent tentacles. Available from the start of the world map (decision 8) and labelled with what it asks for, jumps included. Hand tracking required as the first try (decision 16), pending tests 7 and 8 in section 3.

### What Chen says

Chen reads the operator's vitals through the gauntlets, so this tier is hers to explain. In her voice, short, under three seconds:

- **Tier select:** "Full resonance. The gauntlets draw on your whole body. Legs too." / "More power. More cost. Clear the space around you."
- **First sweep:** "It's sweeping at head height. Get under it."
- **A bend instead of a squat:** "Not from the back. From the legs." (on a cooldown, like wrong-hand corrections)
- **Brace:** "Brace. Get low and hold it."
- **Seal ritual:** "It's fighting the seal. Ground the gauntlets." / "Three more. It's holding." / "Sealed. Up. Slowly."
- **Space check before the first floor phase:** "Check your space. You're going to the floor."
- **Boss rising:** "That's not a scout. It fed on this whole city to get through." / "It can't hold that shape for long. Outlast it."
- **High sweep:** "Low!" / "Under it."
- **Slam:** "Out of the ring!" / "Move. It's coming down."
- **Low sweep:** "It's going for your feet. Jump it."
- **Spent tentacle:** "That cost it. It's spent. Ground the gauntlets." / "Up. It's waking."
- **Volley:** "Its escort is breaking. Here they come."
- **Retreat:** "It's losing its grip on this side. Hold on." / "It's pulling back through. Seal it behind it."
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

**Step 3. Resonance sweep, debug mission only. Built.** A standalone hazard, so the boss's tentacle can drive the same code in Step 6.
- `Scripts/Hazards/resonance_sweep.gd` (`ResonanceSweep`) and `Scenes/Hazards/resonance_sweep.tscn`. Two rails light at the blade's height, 1.05 m either side of the player, running from the rift side past them; they flicker as they light over 1.15 s (scaled by the wave's `telegraph_scale`, never under 0.45 s). The rails sit beside the player, not on the arena pylons, which stand 6.5 m out. Then a 4.2 m blade appears 4.5 m out toward the rift and runs past the player at 6 m/s (times `speed_scale`), 1.6 m on, and fades.
- Line height: `standing_height * (1 - squat_depth)`. Standing height comes from the Player's `SquatDetector` once it has calibrated, else the camera height when the sweep spawns (1.6 m if that reads under 1.0 m). Only that first reading uses the camera, so a player already ducking cannot drag the line down later. `squat_depth` comes from the wave (`"squat_depth"`, default 0.12, duck depth); `RiftManager` hands the wave to any spawn with an `apply_wave` method.
- Clear: head below the line as the blade crosses resolves like the pink dodge, `resolution_kind` `sweep`, score 150, rift damage 14, `on_beat` true. Head above it: `player_contact` with the usual 20 contact damage, judged 12 cm before the blade reaches the eyes, and the blade goes out there instead of drawing through the face.
- Decision 5: when the detector is calibrated, a dip it flags as a lean or a bend (`SquatDetector.dip_fault()`, which judges the dip at any depth, or a `squat_rejected` for `leaned_or_stepped` / `looking_at_floor` during the sweep) still clears, but with `on_beat` false and the reason in `form_fault`. Chen then corrects it (`sweep_bend`: "Bend your knees, not your waist." and three more), at most once every three sweeps: after a correction, three more sweeps must light before the next. The count starts again each mission, so the first bend of a mission is always corrected. The lines coach the squat and never call the dodge a miss.
- Chen's call: as the rails light (`telegraph_started`, after any wait for another sweep), she says `sweep` ("Low!", "Get low!", "Down!", "Under it!"). It is priority 3 with its own `max_wait` of 0.6 s, so it jumps the queue the moment she is free and is dropped if she is mid-line, because a late "Low!" is worse than none. `ChenComms` hears each sweep through `node_added`, so a boss tentacle's sweep gets the same call and correction. Both events are placeholder Windows-voice takes until ElevenLabs takes replace them (`tools/generate_elevenlabs_vo.ps1`).
- Sound, on the SFX bus: a tell that climbs two octaves with a quickening tremolo, from where the blade will appear, so it says which side the sweep comes from; pitched to the telegraph so it ends as the blade sets out (faster and higher when pressure shortens the tell). Then a whoosh that rides the blade, swelling and panning as it passes overhead; pitched to the blade speed so its peak, 0.75 s in, lands as the blade reaches the player. A hit cuts the whoosh where the blade goes out. Pause holds both. Recorded takes go in `SfxVariations` as `sweep_tell` and `sweep_whoosh` and follow the same timing; until then both are generated in code, like the possession tone. Reduced Flashes has nothing to change in the audio; the visual rules above still hold.
- Comfort: a second sweep waits until the first has finished, then 1.5 s more, before its rails light, so squats never come back to back. The glow fades as the blade nears the head, so a cleared blade passing just over the eyes is a thin, dim line, not a flash. Reduced Flashes keeps the rails a steady ramp without flicker and cuts the blade glow to 45 % and the rails to 60 %.
- Interface: `resolved`, `player_contact`, `apply_pressure`, the `phantom` group, `set_interactions_enabled` (pause freezes it), `shows_approach_cue`, `force_cleanup`. `"sweep"` is in `MissionCatalog.SCENE_BY_ID`. For the boss (Step 6), set before `add_child`: `side` (+1 from the player's right, -1 from the left) or `travel_direction`, `telegraph_seconds`, and `blade_visible` / `rails_visible` off when a tentacle mesh carries the motion; detection runs the same. `telegraph_started` fires as the rails light, `crossed(cleared)` as the blade reaches the player, and `progress()`, `telegraph_progress()`, and `blade_position()` let the tentacle follow it.
- **Sweep Drill** (`sweep_drill`, DBG-S) in `MissionCatalog.debug_missions()`: one 450-health rift, a spawn every 4 s from `["yellow", "blue", "sweep"]`, so a sweep about every 12 s over about three minutes. Debug builds only and never in `all_missions()`, so it is not in the unlock chain or the Operations list and records no clears, scores, or times. Start it with `--mission=sweep_drill`: on desktop after `--` on the command line, on Quest in the Quest Debug export preset's **Command Line > Extra Args** (the code reads both Godot's own and user arguments; not yet tried on device).
- Validation (`_validate_resonance_sweep`): a head below the line resolves with the bonus; a head above it damages, and the blade stops short of the face; a paused sweep neither moves nor judges, and carries on when resumed; the telegraph floor holds; a second sweep waits for the first; the line follows the detector's standing height; a bend clears without the bonus; the rift passes the wave's `squat_depth`; Reduced Flashes dims the glow; the drill stays out of the campaign. With Chen listening: a clean squat gets the call and no correction, and four bent dips in a row each clear and get corrected on the first and the fourth. The tell sounds as the rails light and the whoosh as the blade sets out, both on SFX, and the tell holds while paused.
- Desktop stills: `Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn -- --mission=sweep_drill --art-label=sweep` writes the rails lighting, the blade coming in, and the blade over a ducked head to `reports/play/sweep/`.

**Step 4. Headset test of the sweep.** Ready to run: build Quest Debug with `--mission=sweep_drill` in Extra Args, and turn on the Player's `SquatDetector.debug_enabled` to see the bend check and the standing height on the wrist. The sweep now has its tell, whoosh, Chen's "Low!" and her bend correction (Step 3). Chen's call does tell the player what to do, so "without being told" means without a menu or a demonstration; note whether players react to the rails or to her voice, and whether the call lands in time (it is dropped when she is mid-line). Listen for whether the tell reads as "it's coming from that side". Success looks like: first-time players read the telegraph and get under it without being told, in at least 4 of 5 first encounters; nobody bends at the waist more than once after Chen's correction; a three-minute debug operation with a sweep every 10 to 15 seconds leaves the player breathing hard and wanting another go; nobody reports dizziness.

**Step 5, if step 4 passes.** Run the jump signal test (section 3, test 3) and the hand tracking tests (7 and 8). They decide whether the low sweep and the push-ups on a spent tentacle can be built at all.

**Step 6. The Maw as the first boss. Built, debug mission only.** Plays phase one, the turn, and a tentacle phase to a retreat on desktop. Not yet tried on a headset.
- **Where it lives.** `Scripts/Bosses/maw_boss.gd` (`MawBoss`), a node the `RiftDirector` creates under itself and hands every mission in `start_round`. Nothing runs unless the mission carries `"boss"` (the boss Maw) or `"glimpse"` (the tutorial Maw). The boss Maw is `the_maw_boss` in `MissionCatalog.debug_missions()`, beside the Sweep Drill: OP-06's waves plus a `"boss"` block (`name`, `phase_one_scale` 0.5, `anchor` 840, `anchor_seconds` 210, `squat_depth` 0.20). It stays out of the campaign until the war map's difficulties exist. Start it from the main menu with **B** (debug builds; **Shift+B** forces a break), or with `--mission=the_maw_boss`, adding `--maw-breaks` to make every boss Maw break (for headset sessions).
- **Break odds** (decision 29), decided when the mission goes live: `MawBoss.decide_break(faced, without_boss, roll)`. The first boss Maw on a profile always breaks, then `roll < 1/3`, and two dry Maws in a row force the third. `GameSettings.boss_maws_faced` and `maws_without_boss` persist with progress (`record_maw`), and Reset Progress clears them. Note the pity rule lifts the long-run rate from one in three to 9 in 19 (about 47 %), since every third dry Maw is forced; if one in three should be the real rate, the base odds need to drop to about 0.2. The war map's readings hint is not built.
- **Phase one** is the ordinary Maw, except that on a Maw that breaks its health is scaled by `phase_one_scale` (1600 to 800) so the whole mission fits five to ten minutes. The rift's `hold_open` flag makes zero health send `held_at_zero` instead of sealing.
- **The turn**, twelve seconds, driven from the boss's own clock so pause holds it exactly: the false seal (0 s; the portal starts to dissolve, the music settles, Chen's caption starts "That's it, it's clos—"); the silence (0.5 s; `ChenComms.cut_off()` stops her mid-word, `music_intensity_controller.cut()` stops the music dead, the SFX bus ducks 24 dB, a procedural sub-bass rumble plays from the rift on the Critical bus, and the dissolve freezes, then runs backwards from 1.2 s); they run (1 s; every phantom still out turns and flees to a slot on an upright ring around the mouth); it tears (3 to 5 s; the portal grows 1.6x, the floor veins race out from the rift under the player's feet, the sky crack spreads, the pylons flicker and dim, and the ambient and sun light shift toward crimson, all through `ArenaPresentation.set_boss_mood`); the first tentacle (5 to 8 s; it slides out along the floor, stops 2.6 m short, and rises to 8 m); Chen (8 s, "It's not closing. Something's holding it open." then "Operator. That is not a phantom."); the roar (10 s; a procedural growl from the rift and a ground shockwave ring rolling out at shin height); the fight (12 s; the boss music, Chen's "Get ready to move.", the rift hex refilling as the anchor under the name THE MAW). While the turn plays, Chen says only the boss's lines (`ChenComms.scripted`).
- **The anchor** is the rift's health bar. It refills over 1.5 s, then drains 4 a second (840 over 3:30 with no hits and no work). A possession feeds it 20 (five seconds). Any resolve drains its usual rift damage (a sweep or slam dodge 14, three and a half seconds). Each push-up pulse into a spent tentacle drains 12 and scores 60, so a full set of ten takes 30 s off. At zero: the sweep or slam in flight is cancelled, every phantom flees back through, the tentacle recoils over 2.2 s, the Maw shrinks back and seals the ordinary way, and the mission is won with OP-06's victory line.
- **The pattern.** Opener: a slow sweep (2.2 s tell, blade 3.4 m/s), rest 4 s, a volley of whatever fled at the turn, rest 4 s. Then the cycle until the anchor runs out: sweep (1.5 s tell, 4.6 m/s), rest 3 s, slam (with its spent window), summon escort, rest 3.5 s, sweep (1.4 s, 5.0 m/s), rest 3 s, volley, rest 4 s. That is about three squats a minute plus the floor work, a starting point for the headset session to tune.
- **High sweep.** Step 3's `ResonanceSweep`, added to the rift as an attacker (`RiftManager.add_attacker`) with `side` set, `squat_depth` 0.20, and `blade_visible` off. The rails still light the line; the tentacle draws back past where the blade starts, then lies along the line from the rift past the player and runs sideways with `blade_position()`, its underside on the blade's height.
- **Slam.** `Scripts/Bosses/maw_slam.gd` (`MawSlam`): an impact ring (0.75 m, the pink dodge's radius plus a little) paints the floor where the player stands while the tentacle rises overhead for 1.7 s, then a 0.4 s fall. A head outside the ring at impact is a dodge (score 150, 14 anchor, `on_beat`); inside it is a hit like a possession. Either way the tentacle then lies spent on the floor with its tip where the player stood: dim, still, the escort frozen in place, nothing else attacking. The window ends at 20 s or the tenth push-up. On the timer, the limb twitches and Chen says "Up. It's waking." 1.5 s before it recoils; on the tenth push-up it tears back at once. Every attack then holds 2.5 s while the player gets up.
- **Push-ups** are a hook until detection exists: `MawBoss.register_push_up()` counts one while the window is open. A future detector joins the `PushUpDetector` group with a `push_up_completed` signal and is connected automatically; debug builds map **P** to it.
- **Escort.** `Phantom.enter_escort()` / `release_from_escort()`: an escort flees to its ring slot and circles at 0.16 rad/s, never ages out, never possesses, and gets no bearing marker. A volley releases one every 1.1 s; each builds a fresh attack from where it left the ring (a pink paints a fresh lane). With no stream from the rift (option D), the ring would empty after the first volley, so the pattern summons four through the mouth when fewer than three remain. That summon is a prototype choice to judge on the headset.
- **The bracer.** `RoundHUD` listens for `MawBoss.phase_two_started`: the rift label becomes THE MAW in crimson, and that hex is drawn as the anchor, a solid hex that shrinks as the boss loses its hold.
- **The tutorial Maw** stays phase one. On the first seal of OP-06 on a profile, and one seal in four after that, a tentacle comes out of the closing mouth, curls over the rim, grips it, and is dragged back through while the dissolve runs slower. Chen: "Did you see that? Something bigger was holding it open."
- **Placeholders.** The tentacle is a procedural tube (`MawTentacle`, an `ImmediateMesh` along a Catmull-Rom through six posed points, with a small shader for the rim light and the sucker bands). The rumble and roar are generated (`MawTurnFX`), off the main thread while phase one plays. The boss music is `galactic_showdown` until the boss theme in [Music_Prompts.md](Music_Prompts.md) is produced. Chen's eleven new events in `chen_lines.json` have no recordings yet, so they play as captions; run `tools/generate_elevenlabs_vo.ps1` to voice them.
- **Comfort.** The world shakes and the view never does. The tentacle stops at least 2.3 m from the head during the turn and while idle, and the shockwave stays below the knees. Only the attacks themselves reach the player. Reduced Flashes halves the light shift, holds the pylons steady instead of flickering, and keeps the slam ring a steady, dimmer ramp. Nothing takes control: the player can look anywhere, and pause works at any point in the turn.
- **Validation:** `_validate_maw_break_odds` covers the first-always rule, one in three, the pity rule over twelve unlucky rolls, persistence, and reset. `_validate_maw_boss` covers a breaking Maw's shortened phase one; zero health playing the turn instead of sealing; pause holding the turn; the survivors becoming the escort; the fight opening under the boss's name; the anchor refilling, draining 4 a second, feeding 20 on a possession, and draining on a resolve; push-ups counting only on a spent tentacle, ten pulses and no more, the escort holding still, and the tear-back; and an empty anchor retreating, sealing, and winning. `_validate_maw_glimpse` covers an ordinary mission leaving the boss asleep, the tutorial Maw sealing with the glimpse, the boss Maw staying out of the campaign, and Chen's lines.
- **Desktop stills:** `Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/boss_capture.tscn` (`Scripts/Debug/boss_capture.gd`) presses Shift+B, cuts phase one short, and writes every beat of the turn, a sweep drawn back and crossing, a volley, a slam, a spent tentacle with push-ups, the retreat, and the bracer to `reports/boss/current/`.
- **Not built yet:** the low sweep and real push-up detection (Step 7), feeding (decision 28), the readings hint, a war-map home. The torn Maw reads smaller than intended because the portal shader draws only the middle of its quad, and the RIFT beacon stays up through the fight. With Play My Own Music on, the silence is carried by the duck alone, as decision 31 accepts. This is the Phase 7 Maw finale.

**Step 7. The rest of the tentacle attacks.** The low sweep (if test 3 passed), then push-ups on the spent tentacle with hand tracking (if tests 4, 7, and 8 passed), then the feeding escort if decision 28 lands that way.

---

## 6. Deferred questions

Everything else is answered; see **Decisions** at the top. Two questions are deliberately deferred (David, 2026-10-09):

1. **Feeding** (decision 28). Whether the boss eats its escort to buy time. Not decided yet; revisit once escort volleys can be played.
2. **What a retreat means on the war map** beyond holding the line (decision 24). Unknowable until discovery on the war map starts.
