# Decisions log

Locked technical choices for the v2 pivot. Carry these into the build; revisit only
with reason.

## D1 — Native Swift / AppKit, not Electron or web

The hotkey, window, Accessibility, synthetic paste, and on-device speech all want the
native path. Swift gives the lowest-latency hotkey + window + AX + paste with no
runtime overhead. Keep the existing SwiftPM native app.

## D2 — Programmatic dispatch, never vision

Handlers fire via URL schemes, AppleScript, deep links, and CLI. No screenshot →
model → click loops. This is the only way to hit the latency budget and stay
reliable.

## D2b — Universal by design; the three flows are examples, not the scope

CasprFlow is a **general dispatcher**, not a launcher for a fixed set of apps. The
design is: a small set of **app-agnostic executor primitives** (open any URL, launch
any app, run any AppleScript, run any shell/CLI command, paste into any app, stream
into a floating artifact window, spawn an agent swarm) and **thin handlers** composed
from them. Adding a capability means adding a handler over the same primitives — no
new plumbing. Do **not** hardcode app-specific assumptions into the core; keep them at
the edge (a handler, a config entry). The browser-search, agent-swarm, and SQL flows
are reference handlers that prove the primitives, not a ceiling.

## D3 — Two-tier router; deterministic first

A deterministic regex/keyword router (Tier 0) handles every known command shape with
zero network. An LLM router (Tier 1) is the fallback for the long tail. The common
path never waits on a model.

## D4 — Router LLM fallback = OpenAI nano

Reuse the existing OpenAI key + client (`LLMClient`, default `gpt-5.4-nano`) with
strict structured output, `reasoning.effort = low`, tiny `max_output_tokens`. Chosen
for zero new setup. A faster provider (Groq/Cerebras) or a local classifier can swap
in later behind the same `IntentRouter` seam if Tier-1 latency matters.

## D5 — Input: voice only, on-device STT

Push-to-talk voice via Apple `SFSpeechRecognizer` with `requiresOnDeviceRecognition =
true`, streaming partial results into the HUD. There is no command text box; only rare
project/path ambiguity can open a native clarification prompt that is remembered.
On-device keeps the voice path off the network. Higher-quality STT must use a
persistent/in-process local engine; per-utterance CLI model startup is too slow for the
push-to-talk hot path.

## D6 — Agent swarm via a swappable `SwarmHost` (Ghostty default)

The agent-swarm handler talks to a `SwarmHost` protocol; the terminal is an
implementation detail. **Ghostty** is the default host because it provides native
macOS panes with scriptable window/tab/terminal control and avoids the nested tmux UI.
`TmuxHost` and `WarpHost` remain alternate implementations, and iTerm can drop in behind
the same protocol without touching the handler. The handler expands short phrases
through project resolution and task slicing before it reaches the host, so the terminal
receives complete per-pane prompts. Codex is the default agent tool; Claude remains an
explicit slot option. Don't let any single terminal leak into the core. `claude`
(`~/.local/bin`), `codex` (`/opt/homebrew/bin`), and `tmux` (`/opt/homebrew/bin`) are
installed; Ghostty is required for the default host.

## D7 — Floating artifact window is a first-class primitive

The "get this doc ready for Prachi" flow (skill-loaded SQL agent → stream a query into
a floating always-on-top artifact window → user clicks Run → paste into ClickHouse →
confirm) is **in the design** as a reference use case. Its building block — a floating
always-on-top **artifact window** that streams model output and exposes actions
(Run/Copy/Dismiss) — is a reusable executor primitive, built on the `FloatingPanel`
shell. Implementation is sequenced after the simpler handlers, but the architecture
must not design it out.

## D8 — Never auto-send

Reply/output actions paste into the target app and stop. The user presses send. This
keeps outward-facing actions under human control (matches the kept Slack-reply paste
flow).
