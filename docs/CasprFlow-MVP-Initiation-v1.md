# CasprFlow MVP Initiation
### One-day minimum viable build plan

## Purpose

CasprFlow is a Mac reply layer that helps the user answer messages without leaving the app they are already using.

The MVP should prove one thing:

**a user can highlight a message, press a hotkey, receive one reply that feels close to their style, edit it, paste it into the active app, and see the next reply adapt from that edit.**

This is not the full product. It is the smallest working version that communicates the core idea clearly.

The one-day goal is not to build a perfect Mac communication assistant. The goal is to create a believable working loop that makes the product feel real.

---

## MVP outcome

At the end of the one-day MVP, a user should be able to:

1. Highlight message text in any Mac text surface.
2. Press a global hotkey.
3. See a small overlay with one generated reply.
4. Edit the reply inside the overlay if needed.
5. Press Enter to paste the final reply into the active field.
6. Have CasprFlow store the difference between the generated reply and the edited reply locally.
7. See a small learned label, such as `learned: shorter` or `learned: no emojis`.
8. Generate a later reply that is influenced by the stored local preference.

This preserves the essential CasprFlow idea:

- in-context reply generation
- one-key activation
- one likely response
- user control
- local learning from corrections
- visible adaptation

---

## The MVP promise

The MVP promise is:

**Reply in place, with a draft that gets closer to you each time you correct it.**

This should be the product's first demo sentence.

The MVP should communicate that CasprFlow is not another writing screen. It is a light layer that appears only when needed, helps with the reply at hand, and improves from the user's own edits.

---

## One-day scope

### In scope

- Mac desktop app.
- Background/menu-bar app behavior.
- Global hotkey.
- Selection-first context capture.
- One generated reply.
- Small overlay UI.
- Editable reply field inside the overlay.
- Enter to paste the final reply into the active app.
- Local storage of generated reply, edited reply, and simple preference signals.
- Tiny learned-label feedback.
- Simple preference-aware prompt construction.
- Basic demo reliability in common text surfaces such as Notes, Messages, Slack, browser text boxes, or any focused input that accepts paste.

### Out of scope

- Auto-send.
- Detecting whether the user actually sent the message.
- Watching edits after the reply is pasted into another app.
- Deep app integrations.
- Browser extension.
- Mobile support.
- Relationship-specific memory.
- Full long-term personality model.
- Multiple response options.
- Tone mode picker.
- Complex onboarding.
- Account system.
- Cloud sync.
- Team features.
- Advanced analytics.

---

## Important MVP adjustment

The full concept says the user may edit the pasted reply before sending, and CasprFlow stores that edit delta.

For a one-day MVP, that is too fragile across arbitrary Mac apps. It requires deeper accessibility monitoring, app-specific behavior, or send-event detection.

The MVP should instead capture the edit inside CasprFlow's overlay:

1. CasprFlow generates the reply.
2. The overlay displays the draft in an editable field.
3. The user edits the draft there.
4. When the user presses Enter, CasprFlow stores the delta and pastes the final text.

This keeps the proof intact while avoiding the hardest integration problem on day one.

The user still experiences the important loop:

**AI writes something close, the user makes it theirs, and the system learns from that correction.**

---

## Core user flow

### First run

1. User launches CasprFlow.
2. App asks for the minimum required permissions:
   - Accessibility permission for global hotkey and paste behavior.
   - Optional clipboard access through normal pasteboard APIs.
3. App appears as a menu-bar item.
4. User sees a short instruction:
   - Highlight a message.
   - Press the hotkey.
   - Edit the reply.
   - Press Enter to paste.

### Reply generation

1. User highlights the message they want to answer.
2. User presses the CasprFlow hotkey.
3. CasprFlow temporarily copies the selected text.
4. CasprFlow restores the user's previous clipboard value if possible.
5. CasprFlow sends the selected context plus local preference signals to the model.
6. CasprFlow shows one reply in a compact overlay near the center of the screen or near the current cursor position.

### User correction

1. User accepts the draft as-is or edits it in the overlay.
2. User presses Enter.
3. CasprFlow compares:
   - generated draft
   - final edited text
4. CasprFlow stores the delta locally.
5. CasprFlow pastes the final text into the previously active field.
6. Overlay disappears.

### Next reply

1. User highlights another message.
2. User presses the hotkey.
3. CasprFlow includes learned preference signals in the prompt.
4. Reply reflects those signals where relevant.
5. Overlay shows a small learned label.

Example:

`learned: more direct`

---

## Minimum feature set

### 1. Menu-bar shell

The app should run quietly in the background and expose only minimal controls:

- Enable/disable CasprFlow.
- View hotkey.
- Clear local learning.
- Quit.

No full settings screen is required for the MVP.

### 2. Global hotkey

Use one fixed default hotkey for day one.

Recommended:

`Option + Space`

Do not build a hotkey picker for the MVP.

If registration fails, show a simple error.

### 3. Selected-text capture

Use a pragmatic copy-based approach:

1. Save current clipboard contents.
2. Simulate `Command + C`.
3. Read selected text from pasteboard.
4. Restore previous clipboard contents after context is captured.

If no selected text is found, show a small overlay state:

`Highlight a message first.`

This is acceptable for the MVP because selection-first context is part of the product principle.

### 4. Reply generation

Use one model call with a focused prompt.

The prompt should include:

- selected message context
- product instruction
- local preference summary
- hard limit to produce one reply only

The generated reply should be:

- short
- natural
- directly usable
- not overly polished
- not explanatory
- not wrapped in quotes

### 5. Overlay

The overlay should be small and fast.

Minimum UI elements:

- editable generated reply text
- learned label if a preference exists
- helper text: `Enter to paste, Esc to cancel`
- loading state while generating
- error state if model call fails

The overlay should not feel like a full editor. It should feel temporary.

### 6. Paste final reply

When the user presses Enter:

1. Store the final text.
2. Copy final text into clipboard.
3. Simulate `Command + V`.
4. Restore previous clipboard value after a short delay if practical.
5. Close overlay.

The MVP does not send the message. The user remains in control.

### 7. Local learning

Store the learning data locally in a simple file.

Recommended local storage:

`~/Library/Application Support/CasprFlow/preferences.json`

Minimum stored fields:

```json
{
  "examples": [
    {
      "createdAt": "2026-04-14T10:00:00Z",
      "context": "selected incoming message",
      "generated": "generated draft",
      "edited": "user edited final reply",
      "signals": ["shorter", "more_direct"]
    }
  ],
  "summary": {
    "shorter": 2,
    "more_direct": 1,
    "no_emojis": 1
  }
}
```

The MVP does not need embeddings, training, or complex memory.

### 8. Learned label

The learned label should be visible but subtle.

Examples:

- `learned: shorter`
- `learned: no emojis`
- `learned: more direct`
- `learned: warmer`

Only show one label at a time.

Pick the strongest current signal from the local summary.

---

## Lightweight learning rules

The MVP can infer preference signals with simple heuristics.

### Shorter

If the edited reply is at least 20 percent shorter than the generated reply:

`shorter`

### Longer

If the edited reply is at least 20 percent longer than the generated reply:

`more_context`

### No emojis

If the generated reply contains emoji and the edited reply removes them:

`no_emojis`

### More direct

If the user removes softening phrases such as:

- `I think`
- `maybe`
- `just`
- `if that works`
- `no worries if not`

Signal:

`more_direct`

### Warmer

If the user adds phrases such as:

- `thanks`
- `appreciate`
- `sounds good`
- `happy to`

Signal:

`warmer`

### Less excited

If the user removes exclamation marks:

`less_excited`

These rules are enough to make the product feel adaptive in a demo.

---

## Prompt shape

The model prompt should stay narrow.

Example system instruction:

```text
You generate one concise reply for the user.
Write in a natural personal tone.
Do not explain the reply.
Do not include alternatives.
Do not wrap the reply in quotes.
Respect the user's learned style preferences when they fit the context.
```

Example user message:

```text
Selected message:
{selected_context}

Learned preferences:
{preference_summary}

Write the reply the user is most likely to send.
```

If there are no learned preferences, pass:

`No learned preferences yet.`

---

## Suggested technical route

### Recommended stack

For the one-day MVP, use native Mac tooling:

- Swift
- SwiftUI
- AppKit where needed
- Menu bar app
- KeyboardShortcuts or a similar hotkey helper
- Gemini API for generation
- Local JSON file for learning storage

This route keeps the app close to the operating system and avoids building a browser extension or Electron shell before the interaction is proven.

### Main components

#### App shell

Responsibilities:

- start app
- register menu-bar item
- register hotkey
- request/check permissions

#### Selection service

Responsibilities:

- save clipboard
- simulate copy
- read selected text
- restore clipboard
- return clean context string

#### Generation service

Responsibilities:

- build prompt
- call model
- return one reply
- handle loading and errors

#### Overlay controller

Responsibilities:

- show overlay
- focus editable reply field
- handle Enter and Escape
- call paste service

#### Paste service

Responsibilities:

- copy final reply
- simulate paste
- optionally restore clipboard

#### Learning store

Responsibilities:

- save generated and edited text
- infer signals
- update local summary
- return strongest learned label
- return prompt-ready preference summary

---

## One-day build route

This is the minimum viable route to a demoable MVP.

### Hour 0 to 1: Project skeleton

- Create Mac app project.
- Add menu-bar mode.
- Add default hotkey.
- Add basic permission guidance.
- Add local app constants:
  - app name
  - hotkey
  - storage path

Done when:

- App launches.
- Menu-bar item appears.
- Hotkey callback fires.

### Hour 1 to 2: Selection capture

- Implement copy-based selected-text capture.
- Preserve and restore clipboard where possible.
- Show a simple error if no text is selected.

Done when:

- User can highlight text in another app.
- Hotkey captures that text.

### Hour 2 to 3: Overlay

- Build compact overlay window.
- Add loading state.
- Add editable reply field.
- Add `Enter to paste, Esc to cancel`.

Done when:

- Hotkey opens overlay.
- Overlay can display placeholder text.
- User can edit the field.

### Hour 3 to 4: Generation

- Add model API call.
- Build narrow prompt.
- Display generated reply in overlay.
- Add error handling.

Done when:

- Highlighted text becomes one generated reply.

### Hour 4 to 5: Paste flow

- Implement Enter behavior.
- Paste final overlay text into the previously active app.
- Close overlay after paste.

Done when:

- User can highlight a message, generate a reply, edit it, and paste the final reply into the active field.

### Hour 5 to 6: Local learning

- Create local JSON store.
- Save generated and edited reply.
- Add simple signal detection.
- Update preference summary.

Done when:

- Edits create local learning data.

### Hour 6 to 7: Preference-aware generation

- Convert stored signals into prompt text.
- Include learned preferences in the next generation.
- Show learned label in overlay.

Done when:

- Editing a reply changes the guidance used for future replies.
- Overlay can show `learned: ...`.

### Hour 7 to 8: Demo polish and failure handling

- Test in at least two common apps.
- Improve empty-selection behavior.
- Improve API error message.
- Add clear-learning menu item.
- Add README-style setup notes if needed.

Done when:

- The core loop works reliably enough to demo.

---

## Demo script

The MVP should be judged by this demo, not by a long feature checklist.

### Demo 1: First reply

1. Open a chat or text surface with a message like:

   `Can you send me the project update by tonight?`

2. Highlight the message.
3. Press the hotkey.
4. CasprFlow shows a reply:

   `Yes, I can send it over tonight.`

5. Press Enter.
6. Reply appears in the active field.

This proves in-place generation.

### Demo 2: Learning from correction

1. Highlight another message.
2. Generate a reply.
3. Edit the generated text to make it shorter or more direct.
4. Press Enter.
5. Generate a reply again.
6. Overlay shows:

   `learned: shorter`

7. The next draft is shorter.

This proves visible adaptation.

### Demo 3: User control

1. Generate a reply.
2. Press Escape.
3. Overlay disappears.
4. Nothing is pasted.

This proves the user remains in control.

---

## MVP success criteria

The MVP is successful if:

- The hotkey works while another app is active.
- Selected text becomes usable reply context.
- The app generates exactly one reply.
- The reply appears in a lightweight overlay.
- The user can edit the reply before insertion.
- Enter pastes the final reply into the active app.
- Escape cancels safely.
- At least one local learning signal is stored.
- At least one learned label appears after correction.
- A later generation is influenced by the learned signal.
- The whole flow is understandable in under 30 seconds.

The MVP is not judged by:

- perfect writing quality
- perfect memory
- every Mac app working
- detecting actual send events
- robust personalization across weeks
- production-grade onboarding

---

## Key risks

### Clipboard behavior

Copy/paste automation can temporarily disturb the user's clipboard.

MVP mitigation:

- Save and restore clipboard contents where possible.
- Keep the operation fast.
- Use clear fallback messages.

### Accessibility permissions

Mac automation requires user-granted permissions.

MVP mitigation:

- Show a simple permission-needed state.
- Do not hide this behind complex onboarding.

### App focus after overlay

The app must paste back into the original active app, not into the overlay.

MVP mitigation:

- Store the previously active app before opening overlay.
- Return focus before paste.
- Test with a small set of target apps.

### Model latency

A slow reply breaks the feeling of immediacy.

MVP mitigation:

- Keep selected context small.
- Use a fast model.
- Show loading immediately.
- Avoid extra model calls.

### Learning overclaim

The MVP learning is heuristic, not deep personalization.

MVP mitigation:

- Keep labels simple.
- Use language like `learned: shorter`, not `mastered your style`.

---

## Product principles for the MVP

### Stay narrow

Every feature should support the core reply loop.

### Show one reply

The MVP should not offer a menu of drafts. One reply makes the product feel decisive.

### Keep the user in charge

CasprFlow should paste, not send.

### Make learning visible

The learned label is part of the product, not a debug detail.

### Prefer demo truth over architecture ambition

If a feature is hard to make reliable in one day and does not directly prove the loop, it should wait.

---

## Day-one definition of done

The one-day MVP is done when this exact flow works:

1. Highlight an incoming message in another app.
2. Press the CasprFlow hotkey.
3. See one generated reply in an overlay.
4. Edit the reply in the overlay.
5. Press Enter.
6. Final reply is pasted into the active app.
7. CasprFlow stores the edit delta locally.
8. The next reply uses that local signal.
9. The overlay shows one learned label.

If this works, the MVP communicates the idea.

Everything else can wait.
