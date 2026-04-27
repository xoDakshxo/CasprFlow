import Foundation

public enum KnowledgeFastRepliesPhaseZeroSelfCheck {
    public static func replyPlanRoundTripsThroughJSON() -> Bool {
        guard let plan = try? sampleReplyPlan() else { return false }
        return roundTrip(plan) == plan
    }

    public static func replyPlanRequiresOneDraftPerChip() -> Bool {
        let chips = sampleChips()
        do {
            _ = try ReplyPlan(
                id: "plan-1",
                contextBriefID: "context-1",
                targetSummary: "Slack asks for a status update.",
                targetConfidence: 0.9,
                surfaceKind: .chat,
                chips: chips,
                defaultChipID: chips[0].id,
                drafts: [
                    ReplyPlanDraft(chipID: chips[0].id, text: "I am checking it now."),
                    ReplyPlanDraft(chipID: chips[1].id, text: "I need a bit more time.")
                ],
                learnedLabel: nil,
                warnings: [],
                fallbackReason: nil
            )
            return false
        } catch ReplyPlanningValidationError.missingDraft(let chipID) {
            return chipID == chips[2].id
        } catch {
            return false
        }
    }

    public static func contextBriefRepresentsTargetDirections() -> Bool {
        let directions = Set(ContextBrief.TargetDirection.allCases)
        return directions == [.selected, .incoming, .outgoing, .ambiguous]
            && sampleContext(direction: .selected).targetDirection == .selected
            && sampleContext(direction: .incoming).targetDirection == .incoming
            && sampleContext(direction: .outgoing).targetDirection == .outgoing
            && sampleContext(direction: .ambiguous).targetDirection == .ambiguous
    }

    public static func capturePackRepresentsSurfaces() -> Bool {
        let chat = sampleCapturePack(surface: .chat)
        let casual = sampleCapturePack(surface: .casual)
        let code = sampleCapturePack(surface: .code)
        return roundTrip(chat)?.surfaceKind == .chat
            && roundTrip(casual)?.surfaceKind == .casual
            && roundTrip(code)?.surfaceKind == .code
    }

    public static func knowledgeContextCanBeEmpty() -> Bool {
        let empty = KnowledgeContext.empty
        return empty.hints.isEmpty
            && empty.recentChipLabels.isEmpty
            && empty.retrievalSourceIDs.isEmpty
            && roundTrip(empty) == empty
    }

    public static func learningEventSeparatesGeneratedAndFinalText() -> Bool {
        let event = LearningEvent(
            id: "event-1",
            captureID: "capture-1",
            contextBriefID: "context-1",
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            surfaceKind: .chat,
            targetSummary: "Naga asked for a retry bug status update.",
            chipsShown: sampleChips(),
            selectedChipID: "update_now",
            draftShown: "I am checking the retry path now and will update you shortly.",
            generatedDraft: "I am checking the retry path now and will update you shortly.",
            finalPastedText: "Checking the retry path now, will update shortly.",
            editDeltaSummary: "shorter",
            inferredSignals: ["shorter"],
            createdAt: sampleDate
        )

        guard let decoded = roundTrip(event) else { return false }
        return decoded.generatedDraft != decoded.finalPastedText
            && decoded.draftShown == decoded.generatedDraft
            && decoded.inferredSignals == ["shorter"]
    }

    private static func sampleReplyPlan() throws -> ReplyPlan {
        let chips = sampleChips()
        return try ReplyPlan(
            id: "plan-1",
            contextBriefID: "context-1",
            targetSummary: "Slack asks for a status update.",
            targetConfidence: 0.9,
            surfaceKind: .chat,
            chips: chips,
            defaultChipID: chips[0].id,
            drafts: [
                ReplyPlanDraft(chipID: chips[0].id, text: "I am checking it now and will update you shortly."),
                ReplyPlanDraft(chipID: chips[1].id, text: "I need a bit more time to verify the retry path."),
                ReplyPlanDraft(chipID: chips[2].id, text: "I am still checking and will send details once I have them.")
            ],
            learnedLabel: "shorter",
            warnings: [],
            fallbackReason: nil
        )
    }

    private static func sampleChips() -> [ReplyPlanChip] {
        [
            ReplyPlanChip(id: "update_now", label: "Update now"),
            ReplyPlanChip(id: "need_time", label: "Need time"),
            ReplyPlanChip(id: "still_checking", label: "Still checking")
        ]
    }

    private static func sampleContext(direction: ContextBrief.TargetDirection) -> ContextBrief {
        ContextBrief(
            id: "context-\(direction.rawValue)",
            captureID: "capture-1",
            surfaceKind: .chat,
            replyTargetSummary: "Latest Slack message asks for status.",
            targetConfidence: 0.87,
            relevantSnippets: ["Any update on the retry bug?"],
            speakerHints: ["Naga"],
            targetDirection: direction,
            ignoredChromeSummary: "Ignored sidebar and buttons.",
            missingContextFlags: [],
            screenshotConfidence: 0.82,
            sourceIDs: ["capture-1", "screenshot-1"]
        )
    }

    private static func sampleCapturePack(surface: ScreenContextBundle.SurfaceKind) -> CapturePack {
        CapturePack(
            id: "capture-\(surface.rawValue)",
            capturedAt: sampleDate,
            appName: appName(for: surface),
            bundleId: bundleID(for: surface),
            windowTitle: "Demo",
            surfaceKind: surface,
            focusedField: CapturePack.FocusedFieldSummary(
                role: "AXTextArea",
                subrole: nil,
                valueSummary: nil,
                fieldKind: surface == .code ? .code : .chat
            ),
            selection: nil,
            recent: [
                ScreenContextBundle.MessageBlock(
                    text: "Can you send an update?",
                    source: "ax",
                    confidence: 1.0,
                    boundingBox: nil
                )
            ],
            ambient: ["Demo"],
            visibleAXCandidates: ["Can you send an update?"],
            screenshotMetadata: [
                ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 1, width: 640, height: 420)
            ],
            screenshot: CapturePack.Screenshot(
                metadata: ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 1, width: 640, height: 420),
                data: Data([1, 2, 3]),
                mimeType: "image/jpeg"
            ),
            confidence: 0.82,
            screenshotDecision: CapturePack.ScreenshotDecision(
                action: .attached,
                reason: "focused crop available"
            )
        )
    }

    private static func appName(for surface: ScreenContextBundle.SurfaceKind) -> String {
        switch surface {
        case .chat: return "Slack"
        case .casual: return "Messages"
        case .code: return "Cursor"
        default: return "Notes"
        }
    }

    private static func bundleID(for surface: ScreenContextBundle.SurfaceKind) -> String {
        switch surface {
        case .chat: return "com.tinyspeck.slackmacgap"
        case .casual: return "com.apple.MobileSMS"
        case .code: return "com.todesktop.230313mzl4w4u92"
        default: return "com.apple.Notes"
        }
    }

    private static func roundTrip<T: Codable & Equatable>(_ value: T) -> T? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private static var sampleDate: Date {
        Date(timeIntervalSince1970: 1_771_840_800)
    }
}
