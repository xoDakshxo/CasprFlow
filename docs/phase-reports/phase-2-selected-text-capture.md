# Phase 2 Report: Selected Text Capture + Rich Screen Context

Status: **Complete** — selection capture and rich context working across native and Electron apps.

## Summary

### What changed
- **`ScreenContext.swift`** (new): Rich model carrying everything AX APIs can provide — app info, all window titles, focused element metadata, full element value, surrounding text, and a flattened visible UI tree. Includes `aiDescription` for LLM consumption.
- **`SelectionCaptureService.swift`**: Three-tier selection capture (AX direct → AX range → clipboard fallback). AX tree walker scrapes the focused window's children (depth 6, max 80 elements). Logging moved to `os.log` with opt-in file logging via `CASPRFLOW_DEBUG=1`.
- **`ReplyCapsuleController.swift`**: Capsule UI shows selected text, before/after context, document URL, and collapsible metadata section with element role/subrole/description/identifier. Expandable "More" for long text sections.
- **`AppCoordinator.swift`**: Prompts for Accessibility on launch if not trusted. Routes to `showContext()` for rich display.
- **`Scripts/create_app_bundle.sh`**: Hash-based signing — tracks binary SHA-256, only re-signs when binary changes. Preserves TCC permissions across rebuilds.

### What works
- **Notes**: AX direct selection + full surrounding text + AX tree of visible UI
- **Warp**: Clipboard fallback via osascript. AX tree shows terminal UI structure.
- **Slack**: Clipboard fallback via osascript. Window title captured.
- **GitHub Desktop**: Clipboard fallback. Window title captured.
- **Activity Monitor**: Clipboard fallback works.
- **Empty selection**: Shows "Highlight a message first."
- **No Accessibility**: Shows "Accessibility needed" and prompts on launch.

### Clipboard fallback chain
1. **osascript subprocess**: `tell application "System Events" to keystroke "c" using command down` — most reliable across Electron/Warp/native
2. **CGEvent**: `CGEvent` with `.privateState` source, posted to `.cgSessionEventTap` — fallback for apps that don't respond to osascript
3. Both methods save/restore clipboard via `pasteboardItems` backup

### AX tree walking
- Starts at focused window, recurses through `kAXChildrenAttribute`
- Depth-limited to 6 levels, capped at 80 elements
- Skips layout containers (AXGroup, AXSplitGroup, etc.) unless they have labels
- Captures: role, title/description (as label), value (truncated to 300 chars), identifier

### Key fixes during development
- **TCC invalidation**: Ad-hoc signing generated new CDHash each build. Fixed with hash-based script.
- **Focused element fallback**: `focusedElement()` now tries app-level first, then system-wide AX always.
- **osascript blocking MainActor**: Wrapped in `withCheckedContinuation` + `DispatchQueue.global`.
- **Option key leaking into Cmd+C**: Switched to `.privateState` CGEvent source (clean flags).

## Files changed
- `Sources/CasprFlowCore/ScreenContext.swift` (new)
- `Sources/CasprFlowCore/SelectionCaptureService.swift`
- `Sources/CasprFlowCore/ReplyCapsuleController.swift`
- `Sources/CasprFlowCore/AppCoordinator.swift`
- `Scripts/create_app_bundle.sh`

## Build
```sh
sh Scripts/create_app_bundle.sh
open .build/CasprFlow.app
```

For verbose logging:
```sh
CASPRFLOW_DEBUG=1 .build/CasprFlow.app/Contents/MacOS/CasprFlow
```

## Next Phase

Use the repo-local CasprFlow skills and execute docs/phases/phase-3-stub-reply-capsule-and-paste.md. Complete only that phase, run its checks, write the phase report, commit the phase, and stop.
