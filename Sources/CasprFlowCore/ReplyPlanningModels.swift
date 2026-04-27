import Foundation

public enum ReplyPlanningValidationError: Error, Equatable, LocalizedError {
    case wrongChipCount(Int)
    case duplicateChipID(String)
    case missingDefaultChip(String)
    case missingDraft(chipID: String)
    case emptyDraft(chipID: String)
    case emptyTargetSummary

    public var errorDescription: String? {
        switch self {
        case .wrongChipCount(let count):
            return "ReplyPlan must contain exactly three chips, got \(count)."
        case .duplicateChipID(let id):
            return "ReplyPlan contains duplicate chip id \(id)."
        case .missingDefaultChip(let id):
            return "ReplyPlan default chip id \(id) is not in chips."
        case .missingDraft(let chipID):
            return "ReplyPlan is missing a draft for chip \(chipID)."
        case .emptyDraft(let chipID):
            return "ReplyPlan draft for chip \(chipID) is empty."
        case .emptyTargetSummary:
            return "ReplyPlan target summary is empty."
        }
    }
}

public struct CapturePack: Codable, Equatable, Sendable {
    public struct FocusedFieldSummary: Codable, Equatable, Sendable {
        public let role: String?
        public let subrole: String?
        public let valueSummary: String?
        public let fieldKind: ScreenContextBundle.FieldKind

        public init(
            role: String?,
            subrole: String?,
            valueSummary: String?,
            fieldKind: ScreenContextBundle.FieldKind
        ) {
            self.role = role
            self.subrole = subrole
            self.valueSummary = valueSummary
            self.fieldKind = fieldKind
        }
    }

    public struct Screenshot: Codable, Equatable, Sendable {
        public let metadata: ScreenshotMetadata
        public let data: Data?
        public let mimeType: String?

        public init(metadata: ScreenshotMetadata, data: Data?, mimeType: String?) {
            self.metadata = metadata
            self.data = data
            self.mimeType = mimeType
        }
    }

    public struct ScreenshotDecision: Codable, Equatable, Sendable {
        public enum Action: String, Codable, Sendable {
            case attached
            case skipped
            case unavailable
        }

        public let action: Action
        public let reason: String

        public init(action: Action, reason: String) {
            self.action = action
            self.reason = reason
        }
    }

    public let id: String
    public let capturedAt: Date
    public let appName: String?
    public let bundleId: String?
    public let windowTitle: String?
    public let surfaceKind: ScreenContextBundle.SurfaceKind
    public let focusedField: FocusedFieldSummary?
    public let selection: String?
    public let recent: [ScreenContextBundle.MessageBlock]
    public let ambient: [String]
    public let visibleAXCandidates: [String]
    public let screenshot: Screenshot?
    public let confidence: Double
    public let screenshotDecision: ScreenshotDecision

    public init(
        id: String,
        capturedAt: Date,
        appName: String?,
        bundleId: String?,
        windowTitle: String?,
        surfaceKind: ScreenContextBundle.SurfaceKind,
        focusedField: FocusedFieldSummary?,
        selection: String?,
        recent: [ScreenContextBundle.MessageBlock],
        ambient: [String],
        visibleAXCandidates: [String],
        screenshot: Screenshot?,
        confidence: Double,
        screenshotDecision: ScreenshotDecision
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.appName = appName
        self.bundleId = bundleId
        self.windowTitle = windowTitle
        self.surfaceKind = surfaceKind
        self.focusedField = focusedField
        self.selection = selection
        self.recent = recent
        self.ambient = ambient
        self.visibleAXCandidates = visibleAXCandidates
        self.screenshot = screenshot
        self.confidence = confidence
        self.screenshotDecision = screenshotDecision
    }
}

public struct KnowledgeContext: Codable, Equatable, Sendable {
    public struct Hint: Codable, Equatable, Sendable {
        public enum Scope: String, Codable, Sendable {
            case globalStyle
            case appStyle
            case personTone
            case project
            case thread
            case recentMove
        }

        public let id: String
        public let scope: Scope
        public let text: String
        public let confidence: Double

        public init(id: String, scope: Scope, text: String, confidence: Double) {
            self.id = id
            self.scope = scope
            self.text = text
            self.confidence = confidence
        }
    }

    public let hints: [Hint]
    public let recentChipLabels: [String]
    public let retrievalSourceIDs: [String]

    public static let empty = KnowledgeContext(
        hints: [],
        recentChipLabels: [],
        retrievalSourceIDs: []
    )

    public init(hints: [Hint], recentChipLabels: [String], retrievalSourceIDs: [String]) {
        self.hints = hints
        self.recentChipLabels = recentChipLabels
        self.retrievalSourceIDs = retrievalSourceIDs
    }
}

public struct ContextBrief: Codable, Equatable, Sendable {
    public enum TargetDirection: String, Codable, CaseIterable, Sendable {
        case selected
        case incoming
        case outgoing
        case ambiguous
    }

    public let id: String
    public let captureID: String
    public let surfaceKind: ScreenContextBundle.SurfaceKind
    public let replyTargetSummary: String
    public let targetConfidence: Double
    public let relevantSnippets: [String]
    public let speakerHints: [String]
    public let targetDirection: TargetDirection
    public let ignoredChromeSummary: String
    public let missingContextFlags: [String]
    public let screenshotConfidence: Double
    public let sourceIDs: [String]

    public init(
        id: String,
        captureID: String,
        surfaceKind: ScreenContextBundle.SurfaceKind,
        replyTargetSummary: String,
        targetConfidence: Double,
        relevantSnippets: [String],
        speakerHints: [String],
        targetDirection: TargetDirection,
        ignoredChromeSummary: String,
        missingContextFlags: [String],
        screenshotConfidence: Double,
        sourceIDs: [String]
    ) {
        self.id = id
        self.captureID = captureID
        self.surfaceKind = surfaceKind
        self.replyTargetSummary = replyTargetSummary
        self.targetConfidence = targetConfidence
        self.relevantSnippets = relevantSnippets
        self.speakerHints = speakerHints
        self.targetDirection = targetDirection
        self.ignoredChromeSummary = ignoredChromeSummary
        self.missingContextFlags = missingContextFlags
        self.screenshotConfidence = screenshotConfidence
        self.sourceIDs = sourceIDs
    }
}

public struct ReplyPlanChip: Codable, Equatable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct ReplyPlanDraft: Codable, Equatable, Sendable {
    public let chipID: String
    public let text: String

    public init(chipID: String, text: String) {
        self.chipID = chipID
        self.text = text
    }
}

public struct ReplyPlan: Codable, Equatable, Sendable {
    public let id: String
    public let contextBriefID: String
    public let targetSummary: String
    public let targetConfidence: Double
    public let surfaceKind: ScreenContextBundle.SurfaceKind
    public let chips: [ReplyPlanChip]
    public let defaultChipID: String
    public let drafts: [ReplyPlanDraft]
    public let learnedLabel: String?
    public let warnings: [String]
    public let fallbackReason: String?

    public init(
        id: String,
        contextBriefID: String,
        targetSummary: String,
        targetConfidence: Double,
        surfaceKind: ScreenContextBundle.SurfaceKind,
        chips: [ReplyPlanChip],
        defaultChipID: String,
        drafts: [ReplyPlanDraft],
        learnedLabel: String?,
        warnings: [String],
        fallbackReason: String?
    ) throws {
        self.id = id
        self.contextBriefID = contextBriefID
        self.targetSummary = targetSummary
        self.targetConfidence = targetConfidence
        self.surfaceKind = surfaceKind
        self.chips = chips
        self.defaultChipID = defaultChipID
        self.drafts = drafts
        self.learnedLabel = learnedLabel
        self.warnings = warnings
        self.fallbackReason = fallbackReason

        try validate()
    }

    public func draft(for chipID: String) -> ReplyPlanDraft? {
        drafts.first { $0.chipID == chipID }
    }

    public func validate() throws {
        guard !targetSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReplyPlanningValidationError.emptyTargetSummary
        }
        guard chips.count == 3 else {
            throw ReplyPlanningValidationError.wrongChipCount(chips.count)
        }

        var chipIDs = Set<String>()
        for chip in chips {
            guard chipIDs.insert(chip.id).inserted else {
                throw ReplyPlanningValidationError.duplicateChipID(chip.id)
            }
        }
        guard chipIDs.contains(defaultChipID) else {
            throw ReplyPlanningValidationError.missingDefaultChip(defaultChipID)
        }

        let draftsByChip = Dictionary(grouping: drafts, by: \.chipID)
        for chip in chips {
            guard let chipDrafts = draftsByChip[chip.id], let draft = chipDrafts.first else {
                throw ReplyPlanningValidationError.missingDraft(chipID: chip.id)
            }
            guard !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReplyPlanningValidationError.emptyDraft(chipID: chip.id)
            }
        }
    }
}

public struct LearningEvent: Codable, Equatable, Sendable {
    public let id: String
    public let captureID: String
    public let contextBriefID: String?
    public let appName: String?
    public let bundleId: String?
    public let surfaceKind: ScreenContextBundle.SurfaceKind
    public let targetSummary: String
    public let chipsShown: [ReplyPlanChip]
    public let selectedChipID: String
    public let draftShown: String
    public let generatedDraft: String
    public let finalPastedText: String
    public let editDeltaSummary: String
    public let inferredSignals: [String]
    public let createdAt: Date

    public init(
        id: String,
        captureID: String,
        contextBriefID: String?,
        appName: String?,
        bundleId: String?,
        surfaceKind: ScreenContextBundle.SurfaceKind,
        targetSummary: String,
        chipsShown: [ReplyPlanChip],
        selectedChipID: String,
        draftShown: String,
        generatedDraft: String,
        finalPastedText: String,
        editDeltaSummary: String,
        inferredSignals: [String],
        createdAt: Date
    ) {
        self.id = id
        self.captureID = captureID
        self.contextBriefID = contextBriefID
        self.appName = appName
        self.bundleId = bundleId
        self.surfaceKind = surfaceKind
        self.targetSummary = targetSummary
        self.chipsShown = chipsShown
        self.selectedChipID = selectedChipID
        self.draftShown = draftShown
        self.generatedDraft = generatedDraft
        self.finalPastedText = finalPastedText
        self.editDeltaSummary = editDeltaSummary
        self.inferredSignals = inferredSignals
        self.createdAt = createdAt
    }
}

public protocol ContextBuilding: Sendable {
    func buildContext(from capturePack: CapturePack) async throws -> ContextBrief
}

public protocol OutputPlanning: Sendable {
    func planOutput(
        capturePack: CapturePack,
        contextBrief: ContextBrief,
        knowledgeContext: KnowledgeContext
    ) async throws -> ReplyPlan
}
