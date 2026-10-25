---
name: deploy-phantom-fury
description: Deploy a Phantom Fury release build to a Meta Quest release channel (alpha, beta, rc, or store). Use when asked to deploy, ship a build, push a build to testers, or upload to the Meta dashboard.
---

# Phantom Fury deploy

One script does the whole thing in a fixed order: version bump, validation, release export, upload. Everything else here is what to check before and after.

## Before running

1. **Run from the main clone**, `C:\Users\demav\repos\Phantom-Fray`, not a worktree. The clone holds the ignored `export_credentials.cfg` with the keystore password and the Meta app secret; worktree copies are incomplete. Never print, echo, or quote values from that file. Reporting that a key is set and how long it is, is fine.
2. **Main must be what ships.** Fetch, fast-forward the clone to `origin/main`, and confirm `git status` is clean. The script refuses a dirty tree.
3. **Confirm the channel with the user** if they did not name one. `alpha` is for the developer and close testers, `beta` for the wider tester group, `rc` for a store candidate, `store` for production (which also needs the full [Release_Checklist.md](../../../development/Release_Checklist.md)).
4. **Ask for or write release notes** in one sentence: what changed since the last build on that channel. The script appends the version, code, and commit.
5. If the Quest is connected and the user wants to feel the build first, build a debug APK with `tools/build_quest_debug.ps1` and install it; do not use the release build for that, it is signed for distribution.

## Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\deploy_quest.ps1 -Channel alpha -Notes "what changed"
```

Options: `-VersionName 1.1.0` to change the shown version, `-SkipValidation` only for an immediate rebuild of an already validated commit, `-NoCommit` to leave the version bump uncommitted.

What it does, so failures can be read:

- Bumps `version/code` in both export presets to the highest existing code plus one. Meta rejects a code it has already seen on any channel.
- Runs the editor import and the validation runner. The known flaky `_validate_arc_motion` failure is retried once; any other failure stops the deploy.
- Commits the bump as "Bump version code to N for the <channel> channel."
- Exports `builds/phantom-fury-release.apk` with the release keystore, with the Gradle daemon disabled so the export exits.
- Uploads with `tools/upload_quest_build.ps1` (age group TEENS_AND_ADULTS, release notes with version and commit).
- Prints the version, code, commit, and APK SHA-256.

The export takes about four minutes. Run the script in the background and wait for it; do not poll.

## After it succeeds

1. Push the bump commit: `git push origin main`.
2. Tag a store or rc deploy: `git tag v<version>` on that commit and push the tag. Alpha and beta builds are not tagged.
3. Add an entry to [Playtest_Log.md](../../../development/Playtest_Log.md) under a heading for the build: channel, version code, commit, SHA-256, and the notes, so tester reports can be matched to a build.
4. Tell the user to add testers to the channel in the Meta Horizon developer dashboard (Distribution, Release Channels) if they are not on it. The script cannot do that.
5. Report the version, code, commit, channel, and SHA-256 in one line. If the upload printed a dashboard warning, quote it.

## If it fails

- **"has no value for keystore/release_password"**: it was run from a worktree, or the clone's credentials file lost a line. Run from the clone.
- **"Working tree has uncommitted changes"**: commit or revert them first. The tag must match what ships.
- **Validation failed**: fix the failure on main first; do not deploy around it with `-SkipValidation`.
- **Export failed**: see [Quest_Export_Guide.md](../../../development/Quest_Export_Guide.md); usually the Android template or JDK path.
- **Upload rejected for the version code**: someone uploaded a higher code by hand. Set `version/code` in `export_presets.cfg` above it and rerun.
- **Utility not found**: `ovr-platform-util.exe` belongs in `%APPDATA%\PhantomFray\` or on PATH.
- Anything the upload prints about packaging, signing, or the manifest is a store packaging check; compare against [Meta_VRC_Evidence.md](../../../development/Meta_VRC_Evidence.md) and fix before retrying.
