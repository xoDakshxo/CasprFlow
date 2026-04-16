# Phase 2: Selected Text Capture + Rich Screen Context

## Outcome

Highlighting text in any app and pressing `Option + Space` shows:
1. A compact product capsule preview so the real MVP UI can be judged separately from debug output
2. A separate debug context inspector with the selected text
3. Surrounding text context (before/after selection)
4. Full screen context — app name, window title, document URL, focused element metadata, and a flattened AX tree of visible UI elements

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

### Product capsule preview (added)
- 420x216 compact floating panel that represents the real CasprFlow reply UI direction
- Shows the selected message being replied to
- Includes an editable draft preview seeded from the selected text
- Shows the planned footer controls: `Enter paste | Cmd+R regenerate | Esc`
- Stays non-functional for paste/regeneration in Phase 2; Phase 3 wires behavior

### Debug context inspector
- 480x520 separate floating panel with scrollable, collapsible sections
- Selected Text / Before / After — expandable with "More" for long text
- Full Element Text — full value of focused field (up to 2000 chars)
- Windows — all open windows with focus indicator (● focused, ○ others)
- Visible UI — indented AX tree showing roles, labels, values
- Metadata — role, subrole, description, identifier, bundle, document URL
- AI Description — full structured text dump ready for LLM consumption

### Logging
- `os.log` (Logger) for all capture events — visible in Console.app under `com.casprflow.CasprFlow`
- Verbose file logging (`~/.casprflow-debug.log`) opt-in via `CASPRFLOW_DEBUG=1` environment variable

### Build Script
- Hash-based signing: only re-signs when binary SHA-256 changes, preserving TCC (Accessibility) permissions across rebuilds

## Deliverables

- `ScreenContext.swift` — rich context model with AI description
- `SelectionCaptureService.swift` — capture logic with AX tree walker
- `ReplyCapsuleController.swift` — product capsule preview plus separate debug context inspector
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
- Product capsule preview appears separately from the debug inspector
- Rich screen context populated with app, window, element, and visible UI data
- Empty selection gives clear capsule state
- Logging clean and opt-in for verbose mode
- Build script preserves Accessibility permissions across rebuilds

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-3-stub-reply-capsule-and-paste.md. Complete only that phase, run its checks, write the phase report, and stop.
```
