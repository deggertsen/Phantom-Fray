# Phantom Fray Implementation Checklist

Master checklist across systems, as of 2026-10-08. Phase ownership is in [Production_Roadmap.md](Production_Roadmap.md).

## Progress
- Core systems: complete
- Combat mechanics: complete, low approaches and boss planned
- Campaign content: six operations, replay layer not started
- User interface: complete for the current flow
- Audio: integrated, Chen voiced with ElevenLabs, final mix pending
- Testing and optimization: validation and CI in place, soak and perf on headset pending
- Deployment: build path complete, store work not started
- Fitness, narrative, and location features: planned (Phases 6 to 8)

## 1. Project setup
- [x] Godot 4.7.1 project, OpenXR, godot-xr-tools 4.5.1
- [x] Git, ignore rules for builds, reports, keystores
- [x] Compatibility renderer, Quest-first settings, audio bus layout

## 2. Core systems
- [x] Player: XR origin, tracked hands, grip-gated strikes, haptics, gauntlet armor
- [x] Phantoms: base arc, four rules, three species with three forms each
- [x] Rifts: director and manager, health, placement modes, concurrency, Maw scale
- [x] Life force: drain, recovery, states, fail state
- [x] Round: countdown, timer, score, chain, outcomes, pause
- [x] Flow: menu, operations, training, settings, results, progress persistence
- [x] Best score stored per operation
- [ ] Progression beyond unlock order (medals, map)

## 3. Game mechanics
- [x] Stationary play with physical duck and side-step
- [x] Punch with any style; lure placement rewards hook, uppercut, jab
- [x] Two-hand block, lane dodge
- [x] Chain multiplier and crit bonus
- [x] Pressure scaling per wave
- [ ] Difficulty per mission on the world map (Assist, Standard, Operator, Full Resonance)
- [ ] Low approaches for squats and uppercuts (squat detector prototype built, off by default)
- [ ] Validate the strike-window feel with untold testers

## 4. Additional features
- [x] Rift system with weakening shader and closure
- [x] Combo system (chain multiplier)
- [x] Training: six-module guided orientation on the menu panel
- [ ] Training room with damage off and species selection
- [ ] Shield phantom needing a punch sequence (see Ideas_Backlog.md)
- [ ] Environmental hazards (see Ideas_Backlog.md)
- [ ] Power-ups (see Ideas_Backlog.md)
- [ ] Bosses: The Maw as the first boss, then bosses on the war map (see Exercise_Mechanics_Exploration.md)
- [ ] Hand tracking as an input option

## 5. Fitness (Phase 6)
- [ ] Session stats on results
- [x] Best score stored per operation
- [ ] Best score shown on Operations and results, medals
- [ ] Endless hold with 10, 20, 30 minute lengths
- [ ] Workout-length framing in the menu
- [ ] Fitness tagging and platform integration

## 6. Narrative and war (Phase 7)
- [ ] Story beats and Chen debriefs that reveal the Overseer
- [ ] War map with a front line, local first, shared later
- [ ] Daily and weekly breach
- [ ] Leaderboards
- [ ] Intelligence operations

## 7. Locations (Phase 8)
- [ ] Breach-site presets per operation
- [ ] Training chamber as its own site
- [ ] Two or three additional sites

## 8. User interface
- [x] World-space menu with lasers, Operations, Training, Settings, pause, results
- [x] Bracer wrist panel with Chen captions
- [x] Rift compass and phantom bearings
- [ ] Map screen
- [ ] Stats and medals on results and Operations

## 9. Audio
- [x] Six music tracks with intensity control
- [x] Death, siphon, rift open and close takes
- [x] Procedural heartbeat, drain blip, depletion stinger
- [x] Chen comms system with 29 moments
- [x] Chen takes voiced with ElevenLabs and checked by transcription
- [x] Play My Own Music switch (soundtrack silent, any music app plays through)
- [ ] Species movement and attack sounds
- [ ] Final mix on headset

## 10. Testing and optimization
- [x] Validation runner and GitHub Actions
- [x] Performance monitor, shader prewarm, one-mesh creatures and city
- [x] Desktop art and play capture scenes
- [ ] Playtest log kept per session
- [ ] Headset performance and soak evidence
- [ ] Round and rift integration fixtures

## 11. Deployment
- [x] Quest debug and release build scripts, export presets, signing evidence
- [ ] Rebuild from current main
- [ ] VRC test plan on the exact release build
- [ ] Store listing, art, trailer
- [ ] Soft launch and 1.0

## 12. Documentation
- [x] README, roadmap, status, known issues, release checklist, store plan, export guide, performance budget, enemy and life force design, Chen script
- [x] Playtest log
- [ ] Player-facing help beyond Training (if needed after testing)
