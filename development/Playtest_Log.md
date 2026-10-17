# Playtest Log

One entry per headset session. Keep it short; the point is that the verdicts survive the session. Numbers tuned afterwards go in the commit message, with a link back to the entry.

## Template

```
### YYYY-MM-DD — <tester or "self">, <headset>, <build or commit>
Operations played:
Felt good:
Felt wrong:
Confusions (things the tester asked or got wrong without being told):
Comfort (nausea, strain, boundary):
Numbers to try:
```

## Standing verdicts (sessions before 2026-10-08, unrecorded)

Developer sessions on Quest 3 across the September and October builds. No per-session notes exist; these are the conclusions that drove the roadmap.

- Combat feels fun. Punch timing, lure placement, block and dodge read well.
- A full run of all six operations takes about 20 minutes.
- The campaign reads as a tutorial. Nothing invites a second run.
- No narrative hook. Chen's lines are flavor; nothing is at stake beyond the current rift.
- The strike-window rule (hits count once the phantom is in reach) has not felt like a problem to the developer. Still to be checked with testers who have not been told the rule.
- Results pointer selection after defeat was unreliable before the 2026-10-03 and 2026-10-04 fixes. Not yet retested.

## Sessions

### 2026-10-09 — self, Quest 3, debug build with the SquatDetector overlay (ef96a58, then eec4d01)

Exercise exploration tests 1 to 3 (`Exercise_Mechanics_Exploration.md`, section 3), read from `SQUAT` logcat lines.

- **Calibration (test 1):** standing eye height read 1.66 m, settling to 1.62 to 1.64 m. No head-height jump on recenter. Measured floor-to-eye height not yet taken.
- **Squats (test 2), detector as built (20 % depth, -50° pitch, 1.0 travel per drop):** 20 of 20 squats counted (drops of 73 to 86 cm, travel per drop 0.04 to 0.15, eyes never below -5°). **13 of 17 waist bends counted**: a bend crosses the squat line with the eyes level, looks down only afterwards, and moves the head almost straight down (travel per drop under 0.3). 2 of 9 side-step ducks counted (travel per drop 0.82 to 2.44). 0 of 6 shallow ducks (deepest 20 %).
- **Fix (eec4d01):** a dip is judged again over the whole dip; pitch limit -30°, travel per drop 0.5, squat depth 25 %. Against the recorded numbers that counts 20 of 20 squats and none of the bends, side ducks, or shallow ducks. **Not yet re-checked on the headset.**
- **Jump signal (test 3):** 10 jumps peaked at 1.89 to 2.15 m/s upward, head 21 to 31 cm above standing, 0.39 to 0.50 s up. 10 calf raises peaked at 0.30 to 0.54 m/s, 4 to 10 cm. Separation about 1.35 m/s against the 0.3 m/s needed: jump detection from head tracking alone is viable. Suggested rule: peak upward speed of 1.0 m/s or more.
- **Performance:** the tutorial Maw's close dropped to 20 fps as the glimpse tentacle first drew (shader compiled on the spot). Fixed in eec4d01 by prewarming the boss and hazard shaders; not yet re-checked.
- **Launch notes:** launching over adb with the headset off shows Meta's "controllers required" dialog until the controllers are picked up. Debug missions launch without a keyboard through the intent extra, e.g. `adb shell am start -n com.phantomfray.resonancerising/com.godot.game.GodotAppLauncher --esa command_line_params --mission=sweep_drill` (the extra name is in the Godot Android library; untried).

**Still to run:** the re-check of bends, side ducks, and squats on eec4d01; the measured eye height; the Sweep Drill (Step 4); the boss Maw with `--mission=the_maw_boss,--maw-breaks`; the glimpse at 90 fps. Hand tracking tests 7 and 8 ran on 2026-10-14 and 2026-10-17 (entry below). For the overlay and `SQUAT` lines, set `debug_enabled` on the Player's SquatDetector before building; it is off in the committed scene.

### 2026-10-11 — self, Quest 3, debug builds eec4d01 through 82a5fee

Squat re-checks, the Sweep Drill, and three runs of the boss Maw, read from `SQUAT` and `PUSHUP` logcat lines. Launch arguments now go in `user://debug_args.txt` (see `GameFlowController._debug_args_file`).

- **Squats and bends:** on eec4d01, 5 of 5 squats counted and 2 of 5 waist bends slipped through with the eyes only 18 to 29 degrees down. David then bowed while looking up at an opponent, which pitch cannot see. The early-arc check (head travel from where the descent began, over the fall, once 8 % of standing height down) measured bows at 0.81 to 1.01 and calm squats at 0.16 to 0.20. Under a live sweep squats leaned more (0.29 to 0.50) and one was called a bow, so the limit sits at 0.75: David would rather let a sloppy bow through than reject a real squat.
- **Sweep Drill:** 4 of 4 sweeps cleared, flawless. "Very cool"; it will be better with a tentacle than a bar. The first sweep dropped to 66 fps generating its sounds; they are built during the menu now.
- **Boss Maw, run 1:** "epic". Sweeps too slow (2.3 to 3.5 s from tell to pass, time to squat and wait), volleys from overhead, slams unreadable, the turn "ok, not amazing", no voice for Chen's boss lines (captions only), pacing slow, push-ups not counted. The bow check also called nearly every boss squat a bow: it measured from where the player last stood fully tall, which side-steps and a ready stance made stale.
- **Run 2:** sweeps "perfect" at 1.6 to 1.7 s. Volleys still high (the escort band was measured from the rift, whose base floats 2.2 m up, and the tear lifted the mouth). The ring-shaped light wall did not read. Rumble in the turn did not help much; the phantoms suddenly reversing is the most dramatic beat. Push-ups counted only with the face down; looking forward held it on the 30 degree line.
- **Run 3:** tentacle now drawn in front of the rift (the portal shader ignored depth), but its root does not sit in the mouth, so it seems to come out of nothing. Push-ups looking forward counted: 10 clean reps in a window (head travel 22 to 38 cm, face 16 to 28 degrees down); entering and leaving the plank added 8 to 9 cm wobbles, now below the 12 cm rep line.
- **Still open:** the tentacle's root in the mouth; the slam lane and curtain and the lower escort band not yet judged in a run; ideas for the turn (brainstorm in progress, no changes yet); Chen's voice lines (the ElevenLabs key on this machine is rejected as invalid); the feint (hold a sweep while the player is already crouched) is proposed, not agreed; hand tracking tests 7 and 8 (run since, entry below).

### 2026-10-11 (evening) and 2026-10-13 — self, Quest 3, debug builds 4935549 and 1e2cb39

- **Entrance run (4935549):** the eye looked "odd rather than scary" and was removed. The tentacles prying the Maw open landed; David asked for them to hold the rim through the fight, which 1e2cb39 does. The narrower (0.7 m), faster slam "feels right". Chen's voice lines played for the first time.
- **Verdict:** "the boss fight is pretty solid at this point"; the missing piece was jumping, built in 1e2cb39 (a jump pair of low sweeps per cycle). **The jump build has not been played on the headset yet** (the Quest was not connected when it finished).

### 2026-10-14 and 2026-10-17 — self, Quest 3, handtest builds d8455cf and d2fb982
Tests 7 and 8 (hand tracking build, `tools/build_quest_debug.ps1 -HandTrackingTest`), room lit, read from `HANDTEST` logcat lines (the overlay header was not visible to David, so nothing was read off it). Raw logs in the session notes folder (`handtest_2026-10-14`).
Test 7, simultaneous off, frequency high (Fast Motion Mode), controllers put down:
  Right: jabs counted 7/7, hooks 6/7 (1 dropped), uppercuts 6/6 with 3 dropped; dropped 4; drops 4; jumps 12
  Left:  jabs counted 5/7, hooks 5/7 (2 dropped), uppercuts 4 dropped (10 punch events, several made by pose jumps); dropped 6, missed about 4; jumps 16
  Typical peak speed per punch type (rep / calc): jabs 3.3 to 7.9 m/s right, 7 to 10 left. Hooks and uppercuts have no clean reading: pose jumps of 25 to 99 m/s and impossible 12 to 24 m/s frames. `rep` always equals `calc`: the runtime's palm velocity is not an independent reading, and on the frame a hand is picked up it reports 50 to 135 m/s (now filtered as a jump, d2fb982).
  Controller baseline jab speed: 5.4 to 8.2 m/s (5 jabs)
  FIST held through punches (always / mostly / no): always on jabs (curl 0.76 to 1.00). Held fists 0.97 to 1.00, open hands 0.08 to 0.14; 5 fast open-hand swipes reached 5.7 to 12 m/s at curl 0.07 to 0.08.
  Palm sphere lag by eye (none / visible / bad): visible to bad. "There is definitely enough latency that I'm thinking hand tracking alone is a no go."
  Where tracking drops (no speed limit found: jabs at 7.9 m/s and swipes at 12 m/s held): uppercuts finishing close under the headset; the wind-up of a wide hook outside the cameras (11 drops per hand in about 6 wide hooks, 13 jumps on re-acquiring); fists up at the face in a cover block (about 32 drops per hand in 19 s, flickering twice a second). Forearms crossed at the chest held (1 drop in 7 s); wrists crossed in front of the face held (3 brief drops in 7 s).
  Verdict: dropped + missed per 20: right 4, left 6 to 10. Fails the bar of 2. Hand tracking cannot be required for combat.
Test 8:
  simultaneous: supported. Resumes with no error. The runtime starts each launch with it paused.
  Controller on strap -> optical hand, no menu (yes / no, how long): yes. One hand 0.43 s after resuming; both hands within about a second.
  Grip again -> controller (yes / no, how long): yes, at once (both hands within 0.2 s), no gap.
  Palms on floor, controllers hanging, 10 s: 0 drops, conf HIGH, 26/26 joints through the hold and 3 slow push-ups; curl 0.08 to 0.13.
  Without simultaneous, controller on strap: that hand goes to NONE (no tracked hand) while the other hand holds its controller.
  Double jabs with one hand optical and one on a controller: the optical hand dropped nothing in 14 punch events.
  Verdict: the fallback exists. Fight on controllers, let them hang for the floor, hands tracked, no menu.
Odd readings or crashes: no crashes. Pinch does not select menu items (the menus listen to the controller trigger only). A controller put down on a table still reports a tracked pose, so the probe shows `BOTH` with the controllers lying down: a controller's pose does not say it is held. The XR Tools glove models follow the controllers, not the tracked hands, which read as "it doesn't see open versus fist". On 2026-10-17 the head read 2.6 m standing (1.58 m on 10-14): the Quest's floor level was about 1 m off, so the push-up detector never saw a plank; re-set the floor in the boundary before the next push-up session.

### 2026-10-17 (afternoon) — self, Quest 3, debug builds c2d93c0 through 19a1fd3
Simultaneous hands and controllers built into the game (decision 39), checked in the menu and in a boss fight, read from `HANDS` and `PUSHUP` logcat lines.
- **Free hands in the menu:** letting a controller hang moved that hand's glove and gauntlet onto the tracked hand within about half a second, a fist powered the gauntlet, the glove's fingers followed, pinch selected a menu button, and gripping again brought everything back. **The first two builds put the gauntlets sideways:** the palm joint's rotation is not the same for a camera-tracked hand and for one the runtime builds around a held controller, and the controller-in-hand pose was being measured as the controller dropped (70 to 90 degrees off). Fixed in 19a1fd3 with a hand frame built from joint positions and a measurement taken only during a still grip; then "it worked this time as expected" in a handshake and palm down.
- **Boss fight (`--mission=the_maw_boss --maw-breaks`), floor re-set first:** two spent tentacles, 10 push-ups counted at each (head travel 23 to 42 cm), no script errors. The hands did not stay free on the floor: in the first set the left hand flipped between free and held about four times in 10 s and both went back to held a second in; in the second set no free hand was logged. Every plank was entered on head height alone (`palms=UNKNOWN`).
- **Still to check:** why the hands go back to held on the floor (a hanging controller touching the hand is the likely cause), then whether the palms rule holds a real set.
