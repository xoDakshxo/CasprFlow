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
| `FloatingPanel.swift` | Borderless, floating, non-activating `NSPanel`. `FloatingPanel.make(size:)`, `positionCenterBottom()`, `onEscape`. Plus `HUDPlaceholderView`. | Create **once** at launch (already done in `AppCoordinator`). The voice HUD swaps its `contentView`; phase 15 reuses the same shell for the always-on-top `ArtifactWindow`. |

## LLM connector

| File | What it is | How to use it |
|---|---|---|
| `LLMClient.swift` | Text-only OpenAI Responses client. `LLMConfig.load()` (env → `casprflow.config.local.json` → app-support), `complete(prompt:instructions:textFormat:maxOutputTokens:)`, `preconnect()`, plus static `requestBody`/`extractOutputText`. | Backs the **Planner** (phase 10) and **TaskAgent** (phase 12) via the `LLMCompleting` seam — inject stubs in tests. Pass a JSON-schema `textFormat` for strict structured output. `preconnect()` at launch warms TLS. The vision computer-use model (phase 14) uses a **separate** Anthropic client, not this one. |

Model default is `gpt-5.4-nano` (fast planner/agent). Config keys: `openai_api_key`,
`openai_model`, `openai_reasoning_effort`; v3 adds `anthropic_api_key`,
`computer_use_model`, `computer_use_enabled` (phase 14) and `planner_timeout_ms` (phase 16).

## Paste / output

| File | What it is | How to use it |
|---|---|---|
| `PasteService.swift` | `paste(_:into:)`: snapshots the pasteboard, sets text, activates the target app, sends synthetic Cmd+V, restores the pasteboard. | The output path for the `paste_text` capability (phase 15) and any paste-into-app action. `.confirm` side-effect; **never auto-send** — paste only. |
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
Voice adds two more system prompts (Microphone + Speech Recognition). v3 makes
**Accessibility + Screen Recording load-bearing** for the `control_ui` computer-use
capability (AX driving + screenshots) — see phases 13–14. The Info.plist voice keys are
in [`implementation/phase-1-voice-hud.md`](implementation/phase-1-voice-hud.md#permissions--bundle).

## Kept executors (reused by v3 capabilities — do not rewrite)

These shipped in the v2 phases and are **wrapped as capabilities** in v3 (phase 8), not
replaced:

- `Input/VoiceHUDController.swift`, `Input/VoiceInputService.swift`, transcript HUD —
  push-to-talk + on-device STT. The streaming partials drive **speculative planning**.
- `Exec/URLSchemeLauncher.swift`, `Exec/AppLauncher.swift`, `Exec/AppleScriptRunner.swift`,
  `Exec/ShellRunner.swift` (+ `ShellCommandPolicy`) — the programmatic primitives behind
  `open_url`/`open_app`/`web_search`/`run_shell`/`run_applescript`.
- `Exec/SwarmHost.swift` + `Exec/GhosttyHost.swift` (`TmuxHost`/`WarpHost` alternates),
  `Exec/ProjectResolver.swift`, `Exec/ProjectAliasStore.swift`,
  `Exec/ProjectClarificationService.swift` — behind `spawn_swarm`.
- `Routing/BrowserSearchURLBuilder`, the spoken-number/URL-normalization helpers — reused
  by the FastRouter `fastMatch` implementations (phase 9).

## Superseded by v3 (deleted as their replacement phase lands)

- `Routing/Intent.swift`, `Routing/IntentRouter.swift` (`DeterministicRouter`),
  `Routing/LLMRouter.swift` (`LLMRouter`/`TieredIntentRouter`),
  `Handlers/ActionHandler.swift` (`HandlerRegistry`) and the per-action handler files —
  their logic moves into capabilities + FastRouter + Planner. Phase 9 deletes
  `DeterministicRouter`; phase 11 deletes the rest. **One brain in the tree at a time.**

## Added by the v3 build

- Phase 8: `Capability`, `CapabilityRegistry`, `JSONValue`, `ExecutionContext`, builtin
  capability wrappers.
- Phase 9: `FastRouter` + `fastMatch` on the builtins.
- Phase 10–11: `Planner`, `Orchestrator`, clarify/confirm gates, speculative planning.
- Phase 12: `Agent/TaskAgent.swift` + `run_task` capability.
- Phase 13–14: `ControlUI/AccessibilityDriver.swift`, `ControlUI/ComputerUseModel.swift`,
  `ScreenCapturer`, `EventSynthesizer`, `control_ui` capability.
- Phase 15: `Exec/ArtifactWindow.swift`, `draft_artifact` + `paste_text` capabilities.
- Phase 16: telemetry, config surface, allowlists, graceful degradation.

Each is specified in [`implementation/`](implementation/README.md).
