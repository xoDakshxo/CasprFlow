---
name: casprflow-macos-automation
description: Implement or debug CasprFlow native macOS mechanics. Use for AppKit/SwiftUI menu-bar behavior, push-to-talk global hotkey (press+release), on-device speech capture, the center-bottom voice HUD panel, programmatic action execution (URL schemes, AppleScript, deep links, CLI via Process), synthetic paste + clipboard preservation, the `control_ui` computer-use path (Accessibility/`AXUIElement` driving, screenshots via ScreenCaptureKit, `CGEvent` synthesis), and Accessibility/Screen Recording/Microphone/Speech permissions + the drag-into-Settings flow.
---

# CasprFlow macOS Automation

## Scope

The OS-facing mechanics of CasprFlow. Native Mac plumbing, not product strategy or
model prompting.

## Required patterns

- Swift + AppKit for OS integration; SwiftUI for the small visible HUD only.
- Menu-bar/background app (`NSStatusItem`).
- `NSPanel` (via the kept `FloatingPanel`) for the voice HUD and the artifact window.
- On-device `SFSpeechRecognizer` (`requiresOnDeviceRecognition = true`) + `AVAudioEngine`
  for streaming transcript + mic level. No cloud STT.
- `NSPasteboard` + synthetic Cmd+V (the kept `PasteService`) for paste-into-app output.
- Programmatic execution **first** — `NSWorkspace.open` (URLs/apps), `NSAppleScript`/
  `osascript`, deep links, `Process` (CLI). Computer-use (`control_ui`) is the **gated
  last tier**, Accessibility-first, vision only as fallback — never the default path.

## Hotkey (push-to-talk)

- Fixed hotkey: **Option + Space**. No picker.
- Registered via the kept `HotkeyService` using Carbon `RegisterEventHotKey` with **both**
  `kEventHotKeyPressed` and `kEventHotKeyReleased`:
  `registerDefaultHotkey(onPress:onRelease:)`.
- Press = begin listening (show HUD, start capture). Release = stop capture, show spinner,
  hand the transcript to the router.
- A press-only `registerDefaultHotkey(handler:)` overload remains for non-PTT uses.

## Voice HUD

A tiny center-bottom indicator, not an interactive window:

- Built on `FloatingPanel` (`make(size:)`, `positionCenterBottom()`), prewarmed once.
- Listening state: a sine-wave animation driven by mic RMS level.
- Processing state: the existing `CasprFlowLogoMark` spinner. The sine wave should *morph*
  into the spinner, not hard-swap.
- Escape dismisses. No text field.

## Paste flow (output)

1. Capture final text (verbatim dictation, or a short drafted reply).
2. `PasteService.paste(text, into: targetPID)` — it snapshots the pasteboard, sets text,
   reactivates the target app, sends synthetic Cmd+V, and restores the pasteboard.
3. **Never send automatically.** The user presses send.

## Programmatic execution

- Open URL/deep link: `NSWorkspace.shared.open(url)`.
- Launch/focus app: `NSWorkspace.shared.openApplication` or by bundle id.
- Scriptable apps / window control: `NSAppleScript` or `osascript` via `Process`.
- CLI / agents / `clickhouse-client`: `Process` with captured stdout/stderr + timeout.
  Resolve full tool paths (`~/.local/bin/claude`, `/opt/homebrew/bin/codex`).

## Computer-use (`control_ui`) — tier 3, last resort (phases 13–14)

Reached **only** when no URL scheme / AppleScript / CLI can do it. Two halves, AX first.

**Accessibility driving (phase 13, the fast/local half):**
- Use `AXUIElement` APIs: `AXUIElementCreateApplication(pid)`,
  `AXUIElementCopyAttributeValue` for `kAXChildrenAttribute`/`kAXRoleAttribute`/
  `kAXTitleAttribute`/`kAXValueAttribute`/`kAXIdentifierAttribute`, and
  `AXUIElementCopyAttributeValues` to walk the tree.
- Flatten the tree to bounded `AXNode`s (cap node count). Match a target by
  role + title-substring + identifier. Re-resolve by index-path if the tree changed.
- Act with `AXUIElementPerformAction(el, kAXPressAction)` and
  `AXUIElementSetAttributeValue(el, kAXValueAttribute, …)`.
- Gate by `AXIsProcessTrusted()`; if untrusted, route to the permission guide.
- Keep the tree walk + selector matching **pure** so they unit-test without a live app.
- Budget: snapshot+find+act `< 150 ms`. No model in this loop unless the caller picks the
  selector. No pixels.

**Vision fallback (phase 14, the slow/gated half):**
- Screenshot the target window/display: ScreenCaptureKit (`SCScreenshotManager` /
  `SCStream`) preferred; `CGWindowListCreateImage` acceptable. Needs **Screen Recording**.
- Send screenshot + goal + action history to a `ComputerUseModel` (Anthropic computer-use,
  separate client/key) → one `ComputerAction` in **logical points**.
- Perform with `CGEvent`: `CGEvent(mouseEventSource:…)` move+click,
  `CGEvent(keyboardEventSource:…)` / `keyboardSetUnicodeString` to type, scroll events.
  Convert logical points → device pixels (Retina scale) and offset by the target window
  origin — keep this coordinate math pure + unit-tested.
- Confirm before the first action and before any submit/send action. HUD shows "working"
  the whole time. Step + wall-clock budget; Escape cancels (cooperative).
- The model receives only the screenshot + goal + history — no other data leaves the box.

## Permissions

Kept blunt and minimal, and **preserve the drag-the-app-into-Settings flow**
(`Permissions/PermissionDragSourceView.swift` + `PermissionGuideController`):

- **Accessibility** — required for synthetic key events / paste **and the `control_ui` AX
  driving + `CGEvent` synthesis**. Now load-bearing, not optional.
- **Screen Recording** — required for the `control_ui` vision fallback screenshots. Route
  to the guide when a vision step needs it and it's missing; never silently no-op.
- **Microphone** + **Speech Recognition** — required for voice; add the Info.plist usage
  strings (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`) in
  `Scripts/create_app_bundle.sh`. Surface a clear HUD error if denied.
- Show plain permission-needed states; no complex onboarding.

## Latency

- Prewarm the HUD panel once; show is `orderFrontRegardless` + position only.
- Show the listening HUD on press and the spinner on release with no work in between.
- Keep the audio engine warm-but-cheap so capture starts instantly on press.

## Common failure checks

- Hotkey fires but no release event: confirm both pressed+released event kinds are
  installed in `HotkeyService`.
- Paste fails: verify Accessibility granted, target app reactivated before Cmd+V, the
  field accepts paste, and the pasteboard holds the final text.
- No transcript: verify Microphone + Speech permission, on-device recognizer availability,
  and that the audio tap is installed before `start`.
