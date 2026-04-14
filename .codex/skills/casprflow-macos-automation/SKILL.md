---
name: casprflow-macos-automation
description: Implement or debug CasprFlow native macOS automation. Use for AppKit/SwiftUI menu-bar behavior, fixed global hotkey registration, selected-text capture, clipboard preservation, Accessibility/Input Monitoring permissions, focus restoration, synthetic copy/paste, borderless reply capsule windows, and paste-into-active-app bugs.
---

# CasprFlow macOS Automation

## Scope

Use this skill for the OS-facing pieces of CasprFlow. Keep it focused on native Mac mechanics, not product strategy or model prompting.

## Required Patterns

- Use Swift and AppKit for OS integration.
- Use SwiftUI only for small visible UI where it is faster.
- Run as a menu-bar/background app.
- Use `NSStatusItem` for the menu.
- Use `NSPanel` for the reply capsule.
- Use `NSPasteboard` for selected-text capture and final paste.
- Use synthetic `Command + C` and `Command + V` pragmatically.
- Save the previous active app before opening the capsule.
- Return focus before paste.
- Restore clipboard best-effort; do not block the MVP on perfect clipboard restoration.

## Hotkey

MVP uses a fixed hotkey:

- Use `Option + Space`.
- Register it at launch.
- Show a simple error if registration fails.
- Do not build a hotkey picker.
- Do not add a full settings screen.

## Selected Text Capture

Use this flow:

1. Store current pasteboard string if available.
2. Send synthetic `Command + C`.
3. Wait briefly for pasteboard update.
4. Read selected text.
5. Restore prior pasteboard string best-effort.
6. If selected text is empty, show the capsule with `Highlight a message first.`

Do not attempt app-specific accessibility text extraction in the MVP.

## Reply Capsule

The capsule should feel like a small inline command bubble:

- borderless floating `NSPanel`
- one focused editable text control
- max 3-4 visible lines
- subtle learned label when available
- footer text: `Enter paste | Cmd+R regenerate | Esc`

Keyboard behavior:

- `Enter`: paste current text
- `Command + R`: regenerate from current edited text
- `Escape`: close without paste

Avoid modal windows, side panels, document editor styling, and large overlays.

## Paste Flow

Use this sequence:

1. Capture final capsule text.
2. Store learning if final text differs from generated text.
3. Put final text on pasteboard.
4. Reactivate previous app.
5. Send synthetic `Command + V`.
6. Close the capsule.
7. Restore prior pasteboard best-effort after a short delay.

Never send the message automatically.

## Permission Handling

Keep permissions blunt and minimal:

- Accessibility is required for synthetic key events and focus/paste behavior.
- Input Monitoring may be required depending on the chosen hotkey implementation.
- Show a plain permission-needed state.
- Do not build complex onboarding.

## Common Failure Checks

If hotkey works but paste fails:

- verify Accessibility permission
- verify previous app is restored before paste
- verify the focused field accepts paste
- verify the pasteboard contains the final reply before `Command + V`

If capture returns empty:

- verify text was selected
- increase the pasteboard wait slightly
- ensure clipboard restoration is not running before reading selection
