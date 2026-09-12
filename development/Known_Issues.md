# Known Issues and External Launch Gates

## Hardware and platform blockers

1. **A signed Quest Debug APK has been produced, but no headset was connected.** `builds/phantom-fray-debug.apk` is ARM64, Meta/OpenXR packaged, and v2-signature verified. Install and exercise it on the minimum supported Quest per `Quest_Export_Guide.md`.
2. **No headset playtest has been completed for this branch.** Controller alignment, haptics, HUD readability, room-scale hurtbox behavior, Green timing, and Pink dodge comfort must be tuned on the minimum supported Quest.
3. **Store submission is external.** A production-signed release APK now exists, but Meta developer account configuration, VRC evidence, age rating, privacy declarations, store listing, and upload require authorized dashboard access. Back up `phantom-fray-release.keystore` and its password off-machine before any distribution.

## Production-content gaps

- Procedural capsule-based phantom visuals and ERM overlays are launch-capable placeholders, not final authored character art.
- The arena is a coherent procedural RSF chamber but still needs final branding and environmental art for a premium trailer.
- Existing music is integrated, but impact/UI/proximity audio should receive a final professional mix.
- Main menu, tutorial, and settings now use a stationary cyberpunk world-space panel with dual controller lasers, trigger selection, Meta-button recentering, thumbstick scrolling, and explicit Music/Effects/Haptics controls. Deeper bespoke art polish remains a future production pass.

## Technical follow-up

- Results pointer interaction after defeat remains unreliable on Quest 3. The panel renders, heartbeat stops, and the red pulse/death cue fire, but controller lasers did not select Retry/Training/Main Menu during the final pass. Add a dedicated pointer reset/rebuild on Results entry and retest victory and defeat.
- Android export automation can be added to CI only after the export preset and build template versions are established on a trusted workstation.
- The included validation runner tests resource loading, life-force arithmetic, and key variant rules; expand it with deterministic round/rift integration fixtures before long-term live operation.
- The project intentionally targets Compatibility rendering for standalone Quest reliability. Reassess Mobile/Vulkan only with device measurements on the pinned Godot release.
