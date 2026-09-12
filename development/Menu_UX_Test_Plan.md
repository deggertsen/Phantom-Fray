# Quest 3 Menu UX Test Plan

Use `builds/phantom-fray-menu-debug.apk` for the first headset pass.

## Entry and recentering

- Launch while facing away from the intended play direction; hold the Meta button and confirm the menu is centered after Horizon OS recentering.
- The panel must remain stationary in world space while the player turns their head.
- The menu should be approximately 2.45 m away, centered near eye height, fully inside the comfortable field of view.

## Pointer interaction

- Both controllers show a laser only when a menu is visible.
- Pointing at a button visibly highlights its border/background.
- Pulling and releasing the trigger activates exactly one action.
- Lasers disappear during active combat and reappear on pause/results.
- Buttons must be selectable without wrist twisting or crossing hands.

## Main menu comprehension

Ask a player who has not seen the project to identify, without coaching:

1. Which option starts real combat? Expected: **Deploy Mission**.
2. Which option teaches the game? Expected: **Start Training**.
3. Which option changes audio/haptics/comfort? Expected: **Open Settings**.

Pass condition: all three are identified correctly within 10 seconds.

## Tutorial pacing

- Every lesson remains visible indefinitely until Continue is selected.
- Continue, Back, and Exit Training are visually distinct.
- No trigger press outside a button advances the tutorial.
- Each lesson answers one question: space/recenter, punching, left/right, block/dodge, life force, mission objective.
- The final lesson returns to the main menu rather than starting combat automatically.

## Settings

- Music, haptics, and reduced flashes show their current value.
- Selecting a setting updates the displayed value immediately.
- Back clearly returns to the correct origin: main menu or pause menu.
- Settings persist after app restart.

## Pause and results

- Pause shows Resume Mission as the primary action, Settings as secondary, and End Mission as destructive.
- End Mission requires a confirmation page.
- Results clearly separate Retry Mission, Review Training, and Main Menu.

## Visual quality

- Text remains readable on Quest 3 without leaning.
- No button text clips at normal or seated eye heights.
- Hover and selected states remain legible for common color-vision deficiencies; do not rely on color alone.
- UI audio is subtle and never louder than critical gameplay cues.
- No visible pixel shimmer or excessive aliasing at the panel distance.
