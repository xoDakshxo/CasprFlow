import Foundation

public enum KnowledgeFastRepliesPhaseTwoSelfCheck {
    public static func buildContextRequestIncludesOneScreenshot() -> Bool {
        let body = OpenAIContextBuilder.requestBody(
            capturePack: sampleCapturePack(includeScreenshot: true),
            config: sampleConfig
        )
        return contentCount(in: body) == 2
            && imageContentCount(in: body) == 1
            && body["store"] as? Bool == false
    }

    public static func buildContextPromptDoesNotWriteReplies() -> Bool {
        let prompt = OpenAIContextBuilder.prompt(for: sampleCapturePack(includeScreenshot: true))
        return prompt.contains("Do not produce chips")
            && prompt.contains("Do not produce drafts")
            && !prompt.contains("pasteable drafts")
            && !prompt.contains("Return exactly three chips")
    }

    public static func buildOutputRequestUsesContextBrief() -> Bool {
        let prompt = OpenAIOutputPlanner.prompt(
            capturePack: sampleCapturePack(includeScreenshot: true),
            contextBrief: sampleContextBrief(),
            knowledgeContext: .empty
        )
        return prompt.contains("context-1")
            && prompt.contains("retry bug status")
            && prompt.contains("KnowledgeContext")
    }

    public static func buildOutputRequestStoresFalseAndSendsNoScreenshot() -> Bool {
        let body = OpenAIOutputPlanner.requestBody(
            capturePack: sampleCapturePack(includeScreenshot: true),
            contextBrief: sampleContextBrief(),
            knowledgeContext: .empty,
            config: sampleConfig
        )
        return body["store"] as? Bool == false
            && contentCount(in: body) == 1
            && imageContentCount(in: body) == 0
    }

    public static func malformedContextJSONFallsBack() -> Bool {
        let pack = sampleCapturePack(includeScreenshot: false)
        let brief = OpenAIContextBuilder.parseContextBrief("not json", fallbackCapturePack: pack)
        return brief.id == "context-\(pack.id)"
            && brief.targetDirection == .selected
            && brief.missingContextFlags.isEmpty
    }

    public static func malformedReplyJSONFallsBack() -> Bool {
        let pack = sampleCapturePack(includeScreenshot: false)
        let brief = sampleContextBrief()
        let plan = OpenAIOutputPlanner.parseReplyPlan("not json", capturePack: pack, contextBrief: brief)
        return plan.chips.count == 3
            && plan.drafts.count == 3
            && plan.fallbackReason != nil
    }

    public static func duplicateChipsFallBack() -> Bool {
        let pack = sampleCapturePack(includeScreenshot: false)
        let brief = sampleContextBrief()
        let duplicate = """
        {
          "id": "plan-1",
          "contextBriefID": "context-1",
          "targetSummary": "retry bug status",
          "targetConfidence": 0.9,
          "surfaceKind": "chat",
          "chips": [
            {"id": "same", "label": "Update now"},
            {"id": "same", "label": "Need time"},
            {"id": "still_checking", "label": "Still checking"}
          ],
          "defaultChipID": "same",
          "drafts": [
            {"chipID": "same", "text": "Checking now."},
            {"chipID": "still_checking", "text": "Still checking."},
            {"chipID": "need_time", "text": "Need time."}
          ],
          "learnedLabel": null,
          "warnings": [],
          "fallbackReason": null
        }
        """
        let plan = OpenAIOutputPlanner.parseReplyPlan(duplicate, capturePack: pack, contextBrief: brief)
        return plan.fallbackReason != nil
            && plan.chips.map(\.id) == ["take_it", "push_timing", "ask_context"]
    }

    public static func missingDraftFallsBack() -> Bool {
        let pack = sampleCapturePack(includeScreenshot: false)
        let brief = sampleContextBrief()
        let missingDraft = """
        {
          "id": "plan-1",
          "contextBriefID": "context-1",
          "targetSummary": "retry bug status",
          "targetConfidence": 0.9,
          "surfaceKind": "chat",
          "chips": [
            {"id": "update_now", "label": "Update now"},
            {"id": "need_time", "label": "Need time"},
            {"id": "still_checking", "label": "Still checking"}
          ],
          "defaultChipID": "update_now",
          "drafts": [
            {"chipID": "update_now", "text": "Checking now."},
            {"chipID": "need_time", "text": "Need time."}
          ],
          "learnedLabel": null,
          "warnings": [],
          "fallbackReason": null
        }
        """
        let plan = OpenAIOutputPlanner.parseReplyPlan(missingDraft, capturePack: pack, contextBrief: brief)
        return plan.fallbackReason != nil
            && plan.draft(for: plan.defaultChipID) != nil
    }

    public static func modelRolesAreDistinct() -> Bool {
        let config = OpenAIPlanningConfig.load(environment: [
            "OPENAI_API_KEY": "test",
            "OPENAI_CONTEXT_MODEL": "context-model",
            "OPENAI_OUTPUT_MODEL": "output-model",
            "OPENAI_FOLLOWUP_MODEL": "followup-model"
        ])
        return config.contextModel == "context-model"
            && config.outputModel == "output-model"
            && config.followUpModel == "followup-model"
    }

    private static var sampleConfig: OpenAIPlanningConfig {
        OpenAIPlanningConfig(
            apiKey: "test",
            contextModel: "context-model",
            outputModel: "output-model",
            followUpModel: "followup-model",
            reasoningEffort: "low",
            imageDetail: "low"
        )
    }

    private static func sampleCapturePack(includeScreenshot: Bool) -> CapturePack {
        CapturePack(
            id: "capture-1",
            capturedAt: Date(timeIntervalSince1970: 1_771_840_800),
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "cs-mavericks",
            surfaceKind: .chat,
            focusedField: CapturePack.FocusedFieldSummary(
                role: "AXTextArea",
                subrole: nil,
                valueSummary: nil,
                fieldKind: .chat
            ),
            selection: "Any update on the retry bug?",
            recent: [
                ScreenContextBundle.MessageBlock(
                    text: "Any update on the retry bug?",
                    source: "ax",
                    confidence: 1,
                    boundingBox: nil
                )
            ],
            ambient: [],
            visibleAXCandidates: ["Any update on the retry bug?"],
            screenshotMetadata: [
                ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 7, width: 640, height: 420)
            ],
            screenshot: includeScreenshot
                ? CapturePack.Screenshot(
                    metadata: ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 7, width: 640, height: 420),
                    data: Data([1, 2, 3]),
                    mimeType: "image/jpeg"
                )
                : nil,
            confidence: includeScreenshot ? 0.45 : 0.9,
            screenshotDecision: CapturePack.ScreenshotDecision(
                action: includeScreenshot ? .attached : .skipped,
                reason: includeScreenshot ? "low confidence" : "high confidence"
            )
        )
    }

    private static func sampleContextBrief() -> ContextBrief {
        ContextBrief(
            id: "context-1",
            captureID: "capture-1",
            surfaceKind: .chat,
            replyTargetSummary: "Naga asked for retry bug status.",
            targetConfidence: 0.9,
            relevantSnippets: ["Any update on the retry bug?"],
            speakerHints: ["Naga"],
            targetDirection: .incoming,
            ignoredChromeSummary: "Ignored Slack sidebar.",
            missingContextFlags: [],
            screenshotConfidence: 0.85,
            sourceIDs: ["capture-1"]
        )
    }

    private static func contentCount(in body: [String: Any]) -> Int {
        content(in: body).count
    }

    private static func imageContentCount(in body: [String: Any]) -> Int {
        content(in: body).filter { $0["type"] as? String == "input_image" }.count
    }

    private static func content(in body: [String: Any]) -> [[String: Any]] {
        guard let input = body["input"] as? [[String: Any]],
              let first = input.first,
              let content = first["content"] as? [[String: Any]] else {
            return []
        }
        return content
    }
}
