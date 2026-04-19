# Phase 5.5: Permiso Permission Flow

## Outcome

CasprFlow's menu-bar permission actions use a Permiso-style guided flow for Accessibility and Screen Recording. When a permission is missing, clicking the corresponding menu item opens System Settings to the right privacy pane and shows a draggable CasprFlow app row that the user can drop into the permission list.

## Why

The current permission flow can open System Settings, but it leaves the user to figure out the final step. CasprFlow depends on Accessibility for hotkey/focus/paste behavior and Screen Recording for screenshot context. These permissions need to be smooth enough that manual testing and first-run setup do not feel broken.

`zats/permiso` demonstrates the exact interaction we want: open the privacy pane, track the System Settings window, overlay a helper row, and expose the current app bundle as a drag source.

## Source Reference

- Repo: `https://github.com/zats/permiso.git`
- Local inspection path: `.casprflow-temp/permiso`
- Inspected commit: `3012871`
- Relevant files:
  - `Sources/Permiso/PermisoAssistant.swift`
  - `Sources/Permiso/PermisoPanel.swift`
  - `Sources/Permiso/AppDragSourceView.swift`
  - `Sources/Permiso/OverlayWindowController.swift`
  - `Sources/Permiso/SettingsWindowLocator.swift`
- Important caveat: no license file was present in the inspected checkout. Do not copy source into CasprFlow or ship adapted code publicly until license status is clarified or permission is obtained.
- Package caveat: Permiso currently declares Swift tools 6.2 and `.macOS(.v26)`, while CasprFlow targets macOS 14. Treat it as a reference first; if direct dependency integration is attempted, confirm it compiles against the CasprFlow deployment target.

## Scope

### Menu-bar permission items

Update the status menu to show clear permission actions:

- `Accessibility: Granted` when trusted.
- `Enable Accessibility...` when missing.
- `Screen Recording: Granted` when screenshot capture is allowed.
- `Enable Screen Recording...` when missing.

Clicking a missing permission starts the guided flow instead of only opening Settings.

### Permission checks

- Keep `AccessibilityPermissionService` for `AXIsProcessTrustedWithOptions`.
- Add a small Screen Recording permission checker that uses the existing screenshot path or a lightweight CGWindow probe.
- Refresh menu state after returning from System Settings and after a short polling loop.

### Permiso-style guided helper

Implement or adapt the behavior:

1. Open the correct System Settings privacy pane:
   - Accessibility: `Privacy_Accessibility`
   - Screen Recording: `Privacy_ScreenCapture`
2. Track the frontmost System Settings window.
3. Present a non-activating overlay near the privacy list.
4. Show a draggable CasprFlow app row using the current app bundle URL.
5. Let the user drag that row into the permission list.
6. Provide a small back/close affordance and dismiss when permission is granted or the user closes the helper.

Use Permiso's public API shape as the behavioral model:

```swift
PermisoAssistant.shared.present(panel: .accessibility)
PermisoAssistant.shared.present(panel: .screenRecording)
```

### Integration approach

Preferred path for this phase:

- Reimplement the narrow behavior locally under `Sources/CasprFlowCore/Permissions/` after inspection.
- Keep types CasprFlow-owned, for example:
  - `PermissionGuideController`
  - `PermissionGuidePanel`
  - `PermissionDragSourceView`
  - `SystemSettingsWindowLocator`
- Preserve CasprFlow's macOS 14 target.
- Do not import the whole package unless deployment target compatibility is verified.

If any Permiso source is copied or substantially adapted:

- Add license/permission notes before finishing the phase.
- Add `THIRD_PARTY_NOTICES.md` entry or mark the phase blocked if license cannot be resolved.

## Non-Goals

- no onboarding wizard
- no settings screen
- no permission analytics
- no permissions beyond Accessibility and Screen Recording
- no direct TCC database writes or private APIs

## Deliverables

- `.casprflow-temp/permiso` cloned for reference
- menu items for Accessibility and Screen Recording
- guided helper for both missing permissions
- screen-recording permission check
- phase report: `docs/phase-reports/phase-5-5-permiso-permissions-flow.md`

## Automated Checks

- `make build`
- `make test`

Recommended coverage:

- menu state labels reflect granted/missing Accessibility
- menu state labels reflect granted/missing Screen Recording
- permission guide maps `.accessibility` to `Privacy_Accessibility`
- permission guide maps `.screenRecording` to `Privacy_ScreenCapture`
- drag source exposes the current app bundle URL as `.fileURL`

## Manual Checks

On a clean or permission-reset local app identity:

- Menu bar -> `Enable Accessibility...` opens System Settings to Accessibility.
- The helper overlay appears on top of System Settings.
- The CasprFlow row can be dragged into the Accessibility list.
- Menu bar -> `Enable Screen Recording...` opens Screen Recording.
- The helper overlay appears and the CasprFlow row can be dragged into the Screen Recording list.
- Once permissions are granted, menu labels update to `Granted`.
- Existing `Option + Space` hotkey, capture, chips, expansion, and paste still work.

## Exit Criteria

- Accessibility and Screen Recording setup can be completed from the menu without hunting through Settings manually.
- The helper does not break the menu-bar app lifecycle.
- The integration keeps fixed hotkey, paste-only behavior, and no settings screen.
- License status is documented before any source is copied or substantially adapted.

## Stop If

- Permiso's macOS 26 target prevents direct reuse and local adaptation becomes too large for this phase.
- License status cannot be clarified and source copying is required.
- System Settings window tracking is unreliable across the user's macOS version.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-6-local-learning.md. Complete only that phase, run its checks, write the phase report, and stop.
```
