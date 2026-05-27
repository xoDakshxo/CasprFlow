# Architecture

## One-line model

`hold hotkey → voice → intent router → handler dispatch → result`

The router has two tiers: a deterministic fast-path (zero network) that covers the
known command shapes, and an LLM fallback (OpenAI nano) for the long tail. Handlers
are programmatic executors — URL schemes, AppleScript, CLI — never vision.

## Design principle: universal primitives, thin handlers

CasprFlow is a **general dispatcher**, not a launcher for a fixed app list. The core
is a small set of **app-agnostic executor primitives**; handlers are thin compositions
over them. New capability = new handler over the same primitives. Keep app-specific
knowledge at the edge (in a handler or config), never in the core.

**Executor primitives (the universal layer):**

| Primitive | Does | Backs (examples) |
|---|---|---|
| `URLSchemeLauncher` | Open any URL / deep link | web search, `slack://`, `things://`, maps |
| `AppLauncher` | Launch / focus any app by bundle id or name | "open Figma", bring app forward |
| `AppleScriptRunner` | Run arbitrary AppleScript / JXA | drive scriptable apps, window control |
| `ShellRunner` | Run any shell/CLI command (`Process`) | git, `clickhouse-client`, any tool |
| `PasteService` (kept) | Paste text into the focused app | reply drafts, snippets — never auto-send |
| `ArtifactWindow` | Floating always-on-top panel that streams model output + exposes actions (Run/Copy/Dismiss) | SQL agent, any "draft then act" flow |
| `SwarmHost` | Spawn N terminal panes each running a command | agent swarms (Warp/tmux/iTerm impls) |

The reference handlers below (browser search, agent swarm, Slack reply, SQL artifact)
exist to prove the primitives. They are **examples, not the scope** — the registry is
open-ended.

## Layer diagram

```
Hold Option+Space (push-to-talk)
   │  press                                    release
   ▼                                              │
VoiceHUDController ── prewarmed FloatingPanel, center-bottom, small
   │  listening: live partial transcript pill     │
   │  VoiceInputService: on-device SFSpeechRecognizer, streaming partials
   ▼  (on release → final transcript)             ▼ processing: spinner + late transcript
IntentRouter
   ├─ Tier 0  DeterministicRouter   regex/keyword → Intent      (~0 ms)
   └─ Tier 1  LLMRouter (nano)       strict-JSON classify → Intent (fallback only)
   │
   ▼
HandlerRegistry ── first ActionHandler whose match(Intent) == true wins
   │   (open-ended; reference handlers shown — add more freely)
   ├─ OpenAppHandler / ShellCommandHandler / OpenURLHandler   ← generic, app-agnostic
   ├─ BrowserSearchHandler  → URLSchemeLauncher   (open a search URL)
   ├─ AgentSwarmHandler     → SwarmHost            (Warp/tmux/iTerm impl)
   ├─ SlackReplyHandler     → PasteService         (paste into focused composer)
   └─ SQLArtifactHandler    → ArtifactWindow + ShellRunner  (stream query, Run)
   │
   ▼   (handlers compose executor primitives — see table above)
ActionResult → HUD dismisses / brief result toast
```

## Components

| Component | Responsibility | State |
|---|---|---|
| `VoiceHUDController` | Own the prewarmed HUD panel; drive the transcript→spinner states; emit the final transcript into the route→dispatch loop. | **to build** (phase 1) |
| `VoiceInputService` | On-device streaming STT + mic level; start on press, stop on release. | **to build** (phase 1) |
| `Intent` | Value type: `kind` (enum) + `slots: [String: String]` + `confidence`. | **to build** (phase 2) |
| `IntentRouter` | Tier-0 deterministic + Tier-1 LLM fallback; returns an `Intent`. | **to build** (phase 2, 7) |
| `ActionHandler` / `HandlerRegistry` | Protocol + ordered registry; first match executes. | **to build** (phase 2) |
| Handlers | One per action class; programmatic execution. | **to build** (phase 3–6) |
| Executors | `URLSchemeLauncher`, `AppleScriptRunner`, `ShellRunner`, `SwarmHost`. | **to build** (phase 3–4) |
| `LLMClient` | Text-only OpenAI Responses client + config + preconnect. | **kept** |
| `FloatingPanel` | Borderless floating non-activating NSPanel shell (voice HUD + artifact window). | **kept** |
| `HotkeyService` | Carbon global hotkey (Option+Space). | **kept** |
| `PasteService` | Synthetic Cmd+V + clipboard snapshot/restore. | **kept** |
| Permission stack | Accessibility + Screen Recording guide, drag-into-Settings flow. | **kept** |
| `StatusItemController` | Menu-bar item, permission shortcuts, enable/disable, quit. | **kept** |

See [`connectors.md`](connectors.md) for exact file paths and usage of the kept core.

## Data flow (one dispatch)

1. Hotkey **pressed** → `VoiceHUDController` shows the prewarmed HUD (no allocation) and
   starts on-device capture; partial transcript text updates in the pill.
2. User speaks while holding; partials stream locally.
3. Hotkey **released** → capture stops, the HUD transitions to the spinner, late/final
   transcript text remains visible briefly, and the final transcript goes to `IntentRouter`.
4. Tier-0 deterministic match returns an `Intent` synchronously. Only on a miss does
   Tier-1 hit the network.
5. `HandlerRegistry` picks the first handler whose `match(Intent)` is true and calls
   `execute`.
6. The handler runs a programmatic executor (open URL, run AppleScript, spawn CLI,
   paste). It returns an `ActionResult`.
7. The HUD dismisses (or shows a brief toast). Hard-to-reverse actions (sending) are
   never auto-performed — paste, don't send.

## Intent model (target shape)

The kinds below are the seed set — the enum is meant to grow as handlers are added.
Generic kinds (`openApp`, `openURL`, `shell`) make most "do X" commands expressible
without a bespoke kind; specialized kinds exist only where a handler needs richer
slots.

```swift
enum IntentKind {
    // generic, app-agnostic — cover most commands
    case openApp            // slots: app
    case openURL            // slots: url
    case shell              // slots: command
    // specialized reference handlers
    case browserSearch      // slots: query, engine?
    case agentSwarm         // slots: count, task, tool(claude|codex), dir?
    case slackReply         // slots: recipient, message
    case sqlArtifact        // slots: request  (skill-loaded agent → artifact window)
    case unknown
}

struct Intent {
    let kind: IntentKind
    let slots: [String: String]
    let confidence: Double   // 1.0 for deterministic matches
    let rawText: String
}
```

The deterministic router fills `confidence = 1.0`; the LLM router returns its own
confidence. Handlers read `slots`; missing slots fall back to safe defaults or a
clarifying re-prompt in the HUD.
