---
name: casprflow-macos-automation
description: Implement or debug CasprFlow native macOS mechanics. Use for AppKit/SwiftUI menu-bar behavior, push-to-talk global hotkey (press+release), on-device speech capture, the center-bottom voice HUD panel, programmatic action execution (URL schemes, AppleScript, deep links, CLI via Process), synthetic paste + clipboard preservation, Accessibility/Microphone/Speech permissions, and the drag-into-Settings permission flow.
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
- Programmatic execution only — `NSWorkspace.open` (URLs/apps), `NSAppleScript`/`osascript`,
  deep links, `Process` (CLI). **Never** screenshot→model→click.

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

## Permissions

Kept blunt and minimal, and **preserve the drag-the-app-into-Settings flow**
(`Permissions/PermissionDragSourceView.swift` + `PermissionGuideController`):

- **Accessibility** — required for synthetic key events / paste.
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
