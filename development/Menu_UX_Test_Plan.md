# Quest Menu UX Test Plan

Updated 2026-10-08 for the current panel (`Scripts/UI/vr_menu_panel.gd`). Use a debug build from current `main`.

## Entry and recentering

- Launch while facing away from the intended play direction; hold the Meta button and confirm the menu is centered after Horizon OS recentering.
- The panel remains stationary in world space while the player turns their head.
- The menu sits about 2.45 m away, centered near eye height, inside the comfortable field of view.

## Pointer interaction

- Both controllers show a laser only when a menu is visible.
- Pointing at a button visibly highlights its border or background.
- Pulling and releasing the trigger activates exactly one action, on release.
- Lasers disappear during combat and reappear on pause, XR suspend, and results.
- Buttons are selectable without wrist twisting or crossing hands.
- The results panel responds to both lasers after victory and after defeat (regression check for the earlier Quest 3 issue).

## Main menu comprehension

Ask a player who has not seen the project to identify, without coaching:

1. Which option starts real combat? Expected: **Deploy Mission**. The button also names the next or replay contract.
2. Which option lets you pick a specific mission? Expected: **Operations**.
3. Which option teaches the game? Expected: **Start Training**.
4. Which option changes audio, haptics, or comfort? Expected: **Open Settings**.

Pass condition: all four identified within 10 seconds.

## Operations

- Six contracts listed with codename, title, summary, and state: SEALED, OPEN, or LOCKED.
- Locked contracts show which operation must be sealed first and cannot be selected.
- Selecting an open or sealed contract starts it. Back returns to the main menu.
- After Phase 6: best score and medal are visible per contract.

## Training pacing

- Each of the six modules stays visible until Continue is selected.
- Continue, Back, and Exit Training are visually distinct. The last module reads Complete Training.
- No trigger press outside a button advances the tutorial.
- Modules answer one question each: play space and recenter, grip and strike, yellow and blue, green and pink, life force, rifts and the objective.
- Completing training returns to the main menu rather than starting combat.

## Settings

- Play My Own Music switch shows its state; when on, the Music Volume stepper is hidden and the soundtrack is silent.
- Music (when shown), Effects, and Haptics steppers show their current value and explain what they affect.
- Reduced Flashes shows its state.
- Reset Progress asks for confirmation and explains that audio and training are kept.
- Back returns to the correct origin: main menu or pause.
- Settings and progress persist after an app restart.

## Pause, suspend, and results

- Pause shows Resume Mission as primary, Settings as secondary, End Mission as destructive with a confirmation page.
- Headset removal shows the XR suspended page; Resume When Ready is required to continue.
- Results show the outcome, final score, the operation's debrief line, and Next Operation (after a victory that unlocks one), Retry Mission, and Main Menu. Next Operation is the primary action when present.

## In-fight readability

- Bracer panel text is readable at a glance mid-combat.
- Chen captions are legible and do not cover the life force bar.
- Rift compass chevron is noticed by an untold tester when a rift opens behind them.

## Visual quality

- Text is readable on Quest 3 without leaning.
- No button text clips at standing eye height.
- Hover and selected states remain legible for common color-vision deficiencies; do not rely on color alone.
- UI audio stays below critical gameplay cues and Chen.
- No visible pixel shimmer or excessive aliasing at the panel distance.
