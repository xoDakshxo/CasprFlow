# Phase 1: Native Walking Skeleton

## Outcome

A native macOS app exists, builds from the command line, runs as a menu-bar app, and opens a tiny placeholder capsule with `Option + Space`.

This is the first walking skeleton: app shell -> hotkey -> capsule -> close.

## Scope

- Create the native Swift macOS project.
- Add command-line build and test targets.
- Add a minimal app bundle setup if using SwiftPM.
- Configure menu-bar/background behavior.
- Add menu items:
  - Enable CasprFlow
  - Clear learning
  - Quit
- Register fixed hotkey `Option + Space`.
- Show a borderless placeholder capsule when the hotkey fires.
- Support `Escape` to close the capsule.
- Add basic permission-needed state if hotkey or synthetic events require it.

## Deliverables

- App source tree.
- Build/test command documented in the phase report.
- Placeholder capsule visible from hotkey.
- `docs/phase-reports/phase-1-native-walking-skeleton.md`

## Automated Checks

Use whichever commands the phase creates, preferably:

- `make build`
- `make test`

If no `Makefile` exists yet, create one with stable targets before finishing:

- `make build`
- `make test`
- `make run`

## Manual Checks

- Launch the app.
- Confirm a menu-bar item appears.
- Press `Option + Space`.
- Confirm a tiny capsule appears.
- Press `Escape`.
- Confirm the capsule closes.
- Quit from the menu.

## Exit Criteria

- The app can be built by Codex without Xcode UI.
- The app can be launched manually.
- The fixed hotkey opens the capsule.
- No selection capture, generation, paste, or learning is required yet.

## Stop If

- macOS permissions block basic hotkey testing.
- The build requires manual Xcode-only steps that cannot be documented as repeatable commands.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-2-selected-text-capture.md. Complete only that phase, run its checks, write the phase report, and stop.
```

