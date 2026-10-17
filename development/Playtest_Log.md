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

**Still to run:** the re-check of bends, side ducks, and squats on eec4d01; the measured eye height; the Sweep Drill (Step 4); the boss Maw with `--mission=the_maw_boss,--maw-breaks`; the glimpse at 90 fps; hand tracking tests 7 and 8 (`tools/build_quest_debug.ps1 -HandTrackingTest`). For the overlay and `SQUAT` lines, set `debug_enabled` on the Player's SquatDetector before building; it is off in the committed scene.

### 2026-10-11 — self, Quest 3, debug builds eec4d01 through 82a5fee

Squat re-checks, the Sweep Drill, and three runs of the boss Maw, read from `SQUAT` and `PUSHUP` logcat lines. Launch arguments now go in `user://debug_args.txt` (see `GameFlowController._debug_args_file`).

- **Squats and bends:** on eec4d01, 5 of 5 squats counted and 2 of 5 waist bends slipped through with the eyes only 18 to 29 degrees down. David then bowed while looking up at an opponent, which pitch cannot see. The early-arc check (head travel from where the descent began, over the fall, once 8 % of standing height down) measured bows at 0.81 to 1.01 and calm squats at 0.16 to 0.20. Under a live sweep squats leaned more (0.29 to 0.50) and one was called a bow, so the limit sits at 0.75: David would rather let a sloppy bow through than reject a real squat.
- **Sweep Drill:** 4 of 4 sweeps cleared, flawless. "Very cool"; it will be better with a tentacle than a bar. The first sweep dropped to 66 fps generating its sounds; they are built during the menu now.
- **Boss Maw, run 1:** "epic". Sweeps too slow (2.3 to 3.5 s from tell to pass, time to squat and wait), volleys from overhead, slams unreadable, the turn "ok, not amazing", no voice for Chen's boss lines (captions only), pacing slow, push-ups not counted. The bow check also called nearly every boss squat a bow: it measured from where the player last stood fully tall, which side-steps and a ready stance made stale.
- **Run 2:** sweeps "perfect" at 1.6 to 1.7 s. Volleys still high (the escort band was measured from the rift, whose base floats 2.2 m up, and the tear lifted the mouth). The ring-shaped light wall did not read. Rumble in the turn did not help much; the phantoms suddenly reversing is the most dramatic beat. Push-ups counted only with the face down; looking forward held it on the 30 degree line.
- **Run 3:** tentacle now drawn in front of the rift (the portal shader ignored depth), but its root does not sit in the mouth, so it seems to come out of nothing. Push-ups looking forward counted: 10 clean reps in a window (head travel 22 to 38 cm, face 16 to 28 degrees down); entering and leaving the plank added 8 to 9 cm wobbles, now below the 12 cm rep line.
- **Still open:** the tentacle's root in the mouth; the slam lane and curtain and the lower escort band not yet judged in a run; ideas for the turn (brainstorm in progress, no changes yet); Chen's voice lines (the ElevenLabs key on this machine is rejected as invalid); the feint (hold a sweep while the player is already crouched) is proposed, not agreed; hand tracking tests 7 and 8.

### 2026-10-11 (evening) and 2026-10-13 — self, Quest 3, debug builds 4935549 and 1e2cb39

- **Entrance run (4935549):** the eye looked "odd rather than scary" and was removed. The tentacles prying the Maw open landed; David asked for them to hold the rim through the fight, which 1e2cb39 does. The narrower (0.7 m), faster slam "feels right". Chen's voice lines played for the first time.
- **Verdict:** "the boss fight is pretty solid at this point"; the missing piece was jumping, built in 1e2cb39 (a jump pair of low sweeps per cycle). **The jump build has not been played on the headset yet** (the Quest was not connected when it finished).

### 2026-10-17 — self, Quest 3, debug build of the training chamber (d3cd00b)

Training played start to finish once, Chen voiced; about 4 minutes 10 seconds from her first word to sign-off (logcat `CHEN` lines).

- **Felt good:** the developer is happy with where it is. The chamber, the paused holograms, the beat order, and the lines all landed; only timing needs adjusting.
- **Felt wrong:** Chen's instruction came too late to follow. Each line waited for the phantom to fly in and pause, so the recruit could act before hearing it. The log shows it: "Tap this one" came 6 s after the previous line and was followed by "Lighter than that" (the tap landed hard before it was heard), the hard hit was followed by "Harder than that", and "This next one, I'm letting through" was followed by "I said let it in" (the phantom was struck before "hands down" was heard).
- **Fix:** Chen now gives each instruction while the phantom is still flying in (`approach_lines` in `TutorialDirector._send_held`), and the cue to act comes last: the tap and hard-hit instructions, hands down before the possession phantom arrives (it is released once she has said it), green's both-hands line, the yellow and blue hand lines, and the pink lane lines during its tell. **Not yet re-checked on the headset.**
- **Not yet checked:** hold distance against a real jab, the glove check, the punch power band at real speeds.
