# Latency contract

The product exists to feel instant. Treat latency as a hard requirement, not a
polish item. If a feature can't hit its budget, change the approach, not the budget.

## Budget (target, common path)

| Stage | Target | Mechanism |
|---|---|---|
| hotkey → bar visible | < 16 ms | panel allocated once at launch; invoke = `orderFrontRegardless` only |
| voice transcript ready | ~0 network | on-device `SFSpeechRecognizer`; partials arrive as you speak |
| Tier-0 route | < 2 ms | pure-Swift regex/keyword; no allocation-heavy work |
| dispatch (URL / AppleScript / deep link) | < 100 ms | `NSWorkspace.open`, `osascript`, deep links |
| Tier-1 route (fallback only) | ~300–600 ms | warm TLS + tiny structured output + low reasoning |
| **end-to-end, Tier-0 demo** | **sub-second wall clock** | sum of the above, excluding the target app's own launch time |

## Tactics (build these in, not after)

1. **Prewarm the window.** `CommandBarPanel` is created once in `AppCoordinator.init`
   and reused. Never allocate a panel on the hotkey path.
2. **Optimistic spinner.** Show the spinner the instant the user submits, before the
   router returns. Perceived latency drops even when work is real.
3. **Deterministic fast-path.** The Tier-0 router covers every known command shape
   (the three demos) with zero network. The LLM is a fallback, not the default.
4. **Warm the TLS connection.** Call `LLMClient.preconnect()` at launch so the first
   Tier-1 request isn't paying for a cold handshake.
5. **One long-lived `URLSession`.** Reuse a single session; don't churn connections.
6. **On-device STT.** No speech audio leaves the machine; no network round-trip on the
   voice path.
7. **Speculative prefetch.** On a high-confidence Tier-0 prefix ("open…", "search…"),
   begin launching the target app while finalizing slots.
8. **Tiny model outputs.** When Tier-1 runs, request the smallest possible structured
   output (intent + slots only) with `reasoning.effort = low` and a small
   `max_output_tokens`.

## How to measure

Log three timestamps per dispatch: `submit`, `route-done`, `dispatch-done`. Print the
deltas in debug builds. Acceptance: Tier-0 paths show `submit → dispatch-done` well
under 150 ms (excluding the target app's own launch), and end-to-end feels sub-second.

## Anti-patterns

- Do **not** make the LLM router the default path.
- Do **not** rebuild the panel per invocation.
- Do **not** use vision/computer-use to perform actions — always prefer URL schemes,
  AppleScript, deep links, or CLI.
- Do **not** block the main thread on network; route on a task, keep the UI live.
