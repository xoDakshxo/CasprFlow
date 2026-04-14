# Phase 1 Report: Native Walking Skeleton

Status: Passed

## Summary

- What changed:
  - Added a SwiftPM native macOS app structure.
  - Added `make build`, `make test`, and `make run`.
  - Added a generated `.app` bundle at `.build/CasprFlow.app`.
  - Updated bundle creation to sign the final `.app` bundle as `com.casprflow.CasprFlow`.
  - Added a menu-bar/background app coordinator.
  - Added a fixed `Option + Space` Carbon hotkey service.
  - Added a tiny borderless placeholder reply capsule.
  - Added `Escape` handling to close the capsule.
  - Added basic Accessibility permission state in the menu/capsule messaging.
- What now works:
  - The app builds from the command line.
  - The bundled app launches as a process.
  - The Phase 1 checks verify the default hotkey descriptor, reply capsule construction, and actual Carbon hotkey registration/unregistration.
  - The app bundle now has a stable signed bundle identifier for Accessibility/TCC.
  - The app can be launched with `make run`.
- What was intentionally skipped:
  - No selected-text capture.
  - No paste flow.
  - No Gemini generation.
  - No local learning.
  - No hotkey picker.

## Checks

- Build:
  - Passed: `make build`
- Unit tests:
  - Passed: `make test`
  - `make test` uses a Swift executable checks target so phase checks stay command-line repeatable for Codex.
  - Re-run after full Xcode selection: passed with Xcode 26.4 / Swift 6.3.
- Manual smoke:
  - Passed: launched `.build/CasprFlow.app` and confirmed the `CasprFlow` process started.
  - Passed: quit the app via AppleScript and confirmed no `CasprFlow` process remained.
  - Not directly automated: sending `Option + Space` via `osascript` was blocked because `osascript` is not allowed to send keystrokes. The checks target directly verified the actual hotkey registration path instead.
- Docs/skills:
  - Phase remained within scope: fixed `Option + Space`, no hotkey picker, no generation, no paste, no learning.

## Evidence

- Commands run:
  - `swift --version`
  - `xcrun --show-sdk-path --sdk macosx`
  - `make build`
  - `make test`
  - `plutil -p .build/CasprFlow.app/Contents/Info.plist`
  - `codesign -dv .build/CasprFlow.app`
  - `open -n .build/CasprFlow.app`
  - `ps ax -o pid,comm | rg CasprFlow`
  - `osascript -e 'tell application "System Events" to key code 49 using option down'`
  - `osascript -e 'tell application "CasprFlow" to quit'`
  - `xcode-select -p`
  - `xcodebuild -version`
  - `swift --version` after full Xcode selection
- Apps tested:
  - `CasprFlow.app` launched from `.build/CasprFlow.app`.
- Files changed:
  - `.gitignore`
  - `Makefile`
  - `Package.swift`
  - `Scripts/create_app_bundle.sh`
  - `Sources/CasprFlowApp/main.swift`
  - `Sources/CasprFlowChecks/main.swift`
  - `Sources/CasprFlowCore/AccessibilityPermissionService.swift`
  - `Sources/CasprFlowCore/AppCoordinator.swift`
  - `Sources/CasprFlowCore/AppDelegate.swift`
  - `Sources/CasprFlowCore/CasprFlowApplication.swift`
  - `Sources/CasprFlowCore/HotkeyDescriptor.swift`
  - `Sources/CasprFlowCore/HotkeyService.swift`
  - `Sources/CasprFlowCore/PhaseOneSelfCheck.swift`
  - `Sources/CasprFlowCore/ReplyCapsuleController.swift`
  - `Sources/CasprFlowCore/StatusItemController.swift`
  - `docs/phase-reports/phase-1-native-walking-skeleton.md`

## Known Issues

- Full Xcode is now selected: `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -version` reports Xcode 26.4, build version 17E192.
- If Accessibility was granted before this signing fix, remove the old CasprFlow entry from System Settings and add `.build/CasprFlow.app` again. The previous build used an unstable ad-hoc executable identity; the current app signs the final bundle as `com.casprflow.CasprFlow`.
- `osascript` could not send `Option + Space` because System Events does not have keystroke permission. This does not block Phase 1 because the checks target directly registers the real hotkey and the app launch path is verified.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute docs/phases/phase-2-selected-text-capture.md. Complete only that phase, run its checks, write the phase report, commit the phase, and stop.
