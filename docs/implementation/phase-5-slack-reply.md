# Phase 5 — Realtime Slack reply

## Goal

The realtime moment: a Slack notification comes in, you hold the hotkey and say "reply
to Prachi that we'll ship Friday", and a draft is pasted into the Slack composer in near
real time. **Never auto-sent** — the user presses send.

## Build

- `Sources/CasprFlowCore/Handlers/SlackReplyHandler.swift` — `.slackReply` →
  (optionally) draft the message → paste into the focused Slack composer.

## Flow

1. Slots from the router: `recipient`, `message`.
2. If `message` is already a complete sentence (the common case — the user dictated the
   reply), use it verbatim. If it's terse ("tell Prachi we're on track"), optionally
   expand it into a natural reply via `LLMClient` (nano, one short sentence, the user's
   style from config). Keep this fast and optional.
3. Bring Slack forward / ensure the composer is focused (the user typically triggered
   this from the Slack notification, so Slack is frontmost). Optionally use a
   `slack://` deep link or AppleScript to focus the right conversation.
4. `PasteService.paste(message, into: slackPID)` — synthetic Cmd+V into the composer.
5. Stop. Do not send.

## Reuse

- `PasteService.paste(_:into:)` — the kept paste connector (snapshots + restores the
  pasteboard). This is exactly its job.
- `LLMClient.complete(...)` — optional drafting; load the user's style from
  `casprflow.config.local.json` (`user_name`, `user_style`).
- `URLSchemeLauncher` / `AppLauncher` — focus Slack if needed.

## Style / intent

When drafting, the model must write **as the user**: pull `user_name` + `user_style`
from config, keep it to one concise sentence, no fake enthusiasm, no em dashes. The
point is a reply the user can send as-is.

## Latency

If using verbatim dictation (no drafting), this is just a paste — instant. If drafting,
it's one small nano call; keep `max_output_tokens` tiny and `reasoning.effort = low`,
and warm the connection (`preconnect`).

## Acceptance

- With Slack focused, hold hotkey, say "reply to Prachi we'll ship Friday" → the draft
  appears in the composer, not sent.
- Pasteboard is restored afterward (the kept `PasteService` already does this).
- `swift build` green, `CasprFlowChecks` passes.
