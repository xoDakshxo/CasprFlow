# Knowledge Fast Replies MVP Phases

Execute these phases in order. Each phase must leave the app in a manually testable state.

| Phase | File | Outcome |
|---|---|---|
| 0 | [phase-0-baseline-and-contracts.md](phase-0-baseline-and-contracts.md) | Confirm current behavior, add data contracts, no product behavior change |
| 1 | [phase-1-capture-pack.md](phase-1-capture-pack.md) | Build compact capture packet with screenshot gate and redaction |
| 2 | [phase-2-two-call-context-and-output.md](phase-2-two-call-context-and-output.md) | Build-context parses the screenshot, then build-output returns three chips plus three drafts |
| 3 | [phase-3-fast-capsule-flow.md](phase-3-fast-capsule-flow.md) | Capsule renders fallback chips fast, then swaps hydrated drafts locally |
| 4 | [phase-4-learning-event-store.md](phase-4-learning-event-store.md) | Paste writes local learning events and style signals |
| 5 | [phase-5-local-knowledge-retrieval.md](phase-5-local-knowledge-retrieval.md) | Next reply retrieves local style/person/app/project hints |
| 6 | [phase-6-robustness-and-privacy.md](phase-6-robustness-and-privacy.md) | Timeouts, malformed output, missing permissions, redaction, reset behavior |
| 7 | [phase-7-end-to-end-mvp-demo.md](phase-7-end-to-end-mvp-demo.md) | Real-app manual demo pass and MVP closeout |

## Phase Rule

Do not skip ahead. If a later phase needs an API or model introduced earlier, add only a placeholder in the earlier phase and implement behavior in its own phase.

## Report Rule

After each phase, write:

```text
docs/knowledge-fast-replies-mvp/reports/phase-N-name.md
```

Every report must include:

- files changed
- build and test results
- manual test steps run
- what works now
- what is intentionally not implemented yet
- blockers or known issues
