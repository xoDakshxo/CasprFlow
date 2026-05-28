# Connectors — the kept core

After the pivot these are the only source files left in `Sources/CasprFlowCore/`.
They are the reusable native substrate the dispatcher is built on. Do not rewrite
them from scratch — wire the new code into them.

## Shell

| File | What it is | How to use it |
|---|---|---|
| `CasprFlowApp/main.swift`, `AppDelegate.swift`, `CasprFlowApplication.swift` | App entry; `NSApplication` + delegate that constructs `AppCoordinator`. | Leave as-is. The app is a menu-bar/agent (`LSUIElement`-style) app. |
| `AppCoordinator.swift` | Top-level wiring: registers the push-to-talk hotkey, owns permissions + status item, shows the prewarmed voice HUD (`startListening`/`stopListening`). | The integration point. Phase 1 grows the HUD into live voice capture; phases 2+ add the route→dispatch loop. |
| `StatusItemController.swift` | Menu-bar item: enable/disable, permission shortcuts, quit. Hotkey label reads from `HotkeyDescriptor`. | Add menu entries here if needed; keep it light. |
| `CasprFlowLogo.swift` | Logo image API + `CasprFlowLogoMark` SwiftUI view with a `TimelineView(.animation)` spinner. | Reuse `CasprFlowLogoMark` for the HUD's processing spinner. |

## Hotkey

| File | What it is | How to use it |
|---|---|---|
| `HotkeyService.swift` | Carbon `RegisterEventHotKey` global hotkey with **press + release** (push-to-talk). `registerDefaultHotkey(onPress:onRelease:)`; a press-only `registerDefaultHotkey(handler:)` overload remains. | Already wired in `AppCoordinator` as press = listen, release = process. Don't add a picker. |
| `HotkeyDescriptor.swift` | The fixed hotkey: **Option + Space** (`keyCode 49`, modifiers `optionKey == 2048`). | Source of truth for the hotkey; the checks target asserts it. |

## Floating window shell (voice HUD + artifact window)

| File | What it is | How to use it |
|---|---|---|
| `FloatingPanel.swift` | Borderless, floating, non-activating `NSPanel`. `FloatingPanel.make(size:)`, `positionCenterBottom()`, `onEscape`. Plus `HUDPlaceholderView`. | Create **once** at launch (already done in `AppCoordinator`). Phase 1 swaps its `contentView` for the live transcript→spinner HUD; phase 6 reuses the same shell for the always-on-top artifact window. |

## LLM connector

| File | What it is | How to use it |
|---|---|---|
| `LLMClient.swift` | Text-only OpenAI Responses client. `LLMConfig.load()` (env → `casprflow.config.local.json` → app-support), `complete(prompt:instructions:textFormat:maxOutputTokens:)`, `preconnect()`, plus static `requestBody`/`extractOutputText`. | Tier-1 router fallback. Pass a JSON-schema `textFormat` for strict structured classification. Call `preconnect()` at launch to warm TLS. |

Model default is `gpt-5.4-nano` (fast classifier). Config keys:
`openai_api_key`, `openai_model`, `openai_reasoning_effort`.

## Paste / output

| File | What it is | How to use it |
|---|---|---|
| `PasteService.swift` | `paste(_:into:)`: snapshots the pasteboard, sets text, activates the target app, sends synthetic Cmd+V, restores the pasteboard. | The output path for `SlackReplyHandler` and any paste-into-app action. **Never auto-send** — paste only. |
| `SelectionTextNormalizer.swift` | Trim/clean a captured string. | Small util; reuse when normalizing recognized speech or captured text. |

## Permissions (kept whole — the drag-into-Settings flow)

| File | What it is |
|---|---|
| `AccessibilityPermissionService.swift` | Trust check for Accessibility (required for synthetic paste/key events). |
| `Permissions/ScreenRecordingPermissionService.swift` | Screen Recording grant check. |
| `Permissions/PermissionGuideController.swift` | Presents the permission guide window; opens the right System Settings pane. |
| `Permissions/PermissionGuidePanel.swift` | Enum of guide panels (`.accessibility`, `.screenRecording`) → Settings pane mapping. |
| `Permissions/PermissionDragSourceView.swift` | The drag source so the user can **drag the CasprFlow app icon into the Settings permission list**. |
| `Permissions/SystemSettingsWindowLocator.swift` | Finds/raises the System Settings window for the guide. |

This whole flow is preserved intentionally (including the drag-into-Settings source).
Voice adds two more system prompts (Microphone + Speech Recognition); the Info.plist
keys are listed in [`implementation/phase-1-voice-hud.md`](implementation/phase-1-voice-hud.md#permissions--bundle).

## Added by the phased build

- Phase 1: `VoiceHUDController`, `VoiceInputService`, transcript HUD view.
- Phase 2: `Intent`, deterministic `IntentRouter`, `ActionHandler`, `HandlerRegistry`,
  and the route→dispatch loop.
- Phase 3: `URLSchemeLauncher`, `AppLauncher`, `AppleScriptRunner`, `ShellRunner`, plus
  generic handlers for browser search, open URL, open app, and guarded shell commands.
- Phase 4: `SwarmHost` + default `GhosttyHost` (`TmuxHost`/`WarpHost` kept as
  alternates), `ProjectResolver`, `ProjectAliasStore`, `ProjectClarificationService`,
  and `AgentSwarmHandler` for short spoken swarm commands that expand into scoped
  per-pane CLI prompts or open plain Codex panes.
- Phase 7: `LLMRouter` and `TieredIntentRouter` for strict-JSON OpenAI fallback only
  when the deterministic router returns `.unknown`; `LLMClient.preconnect()` runs at app
  launch.

Still to be added: Slack/paste reply and `ArtifactWindow`. Each is specified in
[`implementation/`](implementation/README.md).
