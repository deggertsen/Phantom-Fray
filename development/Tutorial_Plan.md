# Tutorial Plan: Dr. Chen's Training Chamber

**Status:** approved by David on 2026-10-13, built, and voiced (see Production_Status.md). His second review renamed the player (Recruit, then Striker), added the glove check, and set the line style below.
**Written:** 2026-10-13, against the code on `main` at ffe1477.

Today's Training is six text pages on the menu panel (`_tutorial_pages` in `Scripts/Core/game_flow_controller.gd`, `show_tutorial` in `Scripts/UI/vr_menu_panel.gd`). This plan replaces it with a played scenario. Dr. Chen introduces herself over comms. The recruit stands in an RSF training chamber where every rift and phantom is a hologram. Chen walks them through everything they meet in a fight, and at the moment a phantom would be punched she pauses the hologram so she can say what matters. It waits there until the recruit does the right thing.

The six campaign operations stay as they are. They remain the extended on-ramp described in the roadmap; this is the first five minutes before them.

## Decisions (David, 2026-10-13)

1. **No gate.** An unfinished tutorial does not block Deploy. Training is the highlighted button on a fresh profile.
2. **The six pages go.** The tutorial replaces them. Menu changes are at my discretion; a full menu revamp is coming, so the menu work here stays small.
3. **Possession on purpose.** Chen lets one through so life force, the drain, and recovery are seen.
4. **Punch power ships.** Players need to be taught the difference a harder punch makes, so it is taught with a hands-on demonstration, not just a line.
5. **Training cannot fail.** A life force floor keeps the recruit in.
6. **No deliberate wrong hand.** Teach the right way; correct a wrong hand only when it happens.
7. **A training facility of holograms.** The recruit should feel they are in a simulation, seeing holograms rather than the real thing. A freeze is the hologram pausing.
8. **Replay is the whole thing.** A replay plays exactly as for a new player. Ending training from the pause menu marks it complete; nobody is forced through the full tutorial.
9. **Review Training on results** (the after-action report when an operation ends): yes, after a failed operation.
10. **Voice:** David reviews the line drafts first, then all of them are generated with ElevenLabs.
11. **Where it sits:** try something; adjust later if it does not land.
12. **Recruit, then Striker** (second review). Chen no longer says "operator". She calls the player "Recruit" in training and "Striker", a member of the Resonance Strike Force, from the first operation on; her sign-off makes sealing First Light the promotion. Menus and docs follow. The "Operator" difficulty tier keeps its name for now.
13. **The glove check** (second review). After the possession, Chen asks the recruit to look at their left glove and waits until they do, so they learn the display there carries information.
14. **Line style** (second review). No mention of recentering. "Fist", never "grip" or a button, so the script works with hand tracking. Fuller sentences that say why ("Different energy signatures in each hand", "No real phantoms here"). The introduction is a full paragraph on who Chen is and what the world faces.

---

## 1. Beat list

Thirteen beats, about five minutes for a player who does everything right first time. Every beat has a way forward for a player who keeps getting it wrong, so the tutorial can never soft-lock.

Conventions:

- **Paused** means the per-phantom hold in section 3: the hologram stops mid-motion, in reach and punchable, unable to possess.
- **Card** is a floating text card about 2 m ahead and below eye line naming the one thing to do.
- **Tag** is a floating label beside a paused phantom ("LURE", "LEFT HAND", "BOTH HANDS"), pointing at the part that matters.
- **Nudge**: if the recruit does nothing useful for 8 seconds, Chen repeats the instruction with another take, again at 16 s.
- Chen's lines are listed by event name; the text is in section 5.

### The chamber

While training runs, the breach site is replaced by the training chamber: a dark holographic dome over the play space, its grid lines in Chen's cyan, hiding the dead city and the sky. The existing "RSF // ERM TRAINING CHAMBER 07" sign in the arena (Known Issues 3 calls it wrong for the breach site) shows only in the chamber, which fixes that issue for the operations. Every phantom and the rift carry a hologram treatment: scanlines climbing through the body and a faint flicker, in their own species colors so yellow, blue, green, and pink still read exactly as they will in a real fight.

### Beat 1: Chen introduces herself

- **On screen:** the chamber, empty. Menu hidden. Bracer reads "TRAINING", full life force. Card: "DR. ELARA CHEN // RSF SCIENCE LEAD".
- **Chen:** `tutorial_hello` (one long speech: who she is, the Breach, the phantoms, the Overseer, the gauntlets, why it is up close and personal, and that Strikers close the rifts; the wrist caption pages through it), `tutorial_chamber`, `tutorial_pause_power`.
- **To advance:** runs on. Pause works throughout (section 4).

### Beat 2: Play space

- **On screen:** the floor's safe ring pulses. Card: "STAND IN THE RING • MAKE FISTS WHEN READY". Nothing mentions recentering.
- **Chen:** `tutorial_ring`, `tutorial_fists` (also the nudge).
- **To advance:** both fists made (on controllers, both grips held) for half a second. Desktop debug builds: Enter. Every line and card talks about fists, not controller buttons, so hand tracking can use the same script.
- **Wrong:** nothing happens; nudge.

### Beat 3: The rift loads

- **On screen:** the round begins. A holographic rift draws itself in dead ahead at 11 m with its beacon. Banner: "TRAINING CHAMBER 07".
- **Paused:** the rift feeds nothing on its own timer. Chen decides what comes through.
- **Chen:** `tutorial_rift_open`.

### Beat 4: Grip and strike, the yellow Angler, the lure

- **On screen:** one yellow Angler comes out of the rift, slow and with a long tell, and arcs in from the left. About 0.95 m from the face it pauses mid-flap, the hologram frozen and tinted. Its lure sits in front of its mouth (the jab spot). Tags: "LEFT HAND", "LURE". Card: "LEFT HAND • GRIP, THEN PUNCH THROUGH THE LURE".
- **Chen:** `tutorial_paused`, `tutorial_yellow_left`, `tutorial_fist_punch`, `tutorial_lure`, `tutorial_lure_crit`.
- **To advance:** a valid left-hand strike. `tutorial_crit_landed` on a lure hit, `tutorial_plain_landed` otherwise.
- **Wrong:** right hand: the lure flashes red, the hand buzzes, it stays paused, `tutorial_wrong_hand`. Grip without a punch or a slow push registers nothing; nudge `tutorial_strike_nudge`.

### Beat 5: Blue Angler

- **On screen:** a blue arcs in from the right and pauses, lure out on its right (the hook spot). Tags: "RIGHT HAND", "LURE". Card: "RIGHT HAND • HOOK THE LURE".
- **Chen:** `tutorial_blue_right`, `tutorial_hook`.
- **To advance:** a valid right-hand strike, with the crit or plain line.
- **Wrong:** as beat 4.

### Beat 6: The chain

- **On screen:** the bracer's multiplier gets a pulsing frame for this beat. Card: "THREE CLEAN HITS IN A ROW".
- **Paused:** nothing. The first live beat: yellow, blue, yellow, one at a time, each sent as the last resolves, at speed 0.8.
- **Chen:** `tutorial_chain`, `tutorial_chain_live`.
- **To advance:** three valid resolves in a row, then `tutorial_chain_done`.
- **Wrong:** a wrong hand or a possession breaks the chain (the real rules): `tutorial_chain_broke` and the count restarts. After the third broken attempt: `tutorial_chain_enough` and on.

### Beat 7: Green Carapace, the two-hand catch

- **On screen:** a green comes in low and fast and pauses at chest height, body widened. Tag: "BOTH HANDS". Card: "BOTH FISTS AT ONCE".
- **Chen:** `tutorial_green`, `tutorial_green_both`.
- **To advance:** both hands inside the 0.55 s window, then `tutorial_green_done`.
- **Wrong:** one hand gets the amber guard flash and half-buzz; if the window lapses, `tutorial_green_one`. It stays paused.

### Beat 8: Pink Spearfin, the lane, the dodge

- **On screen:** a pink paints its chevron lane toward the recruit and pauses at the moment the lane locks, just before the charge. The lane stays at full strength. Tag: "CAN'T BE PUNCHED". Card: "STEP OUT OF THE LANE, OR DUCK".
- **Chen:** `tutorial_pink`, `tutorial_pink_lane`, `tutorial_pink_move`.
- **To advance:** the recruit's head moves more than 0.5 m from the charge line. The hologram resumes, charges down the empty lane, and resolves as a dodge: `tutorial_pink_done`.
- **Wrong:** a punch passes through with the rejected buzz, `tutorial_pink_punch`. It stays paused until they leave the lane.

### Beat 9: A possession, on purpose

- **On screen:** a yellow arcs in and pauses. Card: "HANDS DOWN • LET IT IN".
- **Chen:** `tutorial_let_in`, `tutorial_hands_down`. The hologram resumes and lunges into the head: the impact distortion and possession flash, the siphon sound, life force 100 to 80 with the bracer's life bar framed. (Frost and veins only close in below 70, so a single possession does not bring them; Chen's failsafe line covers what comes after.) Then `tutorial_possessed`, and the glove check: card "LOOK AT YOUR LEFT GLOVE", `tutorial_glove_check`, and Chen waits until the recruit looks at the display on their left glove (within 0.9 m and 30 degrees of the middle of their view, for 0.4 s), then `tutorial_glove_seen`. If they have not looked after 8 s, `tutorial_glove_nudge`; after another 8 s she moves on. Then `tutorial_recover` and `tutorial_failsafe`.
- **To advance:** runs on; the recruit sees the bar start to climb.
- **Wrong:** if they punch it first, `tutorial_let_in_again` and another comes. If they punch that too, `tutorial_watch_glove` and the drain is applied directly (`LifeForceManager.apply_damage(20)`), which still drives the distortion, the drain blip, and the bar.

### Beat 10: The rift and its health

- **On screen:** card: "EVERY HIT DRAINS THE RIFT". The bracer's rift hex gets a pulsing frame.
- **Chen:** `tutorial_rift_damage`, `tutorial_rift_glove`, `tutorial_seal`, `tutorial_stragglers`.

### Beat 11: Punch power

The hands-on lesson David asked for.

- **On screen:** a yellow arcs in and pauses. Card: "TAP IT LIGHTLY". Every resolve in this beat pops a damage readout at the strike point ("RIFT −9") and the rift's damage flash scales with the hit.
- **Chen:** `tutorial_power_intro`, `tutorial_power_soft`. After the tap lands: a second yellow pauses, card "NOW HIT IT HARD", `tutorial_power_hard`.
- **To advance:** the hard hit does more rift damage than the tap. Then `tutorial_power_seen` and `tutorial_power_lure`.
- **Wrong:** a tap that lands hard (power 0.5 or more) gets `tutorial_power_lighter` and another yellow, up to three. If the hard hit does not beat the tap, `tutorial_power_again` and another, up to three. After that, Chen moves on with `tutorial_power_seen` anyway (the readouts have shown the numbers).

### Beat 12: A short live wave

- **On screen:** card: "SEAL THE RIFT". Damage readouts stay on. The rift feeds on its own timer from all four colors (interval 2.8 s, two live at once, speed 0.9, a long tell). Chen's normal combat callouts (wrong hand, possessed, life force, chain, rift weakening) are switched back on.
- **Chen:** `tutorial_live`.
- **The last call:** when the rift drops to 25 health or less, it stops feeding, Chen makes sure two phantoms are out, and the rift's health is trimmed to 9 so the next resolve seals it: `tutorial_last_one`. That makes the straggler lesson reliable.
- **On the seal:** with a straggler out, `tutorial_straggler`; with none, `tutorial_sealed_clean`. The mop-up banner shows as in a real operation.
- **To advance:** the director's `all_clear`, exactly as a real victory.
- **Length:** the rift's health is trimmed to at most 100 when the wave starts, so it lasts about 6 to 9 resolves, 40 to 60 seconds.

### Beat 13: Chen signs off

- **Chen:** `tutorial_signoff_job`, `tutorial_signoff_real`, `tutorial_signoff_comms`.
- **Then:** `tutorial_completed` is saved and the panel shows TRAINING COMPLETE with **DEPLOY FIRST LIGHT** (primary), **REPLAY TRAINING**, and **MAIN MENU**.

---

## 2. Punch power

**What the code does today.** `Scripts/Player/hand_collision.gd` computes `quality = clamp((speed - 1.0) / (10.0 - 1.0), 0, 1)` and puts it in the strike dictionary. `Phantom._make_result` copies it into the result as `hit_quality`. The only reader is the hit VFX: `_resolve_from_strike` passes it as the burst size to `combat_vfx.gd`. `receive_strike` does not use it for score or rift damage, `RiftManager.apply_result` takes `rift_damage` as given, and `RoundController` scores from `base_score`. Haptics are fixed per result type. So "the harder you punch, the more energy goes into the rift" was not true.

**The change.**

- In `Phantom.receive_strike`, rift damage is multiplied by a power factor from the strike's `speed`: 0.85x at 2 m/s or slower, rising linearly to 1.3x at 6 m/s or faster, applied with the on-beat 1.15x and rounded once.
- The band is new constants on `Phantom` (`POWER_SOFT_SPEED` 2.0, `POWER_HARD_SPEED` 6.0, `POWER_MIN` 0.85, `POWER_MAX` 1.3), not the existing `quality`, which runs up to 10 m/s, so a real hard punch with a controller would only read about 0.5.
- The result carries `power` (0 to 1). The rift's damage flash scales with it (0.5 to 1.0) and so does the hand haptic (0.75 to 1.0 of today's strength). That is what makes it felt in headset outside the tutorial too.
- Green's two-hand block uses the second hand's speed. Pink's dodge has no punch and stays at 1.0x.
- Score is unchanged.
- The crit stays worth more: a soft lure hit (20 x 1.15 x 0.85 = 20) beats the hardest plain hit (10 x 1.15 x 1.3 = 15).

**Balance.** Rift health is unchanged, so a hard puncher seals faster and a tapper slower, by up to about 15 percent either way against today, in every operation. The `expected_minutes` ranges were already estimates (Known Issues 6); that entry notes they predate punch power. The boss Maw's anchor drains on resolves too, so hard hitting shortens the boss fight slightly.

---

## 3. The freeze: pausing the hologram

**Why not the pause path.** `RoundController.pause_round` stops the round clock, the rifts, life recovery, and every phantom, and calls `set_interactions_enabled(false)` on them, which zeroes their collision layers: a paused phantom cannot be punched. The tutorial needs one phantom still and punchable while Chen, the HUD, and life recovery keep running. So the freeze is a per-phantom hold. The menu-button pause stays what it is, and composes: pausing during a held beat freezes everything as today, and resuming leaves the held phantom held.

**The hold, on `Phantom`:**

- `hold_in_reach(distance)`: arms the hold. The phantom flies its normal arc and enters the hold on the first physics frame it is within `distance` of the camera (0.95 m for Anglers, 0.9 m for the Carapace). At commit speed that is at most about 8 cm of overshoot.
- While held: no movement; the phase is COMMIT, so strikes count; alert glow full; it turns to face the camera so the lure stays where the punch lands; `_alive_time` does not advance, so the 22 s cleanup cannot fire; `_try_possess_between` and `_on_contact_body_entered` return early, so leaning into it cannot possess; stall detection is skipped.
- The hologram pauses: the creature shader gets a `frozen_time` uniform that stops its sway and flap on the frame it was held, and its scanlines stop and tint toward Chen's cyan.
- `signal held` fires once on entry; the director waits on it.
- A valid strike resolves it through the normal `receive_strike` path. Wrong-hand, one-hand, not-a-punch, and pink's `dodge_only` results leave it held.
- `release_hold()` (beat 9, and pink): the phantom re-locks on the head where it is now and lunges from where it stood at commit speed, possessing unless struck.
- The Angler's lure is placed by the director with the existing `place_sweet_spot(face)`, so beat 4 teaches the jab spot and beat 5 the hook.

**Pink:** `hold_at_lane_lock()` arms the same hold, entered on the frame the telegraph finishes, before the charge. The lane stays at full strength. On release the existing dodge test resolves it once it passes its target. The director releases it when the camera is more than 0.5 m from the charge line (the fish, through its locked target, and 1.5 m past).

**The hologram look** is a `hologram` uniform on the creature shader (scanlines climbing through the body, a faint flicker), set on every phantom the training rift spawns, and the same treatment on the training rift's portal. It is off in every operation.

---

## 4. Structure

**A tutorial director, not a catalog mission.** A new `Scripts/Core/tutorial_director.gd` (`TutorialDirector`, a node in `main.tscn`) runs the beats: one coroutine per beat, awaiting Chen's lines and the recruit's actions through signals, with nudge timers and the exits above. The catalog's wave tables cannot say "send this one phantom, pause it, wait for the left hand", and overloading them would leak tutorial logic into every operation.

The director drives the real systems so the tutorial teaches the real rules:

- It starts a real round with a training mission dictionary built in the director, not in `all_missions`, so it is never in Operations, the unlock chain, best scores, or best times. New mission keys, each ignored by every existing mission:
  - `"tutorial": true`: ChenComms skips its mission-start, first-sighting, rift-bearing, and victory lines; GameFlowController records no clear, score, or time.
  - `"countdown": 0`: `RoundController.begin_round` reads it instead of its 3 s export.
  - `"rift_ahead": true`: `RiftDirector` places the rift straight ahead at 11 m.
  - `"life_floor": 20`: `LifeForceManager.apply_damage` never takes life below it. Training cannot fail.
  - `"hologram": true`: the rift and everything it spawns wear the hologram look.
  - Wave field `"feed": false`: the rift spawns only what the director asks for; the director turns the feed on for beat 12.
- `RiftManager.spawn_variant(variant_id)` sends one specific phantom out of the rift's mouth, registered with the rift, so its resolve damages the rift and its contact drains life.
- `ChenComms` gets `signal line_ended(event)` and a `lock_prefix` that generalizes the boss's `scripted` flag: while it is `"tutorial_"` only tutorial lines are spoken. The boss sets `"boss_"` instead of `scripted = true`, same behavior. During beat 12 the lock is released so her ordinary callouts play, with the four `first_` sightings marked as already introduced.
- Tutorial lines are priority 3, cooldown 0; the director waits for `line_ended` plus a 0.25 s breath between lines.
- A `TrainingChamber` presentation node (in `Scripts/Presentation/`) builds the dome, shows the chamber sign, and hides the city while training runs.

**GameFlowController.** A new `STATE_TRAINING` (the scripted run, menu hidden). The Training button goes straight in: the tutorial itself handles the play space in beat 2, so there is no briefing page. The director's `finished` signal shows the Training Complete panel. `_on_round_finished` ignores the training round; the director owns that ending.

- **Pause:** the menu button (Esc on desktop) pauses at any beat, including the intro before the round exists. The pause panel reads RESUME TRAINING, SETTINGS, END TRAINING. End Training needs no confirmation in training, marks training complete, and returns to the main menu.
- **The six pages** and `tutorial_back` are removed, along with the paged `show_tutorial`.
- **Main menu:** on a fresh profile the Training button is the primary one, and the Deploy detail reads "TRAINING RECOMMENDED FIRST". After training it goes back to today's layout.
- **Results (the after-action report shown when an operation ends):** the `results_training` action is wired in `_on_menu_action`, but no button sends it and `_action_belongs_to_state` rejects it in `STATE_RESULTS`, so it is dead code. Pending David's answer, the default is a REVIEW TRAINING button after a **defeat** only.
- **Replay** plays the whole tutorial, identical to a first run.
- **Gating:** none. Reset Progress keeps leaving the training record alone.
- **Desktop:** debug builds accept Enter for the fists check in beat 2. Strike beats cannot be played with a keyboard; the play capture drives them (section 6).

---

## 5. Chen's lines

Every line is its own event in `Assets/Audio/VO/chen/chen_lines.json`, priority 3, cooldown 0, with a tag and a note for ElevenLabs. Lines marked with two or more are takes for repeats. Chen calls the player "Recruit" throughout training; from the first operation on she calls them "Striker". The lines say "fist", never "grip" or a button, so hand tracking can use the same script. Combat lines stay under three seconds; training lines run longer where they explain something, because the action is paused while she talks, and the introduction is one long speech the wrist caption pages through.

| Event | Line(s) |
|---|---|
| `tutorial_hello` | Recruit, this is Dr. Elara Chen, science lead for the Resonance Strike Force. Years ago, my experiments tore the first holes between our world and another. We call that day the Breach. Phantoms have poured through the rifts ever since. They feed on life force, and our weapons pass straight through them. Whole cities have gone cold, and something on the other side is aiming them. We call it the Overseer. The gauntlets on your hands are my answer. They turn your own life force into a weapon, so this fight is up close and personal. Strikers close the rifts. I'll be in your ear the whole way. |
| `tutorial_chamber` | This is the training chamber. All holograms. No real phantoms here. |
| `tutorial_pause_power` | I can pause them mid-strike. Real phantoms won't wait for you. |
| `tutorial_ring` | Stand in the ring, and give yourself room to swing. |
| `tutorial_fists` | Make fists when you're ready. / Show me your fists when you're ready. |
| `tutorial_rift_open` | Loading a rift. Phantoms come through these. |
| `tutorial_paused` | There. Paused. Take a good look at it. |
| `tutorial_yellow_left` | Yellow requires your left gauntlet. Different energy signatures in each hand. |
| `tutorial_fist_punch` | Hold a fist, then punch through it. |
| `tutorial_lure` | See the light on its stalk? That's the lure. Aim for it. |
| `tutorial_lure_crit` | Hit the lure and you land a resonance crit. It does far more damage. |
| `tutorial_crit_landed` | Crit. That's the one you want. / Right on the lure. Good. |
| `tutorial_plain_landed` | It's down. Next time, aim for the lure. / Good. Go for the light next time. |
| `tutorial_wrong_hand` | Wrong gauntlet. Match the color to the hand. / Wrong energy signature. Use the other hand. |
| `tutorial_strike_nudge` | Make a fist, and snap it through. / Harder. Punch right through it. / Close your fist, then swing. |
| `tutorial_blue_right` | Blue requires your right gauntlet. |
| `tutorial_hook` | This lure hangs out to the side. Hook it. |
| `tutorial_chain` | Every clean hit builds your chain. |
| `tutorial_chain_live` | Now I'll run them live. Three clean hits in a row. |
| `tutorial_chain_broke` | Chain's broken. Again. / That breaks the chain. Start over. |
| `tutorial_chain_done` | That's a chain. It multiplies your score. |
| `tutorial_chain_enough` | Close enough. You'll build it out there. |
| `tutorial_green` | Green is armored. You need energy from both gauntlets to crack it. |
| `tutorial_green_both` | Use both fists, together. Catch it. |
| `tutorial_green_one` | Together. Both fists at the same time. / One fist isn't enough. Both at once. |
| `tutorial_green_done` | That's the catch. |
| `tutorial_pink` | Pink can't be punched, but their energy in our world fades quickly. Just dodge them. |
| `tutorial_pink_lane` | That line on the floor is its charge path. |
| `tutorial_pink_move` | Step out of the lane, or duck under it. |
| `tutorial_pink_punch` | Your fists go right through it. Move. / Don't punch it. Get out of the line. |
| `tutorial_pink_done` | Clean dodge. That still drains the rift. |
| `tutorial_let_in` | This next one, I'm letting through. |
| `tutorial_hands_down` | Hands down. The gauntlets will simulate the hit. |
| `tutorial_possessed` | That's a possession. It fed on your life force. |
| `tutorial_glove_check` | Look at your left glove. That's your life force. |
| `tutorial_glove_nudge` | Raise your left hand and look at the glove. |
| `tutorial_glove_seen` | That's it. Check it whenever you can in a fight. |
| `tutorial_recover` | Stay clear for three seconds, and it climbs back. |
| `tutorial_failsafe` | If it hits zero, the failsafe fires and we pull you out. |
| `tutorial_let_in_again` | Good instinct. Hands down this time. / I said let it in. Hands down. |
| `tutorial_watch_glove` | Fine. I'll simulate it myself. Watch your left glove. |
| `tutorial_rift_damage` | Every phantom you break drains the rift. |
| `tutorial_rift_glove` | Its strength is on your left glove too, under your life force. |
| `tutorial_seal` | Drain it completely, and the rift seals. |
| `tutorial_stragglers` | But whatever's already come through still comes for you. |
| `tutorial_power_intro` | How hard you hit matters. |
| `tutorial_power_soft` | Tap this one. Lightly. |
| `tutorial_power_lighter` | Lighter than that. Just a tap. |
| `tutorial_power_hard` | Now hit it like you mean it. |
| `tutorial_power_again` | Harder than that. Again. / Put your whole body into it. |
| `tutorial_power_seen` | See the difference? Harder hits drain the rift faster. |
| `tutorial_power_lure` | And a lure hit beats them all. |
| `tutorial_live` | Unpausing everything. Seal that rift, recruit. |
| `tutorial_last_one` | It's nearly shut. One more seals it. |
| `tutorial_straggler` | Sealed. But that one's still coming. Finish it. |
| `tutorial_sealed_clean` | Sealed, and nothing left out. Clean. |
| `tutorial_signoff_job` | That's the job, recruit. |
| `tutorial_signoff_real` | First Light is a real breach. No pausing out there. |
| `tutorial_signoff_comms` | Seal it, and you're a Striker. I'll be on comms the whole way. |

59 events, 70 clips. Voiced on 2026-10-13 with `tools/generate_elevenlabs_vo.ps1 -VoiceId wa4sQVgbDDzUDEzJwch3` (only new lines are generated), checked with `tools/check_vo.ps1 -Only <event>`, flagged clips regenerated, and `development/Chen_VO_Script.md` rewritten by `tools/generate_placeholder_vo.ps1`, which only fills missing files and so just rewrites the sheet. The sheet in the repo is stale (no sweep, jump, or boss lines); this fixes that too.

Until the clips exist, ChenComms already captions a missing clip and holds its time, so the tutorial runs captioned.

---

## 6. Validation and capture

**Validation runner (`Tests/validation_runner.gd`):**

- `_validate_phantom_hold`: a yellow 3 m in front of a test camera with `hold_in_reach(0.95)` enters the hold, then stays put for 120 physics steps without possessing, even with the camera moved within 0.2 m of it; its strike window is open; a right-hand strike returns `wrong_hand` and it stays held; a left-hand strike resolves it. `release_hold()` on another ends in a possession. A pink with `hold_at_lane_lock()` holds after its telegraph, ignores a punch, and after release with the camera 0.6 m to the side resolves as a dodge.
- `_validate_punch_power`: 2 m/s and 6 m/s left jabs on a yellow give 0.85x and 1.3x rift damage; the soft crit still beats the hard plain hit; score unchanged.
- `_validate_tutorial_flow`: the director on a test scene (round controller, rift director, life force, Chen, a test camera, scratch settings), with a test hook that skips waiting on audio and starts spawns close. It asserts the beat order; that a wrong hand in beats 4 and 5 does not advance; that the green needs both hands; that pink waits for the camera to leave the lane; that beat 9 drains exactly 20; that the life floor holds; that the power beat compares the two hits; that the live wave ends in `all_clear` with a straggler out at the seal; that completing it sets `tutorial_completed` and records no clear, score, or time; and that End Training also sets `tutorial_completed`.
- Menu checks move from the six pages to the Training Complete panel, the training pause panel, and REVIEW TRAINING on defeat results.
- Every `tutorial_` event the director uses exists in the JSON.

**Desktop play capture.** `Scripts/Debug/play_capture.gd` gets a `--tutorial` mode. It presses T and Enter (the fists check), then for each beat waits for the director's `held` signal, saves a still, and lands the right strike by calling `receive_strike` on the held phantom with a scripted speed (soft then hard in the power beat). For pink it moves the camera 0.6 m sideways. Stills go to `reports/play/tutorial/`.

```bash
godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn -- --tutorial --art-label=tutorial
```

---

## 7. Still open

- Nothing blocking. The headset checks are in Known_Issues.md item 7.
