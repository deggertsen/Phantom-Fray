# Tutorial Plan: Dr. Chen's Breach Orientation

**Status:** plan, awaiting David's approval. Nothing here is built yet.
**Written:** 2026-10-13, against the code on `main` at ffe1477.

Today's Training is six text pages on the menu panel (`_tutorial_pages` in `Scripts/Core/game_flow_controller.gd`, `show_tutorial` in `Scripts/UI/vr_menu_panel.gd`). This plan replaces it with a played scenario: Dr. Chen introduces herself over comms, opens one controlled rift at the breach site, and walks the operator through everything they meet in a fight. At the moment a phantom would be punched, she pins it in place so she can say what matters, and it waits there until the operator does the right thing.

The six campaign operations stay as they are. They remain the extended on-ramp described in the roadmap; this is the first ten minutes before them.

---

## 1. Beat list

Twelve beats, about four to five minutes for a player who does everything right first time. Every beat has a way forward for a player who keeps getting it wrong, so the tutorial can never soft-lock.

Conventions used below:

- **Held** means the phantom is pinned by the per-phantom hold in section 3: still, in reach, punchable, unable to possess.
- **Card** is a small floating text card (Label3D) about 2 m ahead and below eye line, naming the one thing to do. It is the caption of the beat, separate from Chen's subtitle on the bracer.
- **Tag** is a floating label beside a held phantom ("LURE", "LEFT HAND", "BOTH HANDS"), pointing at the part that matters.
- Chen's lines are drafts in her voice from `chen_lines.json`: clipped, focused, dry, quietly urgent, never shouting here. Every line is eight words or fewer so it fits under three seconds. Each line is its own event in a `tutorial_` namespace (section 5). Lines marked *(takes)* have alternates for repeats.
- **Nudge** means: if the operator does nothing useful for 8 seconds, Chen repeats the instruction with a different take, then again at 16 s. After a third nudge on a strike beat, the card adds the desktop/accessibility hint ("GRIP + PUNCH THROUGH IT").

### Beat 1: Chen introduces herself

- **On screen:** the breach site at night, no rift yet. Menu panel hidden. The bracer shows "TRAINING" and full life force. Card: "DR. ELARA CHEN // RSF SCIENCE LEAD".
- **Frozen:** nothing is in play.
- **Chen:**
  1. "Operator, this is Dr. Chen. You hear me?"
  2. "I built the gauntlets on your hands."
  3. "ERM gauntlets. They run on your life force."
  4. "Nothing else touches phantoms. So, up close."
  5. "It's contained. I control what comes through."
- **To advance:** nothing; it runs on when line 5 ends.
- **Wrong:** n/a. The menu button pauses (section 4).
- **On a replay** (tutorial already completed) lines 1 to 4 are replaced by one line: "Back for a refresher? Good." Line 5 still plays.

### Beat 2: Play space and recenter

- **On screen:** the cyan floor ring pulses. Card: "STAND IN THE RING • HOLD META TO RECENTER • SQUEEZE BOTH GRIPS".
- **Frozen:** nothing in play.
- **Chen:**
  1. "Stand in the ring. Clear room to swing."
  2. "Facing wrong? Hold the Meta button."
  3. "Squeeze both grips when you're ready." *(takes, used as the nudge)*
- **To advance:** both grips held together for half a second. This doubles as the first time the operator touches grip. Desktop debug builds: Enter.
- **Wrong:** nothing happens; nudge with line 3's takes.

### Beat 3: The rift opens

- **On screen:** the round begins (section 4): one rift tears open dead ahead at 11 m with its beacon column, open sound, and the bracer's single rift hex. Banner: "BREACH ORIENTATION".
- **Frozen:** the rift spawns nothing on its own timer (`feed` off). Chen decides what comes through.
- **Chen:** "There. A rift. They come through those."
- **To advance:** runs on.

### Beat 4: Grip and strike, the yellow Angler, the lure

- **On screen:** one yellow Angler comes out of the rift at a gentle speed (speed 0.7, long tell) and arcs in from the left. As it reaches punching distance it stops dead about 0.95 m from the face, lure placed in front of its mouth (the jab spot). A cyan stasis ring shimmers around it. Tags: "LEFT HAND" on its body, "LURE" on the light. Card: "LEFT HAND • GRIP, THEN PUNCH THROUGH THE LURE".
- **Frozen:** the yellow, held in its commit phase (strikes count), not moving, not lunging, cannot possess even if the operator leans into it.
- **Chen:**
  1. "I've pinned it. It can't reach you."
  2. "Yellow takes your left hand."
  3. "Hold grip, then punch. Through it."
  4. "That light is the lure. Hit it."
  5. "Lure hits are resonance crits."
- **To advance:** a valid left-hand strike resolves it. On a crit: "Crit. That's the one you want." On a plain hit: "It's down. Next time, the lure."
- **Wrong:**
  - Right hand: the lure flashes red, the hand buzzes, the yellow stays pinned. "Other hand. Yellow is left." *(takes)*
  - Grip without a punch, or a slow push: nothing registers (the existing speed threshold). Nudge: "Grip, and snap it. Through." *(takes)*

### Beat 5: Blue, and the wrong hand

- **On screen:** a blue Angler arcs in from the right and is pinned, lure out on its right (the hook spot). Tags: "RIGHT HAND", "LURE". Card: "TRY YOUR LEFT FIRST".
- **Frozen:** the blue, held.
- **Chen:**
  1. "Blue is your right hand."
  2. "Try your left first. Watch."
- **To advance:** two steps.
  - Step A: the operator hits it with the left. Red flash, buzz, it stays. Chen: "It shrugs off the wrong hand." Card changes to "NOW YOUR RIGHT • HOOK THE LURE". Chen: "Now your right. Hook the lure."
  - Step B: a valid right-hand strike resolves it, with the crit or plain line from beat 4.
- **Wrong / shortcut:** a right-hand strike during step A resolves it anyway, and Chen covers the lesson: "Right hand. Your left would've bounced." Nothing else is required; the operator is never forced into a deliberate mistake twice.

### Beat 6: The chain

- **On screen:** the bracer's multiplier is highlighted (the HUD draws a pulsing frame round it for this beat). Card: "THREE CLEAN HITS IN A ROW".
- **Frozen:** nothing. This is the first live beat: yellow, blue, yellow, one at a time, each spawned as the previous resolves, at speed 0.8.
- **Chen:**
  1. "Every clean hit builds your chain."
  2. "Watch your wrist. Three in a row."
- **To advance:** three valid resolves in a row. Chen: "That's a chain. It multiplies your score."
- **Wrong:** a wrong hand or a possession breaks the chain (the real rules). Chen: "Chain's broken. Again." *(takes)* and the count restarts. After the third broken attempt she moves on: "Close enough. You'll build it live." A possession here is a real 20-point drain; the training life floor (section 4) keeps the operator in.

### Beat 7: Green, the two-hand catch

- **On screen:** a green Carapace comes in low and fast and is pinned at chest height, body widened. Tag: "BOTH HANDS". Card: "BOTH FISTS AT ONCE".
- **Frozen:** the green, held.
- **Chen:**
  1. "Green's armored. One fist won't crack it."
  2. "Both hands, together. Catch it."
- **To advance:** both hands inside the 0.55 s window (the existing two-hand block). Chen: "That's the catch."
- **Wrong:** one hand gets the amber guard flash and a half-buzz, as in combat. If the window lapses without the second hand: "Together. Both fists at once." *(takes)* It stays pinned.

### Beat 8: Pink, the lane, the dodge

- **On screen:** a pink Spearfin comes out and paints its chevron lane across the floor toward the operator. At the moment the lane locks (the end of its telegraph, just before the charge) it stops. The lane stays at full strength. Tag: "CAN'T BE PUNCHED". Card: "STEP OUT OF THE LANE, OR DUCK".
- **Frozen:** the pink, held at lane lock. Its charge line is fixed to where the operator's head was.
- **Chen:**
  1. "Pink can't be punched."
  2. "That line is its charge."
  3. "Step out of the lane. Or duck."
- **To advance:** the operator's head moves more than 0.5 m from the charge line (a side-step or a duck). The pink is released, charges down the empty lane past them, and resolves as a dodge. Chen: "Clean dodge. It still hurts the rift."
- **Wrong:** a punch passes through with the rejected buzz. "Fists go through it. Move." *(takes)* It stays pinned until they leave the lane.

### Beat 9: A possession, on purpose

- **On screen:** a yellow arcs in and is pinned. Card: "HANDS DOWN • LET IT IN".
- **Frozen:** the yellow, held, then released by Chen.
- **Chen:**
  1. "This one I'm letting through."
  2. "Hands down. You need to feel this."
  3. (release: it lunges into the head, frost and veins close in, the view distorts, siphon sound, life force 100 to 80)
  4. "That's possession. It fed on you."
  5. "Your life force is on your wrist."
  6. "Three clear seconds, and it climbs back."
  7. "At zero, the failsafe fires. We pull you out."
- **To advance:** runs on after line 7. The operator watches the bar start to climb.
- **Wrong:** if they punch it before it gets through, it dies like any other. "Good instinct. Hands down this time." *(takes)* and another comes. If they punch the second one too: "Fine. Watch your wrist." and the drain is applied directly (`LifeForceManager.apply_damage(20)`), which still drives the frost, distortion, heartbeat, and bar. No third attempt.

### Beat 10: The rift, its health, sealing, stragglers

- **On screen:** card: "EVERY HIT DAMAGES THE RIFT". The bracer's rift hex is highlighted. The rift's own damage flash scales with the size of each hit (section 2).
- **Frozen:** nothing in play.
- **Chen:**
  1. "Every one you break hurts the rift."
  2. "Its health is on your wrist."
  3. "Hit harder, and more goes into it."
  4. "Lures hurt it most of all."
  5. "Break it, and the rift seals."
  6. "Whatever's already out still comes for you."
- **To advance:** runs on. (Line 3 only ships if punch power ships; see section 2.)

### Beat 11: A short live wave

- **On screen:** card: "SEAL THE RIFT". The rift feeds on its own timer from all four colors (interval 2.8 s, two live at once, speed 0.9, a long tell). Chen's normal combat callouts (wrong hand, possessed, life force, chain, rift weakening) are switched back on for this beat.
- **Frozen:** nothing.
- **Chen:** "Field's off. Seal it, operator."
- **The last call:** when the rift drops to 25 health or less, it stops feeding, Chen makes sure two phantoms are out, and the rift's health is trimmed to 9 so the next resolve seals it. Chen: "It's nearly shut. One more seals it." That makes the straggler lesson reliable: the second phantom is still out when the seal lands.
- **On the seal:** with a straggler out, "Sealed. That one's still coming. Finish it." With none (it possessed them first), "Sealed. Nothing left out. Clean." The round's mop-up banner ("CLEAR THE LAST ONE") shows as in a real operation.
- **To advance:** the director's `all_clear`, exactly as a real victory.
- **Wrong:** possessions are real; the training life floor holds them at 20.
- **Length:** the rift's health is trimmed to at most 100 at the start of the wave, so it lasts about 6 to 9 resolves, 40 to 60 seconds.

### Beat 12: Chen signs off

- **On screen:** quiet breach site, rift gone. Then the Training Complete panel.
- **Chen:**
  1. "That's the job, operator."
  2. "First Light is a real breach. Four rifts."
  3. "I'll be on comms. Go when ready."
- **Then:** `tutorial_completed` is saved and the panel shows TRAINING COMPLETE with **DEPLOY FIRST LIGHT** (primary), **REPLAY TRAINING**, and **MAIN MENU**.

---

## 2. Punch power

**What the code does today.** `Scripts/Player/hand_collision.gd` computes `quality = clamp((speed - 1.0) / (10.0 - 1.0), 0, 1)` and puts it in the strike dictionary. `Phantom._make_result` copies it into the result as `hit_quality`. The only reader is the hit VFX: `_resolve_from_strike` passes it as the burst intensity to `combat_vfx.gd` (`lerpf(1.8, 2.8, intensity)`). `receive_strike` does not use it for score or rift damage, `RiftManager.apply_result` takes `rift_damage` as given, and `RoundController` scores from `base_score`. Haptics are fixed per result type. **So "the harder you punch, the more energy goes into the rift" is not true today.** A 2 m/s tap and a 7 m/s cross do the same damage.

**Proposed change (smallest honest one).** Scale rift damage by punch speed, leave score alone:

- In `Phantom.receive_strike`, after the on-beat bonus, multiply rift damage by a power factor from the strike's `speed`: 0.85x at 2 m/s or slower, rising linearly to 1.3x at 6 m/s or faster, rounded once at the end (no double rounding with the 1.15 on-beat factor).
- The speed band is new constants on `Phantom` (`POWER_SOFT_SPEED` 2.0, `POWER_HARD_SPEED` 6.0, `POWER_MIN` 0.85, `POWER_MAX` 1.3), not the existing `quality`, because `quality` runs up to 10 m/s, which almost nobody reaches with a controller, so a real hard punch would only read about 0.5.
- The result carries `power` so the rift's damage flash and the hand haptic can scale with it (flash 0.5 to 1.0, haptic magnitude 0.75 to 1.0). That is what makes it readable in headset.
- Green's two-hand block uses the second hand's speed. Pink's dodge has no punch and stays at 1.0x.
- The crit stays worth more: a soft lure hit (20 x 1.15 x 0.85 = 20) still beats the hardest plain hit (10 x 1.15 x 1.3 = 15).

**This changes balance in every operation.** Rift health is unchanged, so a player who punches hard seals faster and a player who taps seals slower, by up to about 15 percent either way against today. The `expected_minutes` ranges are already estimates from the wave tables (Known Issues 6) and would be noted as predating punch power until timed headset runs replace them. The boss Maw's anchor drains on resolves too, so a hard-hitting operator shortens the boss fight slightly; its `anchor_seconds` is not changed by this.

If David does not want the balance change, beat 10 line 3 is cut and the tutorial does not claim it.

---

## 3. The freeze mechanic

**Why not the pause path.** `RoundController.pause_round` stops the round clock, the rifts, life recovery, and every phantom, and calls `set_interactions_enabled(false)` on them, which zeroes their collision layers. A paused phantom cannot be punched. The tutorial needs the opposite: one phantom still and punchable while everything else (Chen, the HUD, life recovery, the rift's animation) keeps running. So the freeze is a per-phantom hold, and the pause path stays exactly what it is: the menu button. The two compose: pausing during a held beat freezes everything as today, and resuming leaves the held phantom still held.

**The hold, on `Phantom` (base class):**

- `hold_in_reach(distance: float)`: arms the hold. The phantom flies its normal arc; on the physics frame its distance to the camera first drops to `distance` (0.95 m for Anglers, 0.9 m for the Carapace), it enters the hold. At commit speed that is at most about 8 cm of overshoot.
- While held: velocity is zero and `move_and_slide` is not called; the phase is forced to COMMIT so `is_strike_window_open` is true and alert glow is full; the body turns to face the camera so the lure stays where the punch lands; `_alive_time` does not advance (the 22 s cleanup cannot fire); `_try_possess_between` and `_on_contact_body_entered` return early, so leaning into it cannot possess; stall detection is skipped. `_process` still runs, so visuals pulse and the Carapace's block window still times out.
- A stasis ring (a thin torus in Chen's cyan around the body) shows while held, so the freeze reads as Chen's field rather than a bug.
- `signal held` fires once on entry, which is how the director knows the beat's frozen moment has arrived.
- Release on the player's action: a valid strike resolves it through the normal `receive_strike` path, which makes it terminal. Wrong-hand, one-hand, not-a-punch, and pink's `dodge_only` results leave the hold untouched.
- `release_hold()`: for beat 9 and for pink. The phantom re-locks its target on the head where it is now and builds a short straight curve with progress near the end, so it lunges at commit speed from where it stood and possesses unless struck.
- The Angler's lure placement is chosen by the director (`place_sweet_spot(face)` already exists) so beat 4 always teaches the jab spot and beat 5 the hook.

**Pink (`pink_phantom.gd`):** `hold_at_lane_lock()` arms the same hold, entered on the frame the telegraph finishes, before the charge. While held the lane is drawn at full strength from the fish to its locked target. `release_hold()` lets the charge run; the existing dodge test (passing its target) resolves it. The director decides when to release by measuring the camera's distance to the charge line, the segment from the fish through the locked target and 1.5 m past it.

**What is not frozen during a held beat:** life recovery, the round clock (training records no time), the chain timeout, Chen, music, the rift's portal animation. Only the one phantom.

---

## 4. Structure

**A tutorial director, not a catalog mission.** A new `Scripts/Core/tutorial_director.gd` (`TutorialDirector`, a node in `main.tscn`, group `TutorialDirector`) runs the beats as a small state machine: one function per beat, each awaiting Chen's lines and the operator's action through signals, with nudge timers and the soft-lock exits above. The mission catalog's wave tables cannot express "spawn this one phantom, pin it, wait for the left hand", and overloading them would leak tutorial logic into every operation.

The director still drives the real systems so the tutorial teaches the real rules:

- It starts a real round with a tutorial mission dictionary built in the director (not in `all_missions`, so it is never in Operations, the unlock chain, best scores, or best times). New mission keys, each read where it applies and ignored by every existing mission:
  - `"tutorial": true`: ChenComms skips its mission-start, first-sighting, rift-bearing, and victory lines; GameFlowController records no clear, score, or time.
  - `"countdown": 0`: `RoundController.begin_round` reads it instead of its 3 s export.
  - `"rift_ahead": true`: `RiftDirector` places the rift straight ahead at 11 m.
  - `"life_floor": 20`: `LifeForceManager` gets a `floor` that `apply_damage` clamps to, set by `begin_round` and cleared by `reset`/`abandon_round`. Training cannot fail (see open question 5).
  - Wave field `"feed": false`: `RiftManager.configure_wave` sets `feed_enabled` off, so the rift spawns only what the director asks for. The director turns it on for beat 11.
- `RiftManager.spawn_variant(variant_id)` spawns one specific phantom from the rift's mouth (a small refactor of `_spawn_phantom` to take a scene), so it is registered with the rift: its resolve damages the rift and its contact drains life, honestly.
- `ChenComms` gets `signal line_ended(event)` so the director can wait for a line to finish, and a `lock_prefix` that generalizes today's boss-only `scripted` flag: while the director holds it at `"tutorial_"`, only tutorial lines are spoken. The boss sets it to `"boss_"` instead of `scripted = true` (same behavior). During beat 11 the lock is released so her ordinary callouts play; the four `first_` sightings are marked introduced so she does not re-introduce colors the tutorial just taught.
- Tutorial lines are priority 3, cooldown 0, so she says them back to back with no drops; the director waits for `line_ended` plus a 0.25 s breath between lines.

**GameFlowController.** One new state, `STATE_TRAINING` (the scripted run, menu hidden). `STATE_TUTORIAL` stays the menu state and now shows a single **briefing card** instead of six pages: "BREACH ORIENTATION • ABOUT 5 MIN", one line on space ("Stand in the ring. Clear room to punch and step."), **BEGIN** (primary) and **BACK**. BEGIN hides the menu and hands over to the director. The director's `finished` signal ends the run and shows the Training Complete panel. `_on_round_finished` ignores rounds whose mission is a tutorial; the director owns that ending.

- **Pause:** the menu button (Esc on desktop) pauses in `STATE_TRAINING` at any beat, including the intro before the round exists. The director stops its timers and nudges; `pause_round` freezes the round if one is running. The pause panel reads RESUME TRAINING, SETTINGS, END TRAINING; End Training goes through the existing confirmation with training wording and returns to the main menu.
- **The six pages:** removed. `_tutorial_pages`, `tutorial_back`, and the paged `show_tutorial` go; the briefing card replaces them. (Open question 2 offers keeping them as a reference.)
- **Training on the main menu** opens the briefing card. On a fresh profile (`tutorial_completed` false) the Training button is the primary, highlighted one and the Deploy card's detail line reads "TRAINING RECOMMENDED FIRST • NEXT • OP-01 FIRST LIGHT".
- **Review Training on results:** the `results_training` action is wired in `_on_menu_action` but no results button sends it and `_action_belongs_to_state` rejects it in `STATE_RESULTS`, so it is dead code today. This fixes it: after a **defeat**, results show REVIEW TRAINING as a third button, which opens the briefing card.
- **Skip and replay:** End Training from pause is the skip; it does not mark training complete. Replay is always from the start (with the short replay intro in beat 1). No chapter select.
- **Gating:** `tutorial_completed` does not gate Deploy. It changes which button is primary and the Deploy detail line, nothing more (open question 1). Reset Progress keeps leaving the training record alone, as it says today.
- **Desktop:** debug builds accept Enter for the grip check in beat 2. Strike beats cannot be played with a keyboard; the play capture drives them (section 6).

---

## 5. Chen's lines

- New events in `Assets/Audio/VO/chen/chen_lines.json`, all named `tutorial_<beat>_<what>` (for example `tutorial_yellow_lure`, `tutorial_wrong_hand`), with `priority` 3, `cooldown` 0, a `tag` from the existing palette (`[focused]`, `[instructive]`, `[dry]`, `[firm]`, `[warm]` for the sign-off), and a `note` describing the moment for ElevenLabs. Narrative lines have one take; reactive lines (wrong hand, nudges, chain broke, one-hand green, punching a pink, crit landed) have two to four.
- About 50 events and 70 clips, every line under three seconds.
- Voiced with `tools/generate_elevenlabs_vo.ps1 -VoiceId wa4sQVgbDDzUDEzJwch3` (only new lines are generated; the manifest skips existing ones), then checked with `tools/check_vo.ps1 -Only <event>` per new event, and flagged clips regenerated.
- `development/Chen_VO_Script.md` is regenerated by running `tools/generate_placeholder_vo.ps1` after the ElevenLabs run: it writes placeholders only for missing files, so with every clip present it only rewrites the sheet. Note: the sheet in the repo today is stale (it lacks the sweep, jump, and boss lines); regenerating fixes that as well.
- The validation runner checks every `tutorial_` event the director references exists in the JSON and has its clip files.

---

## 6. Validation and capture

**Validation runner (`Tests/validation_runner.gd`), new checks:**

- `_validate_phantom_hold`: a yellow spawned 3 m in front of a test camera with `hold_in_reach(0.95)` enters the hold, then stays put for 120 physics steps without possessing, even with the camera moved to within 0.2 m of it; its strike window is open; a right-hand strike returns `wrong_hand` and it stays held; a left-hand strike resolves it. `release_hold()` on another held yellow ends in a possession. A pink with `hold_at_lane_lock()` holds after its telegraph, ignores a punch, and after release with the camera moved 0.6 m sideways resolves as a dodge.
- `_validate_tutorial_flow`: the director run on the test scene (round controller, rift director, life force, Chen, a test camera, scratch settings) with a test hook that skips waiting for audio and places spawned phantoms 2 m out. It asserts the beat order; that a wrong hand in beats 4 and 5 does not advance; that beat 5's left-first path and right-first path both advance; that beat 9 drains exactly 20; that the life floor holds at 20; that the live wave ends in `all_clear` with a straggler out at the seal; that completing it sets `tutorial_completed`, records no clear, score, or time; and that End Training leaves `tutorial_completed` false.
- `_validate_punch_power` (if approved): a 2 m/s and a 6 m/s left jab on a yellow give 0.85x and 1.3x rift damage; the crit at 2 m/s still beats the plain hit at 6 m/s; score is unchanged.
- The menu surface checks move from the six pages to the briefing card, the Training Complete panel, and REVIEW TRAINING on defeat results.
- The VO check above.

**Desktop play capture.** `Scripts/Debug/play_capture.gd` gets a `--tutorial` mode: it presses T, BEGIN, and Enter for the grip check, then for each strike beat waits for the director's `held` signal, saves a still, and lands the right strike by calling `receive_strike` on the held phantom (left jab on the lure, the wrong hand first in beat 5, both hands in beat 7). For pink it moves the camera 0.6 m sideways. Stills, in `reports/play/tutorial/`: intro card, ring card, rift open, yellow held with tags, blue held, chain with the bracer, green held, pink lane locked, possession frost, rift health card, live wave, straggler after the seal, Training Complete panel, plus bracer captures at the chain and possession beats.

Run:

```bash
godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn -- --tutorial --art-label=tutorial
```

---

## 7. Open questions for David

Each has a recommended default; the build follows the default unless you say otherwise.

1. **Does an unfinished tutorial gate Deploy on a fresh install?** Default: no hard gate. Training is the highlighted button and Deploy says "TRAINING RECOMMENDED FIRST" until it is done. Alternative: the first Deploy on a fresh profile routes into the briefing card with a Skip button.
2. **The six menu pages.** Default: remove them; the briefing card replaces them. Alternative: keep them as a one-screen "Field Manual" reference reachable from the briefing card.
3. **Possession on purpose or a near miss?** Default: on purpose (beat 9), because frost, distortion, and recovery are only learned by seeing them. Near miss would show none of it.
4. **Punch power.** Default: build it as in section 2 (rift damage 0.85x to 1.3x between 2 and 6 m/s, score unchanged), accepting the balance shift in every operation. Alternative: leave damage alone and cut the claim from Chen's lines.
5. **Can training fail?** Default: no. A life floor of 20 holds the operator in; Chen's failsafe line explains what would happen. Alternative: let it fail, with the real failsafe and a "retry from the live wave" option.
6. **Blue's deliberate wrong hand.** Default: Chen asks for the left first, and a right-first hit is accepted with a line. Alternative: only correct a wrong hand if it happens.
7. **Freeze presentation.** Default: in fiction (Chen pins it in her field), with a cyan stasis ring and floating tags ("LURE", "LEFT HAND", "BOTH HANDS", "CAN'T BE PUNCHED"). Alternative: no tags, Chen's voice and the bracer caption only.
8. **Replay and skip.** Default: replays run from the start with a one-line intro; End Training from pause is the skip and does not count as completion; no chapter select.
9. **REVIEW TRAINING on results.** Default: on defeat results only. Alternative: on every results screen.
10. **Voice.** Default: once you approve the line drafts, generate them all with ElevenLabs on the current Chen voice and run the transcription check. Alternative: build with captions only first and voice after a headset pass on the script.
11. **Where the tutorial sits.** Default: its own "Training" entry, outside the Operations list and the unlock chain, before OP-01. Alternative: list it as OP-00 in Operations.
