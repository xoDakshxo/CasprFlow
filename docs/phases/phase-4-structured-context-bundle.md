# Phase 4: Structured Context Bundle

## Outcome

Every hotkey press produces a single `ScreenContextBundle` — a clean, JSON-shaped struct that downstream consumers (chips, expansion, learning, debug UI) can rely on without re-parsing AX/OCR fragments. The debug window shows the full bundle without truncation.

## Why

Phase 3 left context as scattered candidates: AX list, raw line-level OCR, separate prompt text. Long chat messages wrap into many small OCR lines and look truncated, and downstream prompts cannot tell a chat surface from a code editor. Before adding intent chips, the context needs one canonical structured shape.

## Scope

### Bundle shape

Add `Sources/CasprFlowCore/ScreenContextBundle.swift` with `Codable` types:

```text
ScreenContextBundle
  surface: SurfaceInfo
    kind: chat | code | email | docs | casual | browserChat | other
    appName, bundleId, windowTitle
    isInputFocused: Bool
  focused: FocusedField?
    role, subrole, value (truncated), fieldKind
  selection: String?
  recent: [MessageBlock]            // most-recent-first
    text, source (focusedRegion / cursorRegion / visibleWindow / activeWindow / ax)
    boundingBox?
    confidence
  ambient: [String]                  // headers, sidebar, toolbar — kept separate
  prompt: String                     // compact, token-budgeted text projection
  confidence: Double
  debug: DebugBundle
    rawAXCandidates: [String]
    rawOCRCandidates: [OCRTextCandidate]   // per line, untouched
    screenshots: [ScreenshotMetadata]
    droppedCount: Int
```

`ScreenContext` keeps its existing fields for back-compat but exposes `bundle: ScreenContextBundle` as the canonical source.

### Surface detection

Add `SurfaceClassifier` that maps bundle id + role + window title to `SurfaceKind`:

- `com.tinyspeck.slackmacgap`, `Slack.app` → chat
- `com.apple.MobileSMS` → casual
- `com.microsoft.teams2` → chat
- `com.apple.mail` → email
- `com.apple.dt.Xcode`, JetBrains, VS Code, Cursor → code
- `*.googlechrome.* / Safari / Arc / Firefox / Edge` with chat-like URL or focused contenteditable → browserChat
- everything else → other

Detection is best-effort and overridable later by learning.

### OCR grouping

Replace the per-line OCR candidate list with grouped `MessageBlock`s:

- sort lines top→bottom by source
- merge lines whose vertical gap < ~1.4× line height and whose horizontal extents overlap
- preserve the raw per-line OCR in `debug.rawOCRCandidates` for inspection
- emit grouped blocks into `recent` (most recent first based on y-position)

### Larger interaction crops

Update `ActiveWindowScreenshotService.focusedInteractionRegion` to extend further upward (chat history above input). Make `cursorInteractionRegion` chat-sized. Track which crop was used in screenshot metadata.

### Compact prompt projection

`ScreenContextBundle.prompt` is built from:

- surface header (`App: …`, `Surface: chat`, `Window: …`)
- focused field summary
- top N message blocks until a character budget (~2400 chars)
- selection if present (highest priority)

Drop chrome / button labels / repeated toolbar text. Keep ambient out of the main prompt.

### Debug UI changes

In `ReplyCapsuleController`'s context view:

- show grouped `recent` blocks in full (no `lineLimit`)
- new section: `Surface` (kind, app, bundle id, window title, isInputFocused)
- new section: `Bundle JSON` (collapsed by default) — pretty-printed `JSONEncoder` of the bundle
- raw OCR section stays under `Debug` and is collapsible
- screenshot metadata shows source + size + windowID

### Stub generator

`StubReplyGenerator` keeps working but reads `bundle.prompt` instead of legacy `promptContext.text`.

## Non-Goals

- no Gemini calls
- no chips yet
- no learning store
- no UI changes besides debug expansion and surface header

## Deliverables

- `Sources/CasprFlowCore/ScreenContextBundle.swift`
- `Sources/CasprFlowCore/SurfaceClassifier.swift`
- updated `LocalOCRService` with `groupIntoBlocks(_:)`
- updated `ActiveWindowScreenshotService` crops
- updated `ScreenContext` with `bundle` accessor
- updated `ReplyCapsuleController` debug view
- new self-checks in `PhaseFourSelfCheck`
- `docs/phase-reports/phase-4-structured-context-bundle.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- `SurfaceClassifier` returns `chat` for Slack bundle id
- `SurfaceClassifier` returns `code` for VS Code bundle id
- `SurfaceClassifier` returns `casual` for Messages
- `OCR.groupIntoBlocks` merges two close-y lines into one block
- `ScreenContextBundle.prompt` includes the most recent block first
- `ScreenContextBundle.prompt` excludes chrome strings ("Send", "Submit")
- `ScreenContextBundle` is JSON-encodable and round-trips
- `ScreenContextBundle.confidence` is non-zero when at least one block exists

## Manual Checks

- In Notes, focus a reply field with a long visible message. Press `Option + Space`.
- Confirm the debug window shows the full message in `recent` (not just the first line).
- Confirm `Surface` shows `kind = other` and `app = Notes`.
- Confirm `Bundle JSON` opens and contains the message text.
- In Slack, confirm `kind = chat` and the most recent message appears first in `recent`.

## Exit Criteria

- the bundle is the single source of truth for downstream code
- long chat messages render in full inside `recent`
- `surface.kind` is correct for at least Slack, Notes, Messages, VS Code, Mail
- raw OCR remains available in debug for diagnostic work

## Stop If

- AX walking becomes unbounded for big windows
- OCR grouping merges unrelated messages aggressively (drop merge in that case)
- Bundle JSON in debug overflows the panel — collapse by default

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-5-three-intent-chips.md. Complete only that phase, run its checks, write the phase report, and stop.
```
