# CasprFlow Implementation Plan
### Sequential 2-3 hour MVP route

## Goal

Build the fastest possible CasprFlow MVP:

**highlight message -> press hotkey -> get one reply in a tiny capsule -> edit or regenerate -> paste -> learn locally**

The plan intentionally skips production polish. The point is to get a working demo in 2-3 hours by porting the risky Mac automation pieces from an Apache-2.0 project and building only CasprFlow-specific logic ourselves.

---

## Product workaround: reply capsule, not edit overlay

The MVP should not use a bulky edit overlay.

Use a tiny floating reply capsule instead:

- borderless `NSPanel`
- one focused editable text field
- generated reply appears directly inside the field
- no header
- no big toolbar
- no modal window feeling
- one subtle footer: `Enter paste | Cmd+R regenerate | Esc`

The field is still editable, but it should feel like an inline command bubble, not a document editor.

### Regenerate after editing

The capsule supports a better correction loop:

1. CasprFlow generates a reply.
2. User lightly edits the text.
3. User presses `Command + R`.
4. CasprFlow treats the edited text as correction guidance.
5. The model regenerates a cleaner reply using:
   - original selected message
   - first generated reply
   - user's edited draft
   - stored local preferences
6. The new reply replaces the capsule text.
7. CasprFlow stores a local signal from the edit.

This gives the user a way to steer the reply without opening a heavy editor or adding a prompt box.

For paste:

- `Enter` pastes the current capsule text.
- If the user edited before pressing `Enter`, CasprFlow learns from that final edit.
- If the user regenerated after editing, CasprFlow learns from the edit and the regeneration event.

---

## Source-reuse decision

Do not list or pull small libraries for every small feature.

Only use source reuse for bulk feature extraction where implementation risk is high.

### Primary port target: Axii

Repo:

[bwarzecha/Axii](https://github.com/bwarzecha/Axii)

License:

Apache-2.0

Why it helps:

- It is a native macOS menu-bar AI utility.
- It already handles global hotkey behavior.
- It already handles paste-into-active-app behavior.
- It already has the permission and app lifecycle shape we need.
- It maps closely to our wedge, even though its input is voice and ours is selected text.

What to port:

- menu-bar app shell
- global hotkey registration path
- focus restore pattern
- smart paste pattern
- permission-check pattern
- small floating status/indicator ideas if useful

What not to port:

- audio recording
- transcription model code
- dictation-specific settings
- provider dashboards
- history dashboards
- usage analytics

Time saved:

- avoids building and debugging Mac lifecycle, hotkey, permission, and paste behavior from scratch
- cuts roughly 3-4 risky hours down to about 45-60 minutes of adaptation

License handling:

- preserve Apache-2.0 license text for ported files
- retain copyright headers where present
- add a third-party attribution note before shipping anything public

### Fallback/reference: Hold to Talk

Repo:

[jxucoder/hold-to-talk](https://github.com/jxucoder/hold-to-talk)

License:

Apache-2.0 according to the public project site.

Why it helps:

- It proves the same Mac interaction pattern: trigger, lightweight floating state, paste into the active app.
- It is useful as a reference if Axii's structure is harder to adapt than expected.

What to use it for:

- floating indicator behavior
- paste-anywhere assumptions
- permission wording

What not to do:

- do not port both Axii and Hold to Talk wholesale
- do not mix two app shells unless Axii blocks us

Time saved:

- provides a fallback path instead of losing the build window if Axii is awkward

---

## Corners we are intentionally skipping

- no hotkey picker
- no onboarding flow beyond a basic permission warning
- no keychain settings UI
- no auto-send
- no send detection
- no app-specific integrations
- no cloud sync
- no database
- no embeddings
- no fine-tuning
- no notarized build
- no installer
- no auto-updater
- no exhaustive cross-app testing

These cuts are acceptable because the MVP only needs to demonstrate the loop.

---

## Sequential implementation

### Step 1: Create or port the app shell

Start from the simplest path:

1. Create a new native macOS Swift project named `CasprFlow`.
2. Port the relevant Axii app shell pieces into the project.
3. Configure the app as a menu-bar/background app.
4. Add the minimal menu:
   - Enable CasprFlow
   - Clear learning
   - Quit
5. Register the default hotkey: `Option + Space`.

Done when:

- app launches as a menu-bar app
- hotkey callback fires while another app is active

Target time:

30-45 minutes with Axii porting.

### Step 2: Implement selected-text capture

Implement selected context capture with the fastest reliable approach:

1. Save current pasteboard string if present.
2. Trigger synthetic `Command + C`.
3. Read the selected text from `NSPasteboard`.
4. Restore the previous clipboard value best-effort.
5. If no selected text exists, show the capsule with:

`Highlight a message first.`

Done when:

- selecting text in Notes or a browser text field can be captured by the hotkey

Target time:

20-30 minutes.

### Step 3: Build the reply capsule

Build a tiny SwiftUI view hosted in a borderless `NSPanel`.

States:

- loading
- draft ready
- regenerating
- empty selection
- error

UI:

- one editable text field or compact text editor
- max 3-4 visible lines
- subtle learned label only when available
- subtle footer: `Enter paste | Cmd+R regenerate | Esc`

Keyboard behavior:

- `Enter`: paste current text
- `Command + R`: regenerate from the current text
- `Escape`: close without paste

Done when:

- hotkey opens the capsule
- capsule can show and edit placeholder text
- keyboard controls work

Target time:

25-35 minutes.

### Step 4: Add generation

Implement one direct Gemini API call with `URLSession`.

Use:

- default model: `gemini-3-flash-preview`
- API key source: `GEMINI_API_KEY` or local developer config
- request path: Gemini `generateContent`

Input:

- selected message
- local preference summary

Output:

- one reply only
- no alternatives
- no explanation
- no markdown
- no quotes

Prompt shape:

```text
You generate one concise reply for the user.
Write naturally and directly.
Do not explain.
Do not include alternatives.
Do not wrap the reply in quotes.
Respect learned preferences when relevant.

Selected message:
{selected_message}

Learned preferences:
{preferences}
```

Done when:

- selected text becomes a generated reply in the capsule

Target time:

25-35 minutes.

### Step 5: Add regenerate-from-edit

Implement `Command + R` while the capsule is open.

If the user did not edit:

- regenerate with the original selected message and preferences

If the user edited:

- send original selected message
- send original generated draft
- send current edited draft
- ask the model to produce a cleaner version that follows the user's correction
- infer and store a local signal from the edit

Prompt shape:

```text
The user edited your previous draft.
Regenerate one final reply that follows the user's correction.

Selected message:
{selected_message}

Previous generated draft:
{generated_draft}

User edited draft:
{edited_draft}

Learned preferences:
{preferences}
```

Done when:

- user can edit the capsule text
- `Command + R` replaces it with a better regenerated draft
- learning store records the correction

Target time:

20-30 minutes.

### Step 6: Paste final reply

Use the Axii-style smart paste path.

Flow:

1. Capture current capsule text.
2. Store learning if the final text differs from the generated text.
3. Copy final text to pasteboard.
4. Return focus to the previous active app.
5. Trigger synthetic `Command + V`.
6. Close the capsule.
7. Restore prior clipboard best-effort after a short delay.

Done when:

- final reply pastes into the active text field
- CasprFlow does not auto-send

Target time:

20-30 minutes with Axii porting.

### Step 7: Add local learning

Create:

`~/Library/Application Support/CasprFlow/preferences.json`

Store:

```json
{
  "examples": [],
  "summary": {}
}
```

Infer only a few signals:

- `shorter`
- `longer`
- `more_direct`
- `warmer`
- `no_emojis`
- `less_excited`

Show only the strongest signal in the capsule:

`learned: shorter`

Done when:

- editing a draft creates a local signal
- later generations include that signal in the prompt
- the capsule shows one learned label

Target time:

25-35 minutes.

### Step 8: Final demo pass

Test only the demo route:

1. Notes
2. Browser text field
3. Slack or Messages if available

Required demo:

1. Highlight text.
2. Press hotkey.
3. See reply capsule.
4. Edit reply.
5. Press `Command + R`.
6. See regenerated reply.
7. Press `Enter`.
8. Reply pastes into the active app.
9. Next generation shows a learned label.

Done when:

- the loop works twice in a row
- empty selection does not crash
- model failure gives a readable capsule error

Target time:

20-30 minutes.

---

## Compressed timeline

### 0:00-0:45

Port app shell, menu-bar mode, hotkey, and permission pattern from Axii.

### 0:45-1:15

Implement selected-text capture and pasteboard restore.

### 1:15-1:50

Build reply capsule and keyboard controls.

### 1:50-2:20

Add generation and regenerate-from-edit.

### 2:20-2:45

Add local learning and learned label.

### 2:45-3:00

Demo pass and rough edge cleanup.

---

## Why this can fit in 2-3 hours

The original 7-8 hour estimate included risky native Mac mechanics:

- background menu-bar lifecycle
- global hotkey registration
- accessibility permission handling
- focus restoration
- paste into active app
- floating UI behavior

Axii already covers the hardest shape of that problem under Apache-2.0.

CasprFlow-specific work is smaller:

- selected text instead of audio input
- reply generation instead of transcription
- tiny capsule instead of dictation window
- local style signal storage
- regenerate-from-edit loop

That changes the work from "build a Mac automation app from scratch" to "adapt a proven Mac automation shell and add the CasprFlow reply loop."

---

## Day-one definition of done

The MVP is done when this works:

1. Highlight a message.
2. Press `Option + Space`.
3. A tiny reply capsule appears.
4. CasprFlow generates one reply.
5. User edits the reply in place.
6. User presses `Command + R`.
7. CasprFlow regenerates from that edit.
8. User presses `Enter`.
9. Final reply pastes into the active app.
10. CasprFlow stores a local learning signal.
11. The next reply shows one learned label.

Anything beyond this is not day-one MVP.
