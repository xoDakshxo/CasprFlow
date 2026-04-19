# Phase 5.5 Report: Permiso Permission Flow

Status: Passed

## Summary

- What changed:
  - Added menu-bar permission state for Accessibility and Screen Recording.
  - Added `Enable Accessibility...` and `Enable Screen Recording...` actions when the relevant permission is missing.
  - Added a local Permiso-style permission guide that opens the right System Settings privacy pane, tracks the System Settings window, and displays a passive overlay near the bottom of the Settings content area.
  - Added a draggable CasprFlow app row that exposes the app bundle as a `.fileURL` drag item.
  - Replaced the helper drag-row bundle icon with the CasprFlow logo mark.
  - Tuned the helper to keep Permiso's layout while fitting inside the Settings content area with visible rounded corners.
  - Added a Screen Recording permission checker using `CGPreflightScreenCaptureAccess()`.
  - Added Phase 5.5 self-checks for menu labels, privacy pane identifiers, and drag payload type.
  - Documented `zats/permiso` as a local reference only, with license status unresolved.
- What now works:
  - Missing Accessibility starts a guided helper instead of only opening Settings.
  - Missing Screen Recording can be started from the menu with the same guided helper.
  - The overlay uses the Permiso interaction shape: compact material panel, upward arrow, back affordance, one draggable app row, and bottom-of-System-Settings placement.
  - The helper row now uses CasprFlow's own logo and trimmed sizing instead of the default bundle icon.
  - Menu labels update from enable actions to `Granted` states when permission checks pass.
- What was intentionally skipped:
  - No onboarding wizard.
  - No settings screen.
  - No direct TCC database writes or private APIs.
  - No direct Permiso package dependency because its inspected checkout has no license file and targets newer Swift/macOS versions than CasprFlow.

## Checks

- Build:
  - Passed: `make build`
  - The build re-signed `.build/CasprFlow.app`; local Accessibility and Screen Recording permissions may need to be granted again for the rebuilt app identity.
- Unit tests:
  - Passed: `make test`
  - `CasprFlowChecks` now covers Phase 5.5 menu labels, pane identifier mapping, and `.fileURL` drag source payload.
- Manual smoke:
  - Passed by user confirmation after the overlay was adjusted to match Permiso's UI and bottom placement.
- Docs/skills:
  - Phase stayed within MVP scope: no hotkey picker, no auto-send, no account/sync/dashboard scope.
  - Source reuse docs note that Permiso is reference-only until license status is clarified.

## Evidence

- Commands run:
  - `git clone https://github.com/zats/permiso.git .casprflow-temp/permiso`
  - `make build`
  - `make test`
  - `git diff --check`
- Apps tested:
  - System Settings permission helper was manually checked by the user.
- Files changed:
  - `Sources/CasprFlowCore/Permissions/PermissionGuidePanel.swift`
  - `Sources/CasprFlowCore/Permissions/PermissionGuideController.swift`
  - `Sources/CasprFlowCore/Permissions/PermissionDragSourceView.swift`
  - `Sources/CasprFlowCore/Permissions/ScreenRecordingPermissionService.swift`
  - `Sources/CasprFlowCore/Permissions/SystemSettingsWindowLocator.swift`
  - `Sources/CasprFlowCore/CasprFlowLogo.swift`
  - `Sources/CasprFlowCore/AppCoordinator.swift`
  - `Sources/CasprFlowCore/StatusItemController.swift`
  - `Sources/CasprFlowCore/ReplyCapsuleController.swift`
  - `Sources/CasprFlowCore/AccessibilityPermissionService.swift`
  - `Sources/CasprFlowCore/PhaseFivePointFiveSelfCheck.swift`
  - `Sources/CasprFlowChecks/main.swift`
  - `Assets/logo/logo-black.svg`
  - `Assets/logo/logo-white.svg`
  - `Assets/logo/logo-loading.svg`
  - `docs/phases/phase-5-5-permiso-permissions-flow.md`
  - `docs/phase-reports/phase-5-5-permiso-permissions-flow.md`
  - `docs/phases/README.md`
  - `docs/CasprFlow-Tech-Spec-v1.md`
  - `docs/phase-audits/source-reuse-audit-v1.md`

## Known Issues

- The inspected Permiso checkout did not include a license file. CasprFlow reimplemented the narrow behavior locally and should not copy Permiso source unless license status is clarified.
- `make build` re-signed the app bundle, so macOS may ask for Accessibility and Screen Recording again.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute `docs/phases/phase-6-local-learning.md`. Complete only that phase, run its checks, write the phase report, and stop.
