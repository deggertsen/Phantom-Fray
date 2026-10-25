---
name: verify-phantom-fury
description: Run Phantom Fury and capture desktop fallback evidence before headset verification.
---

# Phantom Fury verification

1. Use Godot 4.7.1 exactly.
2. Launch the real app surface:
   ```bash
   godot --path .
   ```
3. Desktop debug controls:
   - `Enter`/`Space`: activate the primary menu action
   - `T`: tutorial/A-X action
   - `Esc`: pause/menu action
4. Capture the launch/menu, tutorial, settings, mission countdown, pause, and results surfaces.
5. Missing OpenXR runtime/HMD warnings are expected only for desktop fallback. They are blockers for headset verification, not gameplay parser failures.
6. Run the real headset matrix in `development/Release_Checklist.md` before calling the release candidate verified.
