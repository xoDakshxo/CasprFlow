import CasprFlowCore
import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Check failed: \(message)\n", stderr)
        exit(1)
    }
}

private func expectValue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("Check failed: \(message)\n", stderr)
        exit(1)
    }
}

expect(HotkeyDescriptor.defaultHotkey.displayName == "Option + Space", "default hotkey label")
expect(HotkeyDescriptor.defaultHotkey.keyCode == 49, "default hotkey key code")
expect(HotkeyDescriptor.defaultHotkey.carbonModifiers == 2048, "default hotkey modifier")

let state = StatusItemState(
    isEnabled: true,
    isAccessibilityTrusted: false,
    isScreenRecordingGranted: false
)
expect(state.isEnabled, "status item enabled flag")
expect(!state.isAccessibilityTrusted, "status item accessibility flag")
expect(!state.isScreenRecordingGranted, "status item screen recording flag")

expect(SelectionTextNormalizer.clean(nil) == nil, "nil selected text")
expect(SelectionTextNormalizer.clean("   \n\t  ") == nil, "empty selected text")
expect(SelectionTextNormalizer.clean("  hello  ") == "hello", "trimmed selected text")
expect(SelectionTextNormalizer.clean("\nhello\nworld\n") == "hello\nworld", "multiline selected text")

expect(PhaseThreeSelfCheck.stubGeneratorReturnsOneReply(), "stub generator returns one reply")
expect(PhaseThreeSelfCheck.stubRegenerationChangesReply(), "stub regeneration changes reply")
expect(PhaseThreeSelfCheck.pasteServiceRejectsEmptyText(), "paste service rejects empty text")
expect(PhaseThreeSelfCheck.pasteServiceKeepsUserTextUntrimmed(), "paste service keeps user text untrimmed")
expect(PhaseThreeSelfCheck.promptContextWorksWithoutSelection(), "prompt context works without selection")
expect(PhaseThreeSelfCheck.promptContextDropsChrome(), "prompt context drops chrome")
expect(PhaseThreeSelfCheck.promptContextUsesOCRWithoutAX(), "prompt context uses OCR without AX")

expect(PhaseFourSelfCheck.surfaceClassifierDetectsSlack(), "surface classifier detects Slack as chat")
expect(PhaseFourSelfCheck.surfaceClassifierDetectsCode(), "surface classifier detects code IDEs")
expect(PhaseFourSelfCheck.surfaceClassifierDetectsCasual(), "surface classifier detects Messages as casual")
expect(PhaseFourSelfCheck.surfaceClassifierFallsBackToOther(), "surface classifier falls back to other")
expect(PhaseFourSelfCheck.ocrGroupingMergesAdjacentLines(), "OCR grouping merges adjacent lines")
expect(PhaseFourSelfCheck.bundleIncludesGroupedRecentBlock(), "bundle includes grouped recent block")
expect(PhaseFourSelfCheck.bundleExcludesChromeAmbient(), "bundle excludes chrome from prompt")
expect(PhaseFourSelfCheck.confidenceLadderSelectionWins(), "confidence ladder: selection -> 1.00")
expect(PhaseFourSelfCheck.confidenceLadderFocusedFieldPlusRecent(), "confidence ladder: focused field + recent -> 0.85")
expect(PhaseFourSelfCheck.confidenceLadderInputFocusedPlusRecent(), "confidence ladder: input focused + recent -> 0.70")
expect(PhaseFourSelfCheck.confidenceLadderAmbientOnlyTriggersFallback(), "confidence ladder: ambient only -> 0.30 + fallback")
expect(PhaseFourSelfCheck.confidenceLadderEmptyTriggersFallback(), "confidence ladder: empty -> 0.00 + fallback")
expect(PhaseFourSelfCheck.bundleRoundtripsAsJSON(), "bundle round-trips through JSON")

expect(PhaseFiveSelfCheck.chipPromptIncludesBundlePrompt(), "chip prompt includes bundle prompt")
expect(PhaseFiveSelfCheck.malformedChipJSONFallsBack(), "malformed chip JSON falls back")
expect(PhaseFiveSelfCheck.slackFallbackUsesChatChips(), "Slack fallback uses chat chips")
expect(PhaseFiveSelfCheck.expansionPromptIncludesChipAndEdit(), "expansion prompt includes chip and edit")
expect(PhaseFiveSelfCheck.screenshotFallbackAttachesOnlyWhenConfidenceIsLow(), "screenshot fallback attaches only when confidence is low")
expect(PhaseFiveSelfCheck.openAIRequestUsesResponsesImageContent(), "OpenAI request uses Responses image content")
expect(PhaseFiveSelfCheck.chipPromptUsesAXButNotOCR(), "chip prompt uses AX but not OCR")
expect(PhaseFiveSelfCheck.chipParserExtractsWrappedJSON(), "chip parser extracts wrapped JSON")

expect(PhaseFivePointFiveSelfCheck.menuStateTitlesReflectPermissions(), "permission menu titles reflect state")
expect(PhaseFivePointFiveSelfCheck.permissionPanelsMapToSettingsPanes(), "permission panels map to settings panes")
expect(PhaseFivePointFiveSelfCheck.dragSourceExposesBundleFileURL(), "permission drag source exposes bundle file URL")

expect(KnowledgeFastRepliesPhaseZeroSelfCheck.replyPlanRoundTripsThroughJSON(), "reply plan round-trips through JSON")
expect(KnowledgeFastRepliesPhaseZeroSelfCheck.replyPlanRequiresOneDraftPerChip(), "reply plan requires one draft per chip")
expect(KnowledgeFastRepliesPhaseZeroSelfCheck.contextBriefRepresentsTargetDirections(), "context brief represents target directions")
expect(KnowledgeFastRepliesPhaseZeroSelfCheck.capturePackRepresentsSurfaces(), "capture pack represents chat, casual, and code surfaces")
expect(KnowledgeFastRepliesPhaseZeroSelfCheck.knowledgeContextCanBeEmpty(), "empty knowledge context is valid")
expect(KnowledgeFastRepliesPhaseZeroSelfCheck.learningEventSeparatesGeneratedAndFinalText(), "learning event separates generated and final text")
expect(KnowledgeFastRepliesPhaseOneSelfCheck.highConfidenceSelectedTextSkipsScreenshot(), "capture pack skips screenshot for high-confidence selection")
expect(KnowledgeFastRepliesPhaseOneSelfCheck.lowConfidenceContextAttachesOneScreenshot(), "capture pack attaches one screenshot for low confidence")
expect(KnowledgeFastRepliesPhaseOneSelfCheck.redactionRemovesObviousSecrets(), "capture pack redacts obvious secrets")
expect(KnowledgeFastRepliesPhaseOneSelfCheck.chromePruningDropsButtons(), "capture pack prunes chrome")
expect(KnowledgeFastRepliesPhaseOneSelfCheck.slackChromeDoesNotBecomeRecentContext(), "capture pack excludes Slack chrome from recent context")
expect(KnowledgeFastRepliesPhaseOneSelfCheck.debugJSONStaysCompact(), "capture pack debug JSON stays compact")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.buildContextRequestIncludesOneScreenshot(), "build-context request includes one screenshot")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.buildContextPromptDoesNotWriteReplies(), "build-context prompt does not write replies")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.buildOutputRequestUsesContextBrief(), "build-output request uses context brief")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.buildOutputRequestStoresFalseAndSendsNoScreenshot(), "build-output stores false and sends no screenshot")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.malformedContextJSONFallsBack(), "malformed context JSON falls back")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.malformedReplyJSONFallsBack(), "malformed reply JSON falls back")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.duplicateChipsFallBack(), "duplicate chips fall back")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.missingDraftFallsBack(), "missing draft falls back")
expect(KnowledgeFastRepliesPhaseTwoSelfCheck.modelRolesAreDistinct(), "context, output, and follow-up model roles are distinct")

Task { @MainActor in
    expectValue(await PhaseFiveSelfCheck.mockServiceRoundTrips(), "mock generation service round-trips chips and expansion")
    expect(PhaseOneSelfCheck.canCreateReplyCapsule(), "reply capsule construction")
    expect(PhaseOneSelfCheck.canRegisterDefaultHotkey(), "default hotkey registration")
    expect(PhaseThreeSelfCheck.canCreatePhaseThreeCapsule(), "phase 3 capsule construction")
    print("CasprFlow checks passed")
    exit(0)
}

RunLoop.main.run()
