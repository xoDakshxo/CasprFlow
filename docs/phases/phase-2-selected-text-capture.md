# Phase 2: Selected Text Capture + Rich Screen Context

## Outcome

Highlighting text in any app and pressing `Option + Space` shows:
1. The selected text
2. Surrounding text context (before/after selection)
3. Full screen context — app name, window title, document URL, focused element metadata, and a flattened AX tree of visible UI elements

The captured `ScreenContext` is structured for AI consumption, with an `aiDescription` property that produces a text dump an LLM can use to understand intent.

## Scope

### Selection Capture (original)
- AX direct selection (`kAXSelectedTextAttribute`) as primary method
- AX range-based fallback (`kAXValueAttribute` + `kAXSelectedTextRangeAttribute`)
- Clipboard fallback: osascript `Cmd+C` via System Events (primary), CGEvent (secondary)
- Save/restore clipboard contents around fallback copy
- Reject unchanged pasteboard reads via `changeCount` validation
- Show `Highlight a message first.` if no selection found

### Rich Screen Context (added)
- Application: name, bundle identifier, PID
- Windows: focused window title, all open window titles with focus indicator
- Focused element: role, subrole, description, identifier, document URL
- Full element value: up to 2000 chars of the focused text field content
- Surrounding text: 500 chars before/after selection
- Visible UI tree: depth-limited (6 levels), capped (80 elements) walk of the focused window's AX children, extracting roles, labels, values, and identifiers
- AI-friendly dump: `ScreenContext.aiDescription` concatenates everything into structured text

### Logging
- `os.log` (Logger) for all capture events — visible in Console.app under `com.casprflow.CasprFlow`
- Verbose file logging (`~/.casprflow-debug.log`) opt-in via `CASPRFLOW_DEBUG=1` environment variable

### Build Script
- Hash-based signing: only re-signs when binary SHA-256 changes, preserving TCC (Accessibility) permissions across rebuilds

## Deliverables

- `ScreenContext.swift` — rich context model with AI description
- `SelectionCaptureService.swift` — capture logic with AX tree walker
- `ReplyCapsuleController.swift` — capsule UI with expandable sections
- `SelectionTextNormalizer.swift` — text cleanup
- `Scripts/create_app_bundle.sh` — hash-based build script
- `docs/phase-reports/phase-2-selected-text-capture.md`

## Tested Apps

- Notes (native AX — direct selection works)
- Warp (custom renderer — clipboard fallback)
- Slack (Electron — clipboard fallback)
- GitHub Desktop (Electron — clipboard fallback)
- Activity Monitor (native — clipboard fallback)

## Exit Criteria

- Selection capture works in Notes and Electron apps (Slack, Warp)
- Rich screen context populated with app, window, element, and visible UI data
- Empty selection gives clear capsule state
- Logging clean and opt-in for verbose mode
- Build script preserves Accessibility permissions across rebuilds

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-3-stub-reply-capsule-and-paste.md. Complete only that phase, run its checks, write the phase report, and stop.
```
