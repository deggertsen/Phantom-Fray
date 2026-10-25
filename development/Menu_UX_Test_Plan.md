# Quest Menu UX Test Plan

Updated 2026-10-24 for the wraparound city map (`Scripts/UI/vr_wrap_panel.gd`, `Scripts/UI/city_map.gd`) and the single panel that still carries Training Complete, settings, pause, and the confirmations (`Scripts/UI/vr_menu_panel.gd`). Use a debug build from current `main`.

## Entry and recentering

- Launch while facing away from the intended play direction; hold the Meta button and confirm the menu is centered after Horizon OS recentering.
- The panels remain stationary in world space while the player turns their head.
- Only holding the Meta button moves the panels. Selecting a site or a difficulty, opening settings, pausing, results, opening and closing the universal menu, and taking the headset off and putting it back on all leave them where they are.
- The city map and results are three panels: the city on the left, the map in the middle about 2.45 m away, the site and Deploy on the right. The side panels stand off the middle one's edges, turned 30° in toward the player. Everything sits at eye height inside the comfortable field of view; Deploy needs at most a small head turn to the right, never a turn of the shoulders.
- Settings, pause, the confirmations, Training Complete, and the XR suspended page are one panel straight ahead, as before.

## Pointer interaction

- Both controllers show a laser only when a menu is visible.
- Pointing at a button or a map site visibly highlights it, on all three wrap panels.
- Pulling and releasing the trigger activates exactly one action, on release.
- Lasers disappear during combat and training and reappear on pause, XR suspend, results, and Training Complete.
- Buttons are selectable without wrist twisting or crossing hands, including the side panels' outer edges.
- Results respond to both lasers after victory and after defeat (regression check for the earlier Quest 3 issue).
- Map sites are big enough to hit with the laser on the first try. Locked sites do not highlight or respond.

## City map comprehension

Ask a player who has not seen the project to identify, without coaching:

1. Which option starts real combat? Expected: **Deploy** on the right panel. It names the difficulty it will play at; the line above it gives the site's expected time.
2. How do you pick a different mission? Expected: point at another lit site on the map.
3. Which option changes the difficulty? Expected: the four buttons above Deploy.
4. Which option teaches the game? Expected: **Training Chamber** on the left panel.
5. Which option changes audio, haptics, or comfort? Expected: **Settings** on the left panel.
6. What do the red line and the hatched ground mean? Expected: the front, and the ground the breach still holds.

Pass condition: 1 to 5 identified within 10 seconds; 6 explained without help.

## City map

- The left panel shows the city, how much is reclaimed (one sixth per sealed site), a segment per site, and which site to seal next.
- The map shows six sites. Sealed ones carry a check and their best time at the chosen difficulty; the live one is magenta with a cyan ring; the rest sit behind the front line, dashed and locked. Selecting an open or sealed site moves the selection ring to it and fills the right panel with it. Nothing starts until Deploy.
- On opening, and on coming back from results, the next live site is selected; a clear that unlocked a new one selects that.
- The front line sits right of every sealed site and left of every other one, at every sealed count. With all six sealed there is no line.
- The right panel shows the site's codename, state, title, summary, expected time, and the best time at the chosen difficulty when there is one.
- Four difficulties sit above Deploy: ASSIST, STANDARD, OPERATOR, FULL RES. A fresh profile has STANDARD marked (●). Full Resonance can be picked on a fresh profile. Picking one marks it at once, recolors the panel and Deploy, and changes the line under the buttons to what it asks for. At Full Resonance that line names squats, jumps, and push-ups and says to clear room to jump; ask the tester whether they noticed it before deploying.
- The choice survives Deploy and an app restart. Reset Progress keeps it.
- Each site's best time is the one set at the chosen difficulty; switching difficulty swaps it (or hides it where that difficulty has no clear). OP-06 reads 4 TO 7 MIN at Full Resonance and 4 TO 6 MIN elsewhere.
- A clear at any difficulty unlocks the next site.
- All three panels fit without scrolling or clipped text, in every state (new recruit, Full Resonance, all sealed).
- After Phase 6: best score and medal are visible per site.

## Training

Training is no longer a menu: it is Dr. Chen's training chamber ([Tutorial_Plan.md](Tutorial_Plan.md)). What the menu has to get right around it:

- On a fresh profile, Training Chamber is the highlighted button with a NEW RECRUIT note above it, and Deploy reads TRAINING RECOMMENDED FIRST in outline instead of filled. Deploy still starts the selected site. Once training is done (finished or ended from pause), the city map returns to its usual layout.
- Selecting Training Chamber hides the menu and lasers and starts the chamber. No other trigger press starts it.
- The menu button pauses training at any point, including Chen's introduction before the rift appears. The pause panel reads Resume Training, Settings, End Training, and Chen stops mid-line until Resume.
- End Training needs no confirmation, returns to the city map, and counts training as done.
- After Chen signs off, Training Complete offers Deploy (primary, naming the next contract), Replay Training, and City Map. Replay plays the whole tutorial again, identical to a first run.
- Headset removal during training shows the XR suspended page and holds the chamber where it is.

## Settings

- Play My Own Music switch shows its state; when on, the Music Volume stepper is hidden and the soundtrack is silent.
- Music (when shown), Effects, and Haptics steppers show their current value and explain what they affect.
- Reduced Flashes shows its state.
- Changing any setting leaves the list scrolled where it was, with no jump to the top. Opening settings again starts at the top.
- Reset Progress asks for confirmation and explains that audio and training are kept.
- Back returns to the correct origin: the city map or pause.
- Settings and progress persist after an app restart.

## Pause, suspend, and results

- Pause shows Resume Mission as primary, Settings as secondary, End Mission as destructive with a confirmation page. In training the same panel reads Resume Training, Settings, End Training.
- Headset removal shows the XR suspended page; Resume When Ready is required to continue.
- Results wrap around like the city map. Middle: the outcome with the difficulty beside it (ALL RIFTS SEALED • OPERATOR), the completion time after a victory (with NEW BEST TIME when it beats the stored best, SEALED IN otherwise), the score, the map, and the operation's debrief line. After a first clear the site turns sealed, the front moves past it with the old front drawn faint, and the next site turns live.
- Left: the city's reclaimed share (UP FROM the old share when it moved), THE LINE MOVED, THE LINE HELD (a replay), or THE BREACH HELD (a defeat), and the best time at that difficulty.
- Right, after a victory that unlocks a site: the next site and a filled Deploy, then Retry and City Map. Otherwise Retry is the filled button, and after a defeat Review Training sits between Retry and City Map and starts the training chamber. Retry and Deploy keep the difficulty the mission was played at.

## In-fight readability

- Bracer panel text is readable at a glance mid-combat.
- Chen captions are legible and do not cover the life force bar.
- Rift compass chevron is noticed by an untold tester when a rift opens behind them.
- At Full Resonance, Chen's countdown line ("Full resonance. The gauntlets draw on your whole body. Legs too." or "More power. More cost. Clear the space around you.") plays before her mission line, and neither is cut off.

## Visual quality

- Text is readable on Quest 3 without leaning, on the side panels as well as the middle one. Map labels are the smallest text (16 to 18 px); check them first.
- No button text clips at standing eye height.
- Hover and selected states remain legible for common color-vision deficiencies; do not rely on color alone. Sites also differ by shape: check, rift, lock.
- UI audio stays below critical gameplay cues and Chen.
- No visible pixel shimmer or excessive aliasing at the panel distance, including the map's hatching and the side panels seen at an angle.
