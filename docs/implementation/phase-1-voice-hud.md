# Phase 1 — Voice HUD (push-to-talk, no text input)

## Goal

The whole input surface. **No text box.** Hold Option+Space → a small Wispr-style
transcript HUD appears center-bottom → on-device speech recognition streams partial
text inside the pill while you hold → release → the pill transitions into the existing
CasprFlow spinner while the transcript is finalized. Output of this phase: a final
transcript string handed to the dispatcher (phase 2).

## Intended feel

- Tiny, unobtrusive HUD pinned center-bottom (a capsule ~320×56). Not a window you
  interact with — a status indicator.
- Listening = live partial transcript text inside the pill. Processing = the CasprFlow
  spinner (`CasprFlowLogoMark`). The transition between them should feel smooth, not a
  hard swap.
- Zero friction: press, talk, release. No confirm step.

## Build

- `Sources/CasprFlowCore/Input/VoiceHUDController.swift` — owns the prewarmed
  `FloatingPanel`, the HUD state machine (`idle → listening → processing`), and drives
  the transcript readout. Replaces the placeholder wiring currently in `AppCoordinator`.
- `Sources/CasprFlowCore/Input/VoiceInputService.swift` — on-device speech capture.
  `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` + `AVAudioEngine` tap
  for streaming partials and mic level. Start on press, stop on release, return the
  final transcript.
- `Sources/CasprFlowCore/Input/TranscriptHUDView.swift` — the live partial transcript
  readout. Transitions into `CasprFlowLogoMark` on `processing`.

## Contracts

```swift
enum VoiceHUDState { case idle, listening, processing }

@MainActor
final class VoiceHUDController {
    init(onTranscript: @escaping (String) -> Void)
    func beginListening()   // press: position center-bottom, show, start capture
    func endListening()      // release: stop capture, show spinner, emit transcript
    func fail(_ message: String)
    func dismiss()
}

@MainActor
final class VoiceInputService {
    func start(onPartial: @escaping (String) -> Void,
               onLevel: @escaping (Float) -> Void) throws
    func stop() async -> String   // final transcript
}
```

`AppCoordinator` already calls `startListening()` / `stopListening()` on hotkey
press/release — point those at `VoiceHUDController`.

## Reuse

- `FloatingPanel.make(size:)` + `positionCenterBottom()` — the HUD window (prewarmed).
- `CasprFlowLogoMark` (`CasprFlowLogo.swift`) — the processing spinner.
- `HotkeyService.registerDefaultHotkey(onPress:onRelease:)` — push-to-talk, already wired.
- `SelectionTextNormalizer.clean(_:)` — tidy the final transcript.

## Permissions / bundle

Add to the app's Info.plist (in `Scripts/create_app_bundle.sh`):
- `NSMicrophoneUsageDescription` — "CasprFlow listens when you hold the hotkey."
- `NSSpeechRecognitionUsageDescription` — "CasprFlow transcribes your command on-device."

First use triggers the system prompts; surface a HUD error state if denied. Fold these
into the existing permission guide if convenient (see the kept `Permissions/` stack).

## Latency

On-device recognition only — no network. Partial results stream during the hold, so on
release the final transcript is essentially ready. Keep the audio engine setup off the
hotkey path if possible (warm it lazily but quickly). Show the transcript HUD instantly
on press; show the spinner instantly on release.

## Acceptance

- Hold the hotkey → transcript HUD appears center-bottom and updates with your words.
- Release → it transitions into the CasprFlow spinner; the recognized transcript is logged.
- Denying mic/speech shows a clear HUD error, not a crash.
- `swift build` green, `CasprFlowChecks` passes.
