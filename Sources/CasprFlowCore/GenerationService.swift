import Foundation

public struct Chip: Codable, Equatable, Identifiable, Sendable {
    public let label: String

    public var id: String { label }

    public init(label: String) {
        self.label = Self.sanitized(label)
    }

    private static func sanitized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GenerationServiceError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case missingScreenshot
    case invalidRequest
    case requestFailed(String)
    case invalidChips
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Set OPENAI_API_KEY or add openai_api_key to casprflow.config.local.json."
        case .missingScreenshot:
            return "Screen Recording is needed so Caspr can read the current screen."
        case .invalidRequest:
            return "Could not prepare the OpenAI request."
        case .requestFailed(let message):
            return message
        case .invalidChips:
            return "OpenAI did not return three usable moves. Press Cmd+R to retry or Esc."
        case .emptyResponse:
            return "OpenAI returned an empty reply. Press Cmd+R to retry or Esc."
        }
    }
}

@MainActor
protocol GenerationServicing {
    func chips(
        for bundle: ScreenContextBundle,
        screenshots: [ScreenshotAttachment]
    ) async throws -> [Chip]

    func expand(
        chip: Chip,
        bundle: ScreenContextBundle,
        edit: String?,
        previousDraft: String?,
        screenshots: [ScreenshotAttachment]
    ) async throws -> String
}

struct OpenAIGenerationConfig: Equatable {
    static let defaultModel = "gpt-5.4-nano"

    let apiKey: String?
    let model: String
    let reasoningEffort: String
    let imageDetail: String
    let userProfile: UserProfile

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> OpenAIGenerationConfig {
        let fileConfig = configURLs(fileManager: fileManager, homeDirectory: homeDirectory)
            .lazy
            .compactMap { url -> DeveloperConfig? in
                guard fileManager.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return try? JSONDecoder().decode(DeveloperConfig.self, from: data)
            }
            .first

        let apiKey = clean(environment["OPENAI_API_KEY"])
            ?? clean(fileConfig?.openaiAPIKey)
        let model = clean(environment["OPENAI_MODEL"])
            ?? clean(fileConfig?.openaiModel)
            ?? defaultModel
        let reasoningEffort = normalizedReasoningEffort(
            clean(environment["OPENAI_REASONING_EFFORT"])
            ?? clean(fileConfig?.openaiReasoningEffort)
            ?? "low"
        )
        let imageDetail = clean(environment["OPENAI_IMAGE_DETAIL"])
            ?? clean(fileConfig?.openaiImageDetail)
            ?? "high"
        let userProfile = UserProfile(
            name: clean(environment["CASPR_USER_NAME"])
                ?? clean(fileConfig?.userName)
                ?? Self.inferredUserName(),
            style: clean(fileConfig?.userStyle)
                ?? "direct, natural, concise; casual in personal chats, clear and practical in work chats; no fake enthusiasm",
            workContext: clean(fileConfig?.workContext)
        )

        return OpenAIGenerationConfig(
            apiKey: apiKey,
            model: model,
            reasoningEffort: reasoningEffort,
            imageDetail: imageDetail,
            userProfile: userProfile
        )
    }

    private static func configURLs(
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
        var urls: [URL] = []
        let rootConfigName = "casprflow.config.local.json"

        urls.append(
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(rootConfigName)
        )

        var bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<6 {
            urls.append(bundleParent.appendingPathComponent(rootConfigName))
            bundleParent = bundleParent.deletingLastPathComponent()
        }

        urls.append(
            homeDirectory
                .appendingPathComponent("Library/Application Support/CasprFlow/config.json")
        )

        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func inferredUserName() -> String {
        let fullName = NSFullUserName()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty, fullName.lowercased() != "root" {
            return fullName.components(separatedBy: .whitespaces).first ?? fullName
        }
        return "Daksh"
    }

    private static func normalizedReasoningEffort(_ value: String) -> String {
        let normalized = value.lowercased()
        // Some model/API combinations reject `minimal` even though it appears in
        // the general Responses schema. Keep the fast path by using `low`.
        if normalized == "minimal" { return "low" }
        let allowed: Set<String> = ["none", "low", "medium", "high", "xhigh"]
        return allowed.contains(normalized) ? normalized : "low"
    }

    private struct DeveloperConfig: Decodable {
        let openaiAPIKey: String?
        let openaiModel: String?
        let openaiReasoningEffort: String?
        let openaiImageDetail: String?
        let userName: String?
        let userStyle: String?
        let workContext: String?

        enum CodingKeys: String, CodingKey {
            case openaiAPIKey = "openai_api_key"
            case openaiModel = "openai_model"
            case openaiReasoningEffort = "openai_reasoning_effort"
            case openaiImageDetail = "openai_image_detail"
            case userName = "user_name"
            case userStyle = "user_style"
            case workContext = "work_context"
        }
    }
}

struct UserProfile: Equatable, Sendable {
    let name: String
    let style: String
    let workContext: String?
}

final class OpenAIGenerationService: GenerationServicing {
    private let config: OpenAIGenerationConfig
    private let endpoint: URL
    private let session: URLSession

    init(
        config: OpenAIGenerationConfig = .load(),
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        session: URLSession = .shared
    ) {
        self.config = config
        self.endpoint = endpoint
        self.session = session
    }

    func chips(
        for bundle: ScreenContextBundle,
        screenshots: [ScreenshotAttachment]
    ) async throws -> [Chip] {
        guard let apiKey = config.apiKey else {
            throw GenerationServiceError.missingAPIKey
        }

        let attachments = Self.screenshotsForVisionRequest(screenshots)
        guard !attachments.isEmpty else {
            throw GenerationServiceError.missingScreenshot
        }

        let output = try await OpenAIResponsesClient(
            apiKey: apiKey,
            model: config.model,
            endpoint: endpoint,
            session: session
        )
        .createResponse(
            prompt: GenerationPromptBuilder.chipPrompt(for: bundle, userProfile: config.userProfile),
            textFormat: OpenAIResponsesClient.chipJSONFormat,
            maxOutputTokens: 180,
            screenshots: attachments,
            imageDetail: config.imageDetail,
            reasoningEffort: config.reasoningEffort
        )

        return Self.parseAIChips(output, fallbackKind: bundle.surface.kind)
    }

    func expand(
        chip: Chip,
        bundle: ScreenContextBundle,
        edit: String?,
        previousDraft: String?,
        screenshots: [ScreenshotAttachment]
    ) async throws -> String {
        guard let apiKey = config.apiKey else {
            throw GenerationServiceError.missingAPIKey
        }

        let previousMomentum = IntentMomentumStore.shared.current()
        IntentMomentumStore.shared.record(chip: chip, bundle: bundle)

        let prompt = GenerationPromptBuilder.expansionPrompt(
            chip: chip,
            bundle: bundle,
            edit: edit,
            previousDraft: previousDraft,
            momentum: previousMomentum,
            userProfile: config.userProfile
        )
        let attachments = Self.screenshotsForVisionRequest(screenshots)
        let output = try await OpenAIResponsesClient(
            apiKey: apiKey,
            model: config.model,
            endpoint: endpoint,
            session: session
        )
        .createResponse(
            prompt: prompt,
            textFormat: nil,
            maxOutputTokens: 360,
            screenshots: attachments,
            imageDetail: config.imageDetail,
            reasoningEffort: config.reasoningEffort
        )

        guard let cleaned = SelectionTextNormalizer.clean(output) else {
            throw GenerationServiceError.emptyResponse
        }
        return cleaned
    }

    nonisolated static func screenshotsForRequest(
        bundle: ScreenContextBundle,
        screenshots: [ScreenshotAttachment]
    ) -> [ScreenshotAttachment] {
        guard bundle.needsScreenshotFallback else { return [] }
        return Array(screenshots.prefix(1))
    }

    nonisolated static func screenshotsForVisionRequest(
        _ screenshots: [ScreenshotAttachment]
    ) -> [ScreenshotAttachment] {
        Array(screenshots.prefix(1))
    }

    nonisolated static func parseAIChips(
        _ output: String,
        fallbackKind: ScreenContextBundle.SurfaceKind
    ) -> [Chip] {
        var chips = rawChipLabels(from: output)
            .map(normalizedChipLabel)
            .map(Chip.init(label:))
            .filter { !$0.label.isEmpty }
            .reduce(into: [Chip]()) { partial, chip in
                if !partial.contains(chip) {
                    partial.append(chip)
                }
            }

        for fallback in ChipFallback.chips(for: fallbackKind) where chips.count < 3 {
            if !chips.contains(fallback) {
                chips.append(fallback)
            }
        }

        return Array(chips.prefix(3))
    }

    private nonisolated static func rawChipLabels(from output: String) -> [String] {
        if let labels = labelsFromJSONObject(output) {
            return labels
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start < end {
            let jsonSlice = String(trimmed[start...end])
            if let labels = labelsFromJSONObject(jsonSlice) {
                return labels
            }
        }

        return trimmed
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: #"^\s*[-*•]?\s*\d*[\).\:]?\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^["']|["']$"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private nonisolated static func labelsFromJSONObject(_ output: String) -> [String]? {
        guard let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let dictionary = object as? [String: Any],
           let rawChips = dictionary["chips"] as? [String] {
            return rawChips
        }

        if let array = object as? [String] {
            return array
        }

        return nil
    }

    private nonisolated static func normalizedChipLabel(_ value: String) -> String {
        var cleaned = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`.,:;!?"))

        let prefixes = [
            "I would ",
            "You should ",
            "The user should ",
            "Reply with ",
            "Write "
        ]
        for prefix in prefixes where cleaned.lowercased().hasPrefix(prefix.lowercased()) {
            cleaned = String(cleaned.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        let words = cleaned.split(separator: " ").map(String.init)
        guard words.count > 3 else { return cleaned }
        return words.prefix(3).joined(separator: " ")
    }

    nonisolated static func parseChips(_ output: String, fallbackKind: ScreenContextBundle.SurfaceKind) -> [Chip] {
        guard let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawChips = object["chips"] as? [String] else {
            return ChipFallback.chips(for: fallbackKind)
        }

        let labels = rawChips
            .map(Chip.init(label:))
            .filter { !$0.label.isEmpty && $0.label.split(separator: " ").count <= 3 }
            .reduce(into: [Chip]()) { partial, chip in
                if !partial.contains(chip) {
                    partial.append(chip)
                }
            }

        guard labels.count == 3 else {
            return ChipFallback.chips(for: fallbackKind)
        }
        return labels
    }
}

struct MockGenerationService: GenerationServicing {
    var mockChips: [Chip]
    var expansionPrefix: String

    init(
        mockChips: [Chip] = [
            Chip(label: "Take it"),
            Chip(label: "Ask context"),
            Chip(label: "Push timing")
        ],
        expansionPrefix: String = "Mock expansion"
    ) {
        self.mockChips = mockChips
        self.expansionPrefix = expansionPrefix
    }

    func chips(
        for bundle: ScreenContextBundle,
        screenshots: [ScreenshotAttachment]
    ) async throws -> [Chip] {
        _ = bundle
        _ = screenshots
        return Array(mockChips.prefix(3))
    }

    func expand(
        chip: Chip,
        bundle: ScreenContextBundle,
        edit: String?,
        previousDraft: String?,
        screenshots: [ScreenshotAttachment]
    ) async throws -> String {
        _ = bundle
        _ = screenshots
        _ = previousDraft
        if let edit = SelectionTextNormalizer.clean(edit) {
            return "\(expansionPrefix): \(chip.label) after edit: \(edit)"
        }
        return "\(expansionPrefix): \(chip.label)"
    }
}

struct IntentMomentum: Equatable, Sendable {
    let chipLabel: String
    let surfaceKind: ScreenContextBundle.SurfaceKind
    let appName: String?
    let contextSummary: String
    let capturedAt: Date
}

@MainActor
final class IntentMomentumStore {
    static let shared = IntentMomentumStore()

    private var last: IntentMomentum?
    private let ttl: TimeInterval = 8 * 60

    private init() {}

    func current(now: Date = Date()) -> IntentMomentum? {
        guard let last,
              now.timeIntervalSince(last.capturedAt) <= ttl else {
            return nil
        }
        return last
    }

    func record(chip: Chip, bundle: ScreenContextBundle, now: Date = Date()) {
        last = IntentMomentum(
            chipLabel: chip.label,
            surfaceKind: bundle.surface.kind,
            appName: bundle.surface.appName,
            contextSummary: String(bundle.prompt.prefix(360)),
            capturedAt: now
        )
    }
}

enum ChipFallback {
    static func chips(for kind: ScreenContextBundle.SurfaceKind) -> [Chip] {
        labels(for: kind).map(Chip.init(label:))
    }

    static func labels(for kind: ScreenContextBundle.SurfaceKind) -> [String] {
        switch kind {
        case .chat:
            return ["Take it", "Push timing", "Ask context"]
        case .code:
            return ["Implement", "Inspect first", "Plan steps"]
        case .email:
            return ["Confirm", "Defer", "Decline"]
        case .casual:
            return ["Yes", "Soft no", "Not sure"]
        case .browserChat:
            return ["Confirm", "Clarify", "Push back"]
        case .docs:
            return ["Summarize", "Expand", "Rewrite"]
        case .other:
            return ["Confirm", "Clarify", "Decline"]
        }
    }
}

enum GenerationPromptBuilder {
    static func chipPrompt(for bundle: ScreenContextBundle, userProfile: UserProfile) -> String {
        """
        # Role
        You are Caspr's screenshot intent reader. You do not write the final reply yet.

        # Product Model
        The user presses a hotkey inside the app they are already using.
        Caspr must infer the active context, show exactly 3 short "moves", then expand the selected move later.

        Pattern:
        context -> 3 intent chips -> user picks one -> full response / action expands.

        # Inputs
        You receive:
        - one screenshot of the active app/window
        - AX context extracted from the focused app
        - no OCR transcript
        - the local user's identity/style profile

        Treat the screenshot as the source of truth for visual layout and latest-message position.
        Treat AX text as supporting context, especially for selection/focused-field/app/window metadata.

        # User Identity
        The person using Caspr is \(userProfile.name).
        Generate chips for \(userProfile.name) to pick as the next move.
        If a message says "hey \(userProfile.name)" or addresses \(userProfile.name), that message is addressed to the user. Do not write as if the other person is \(userProfile.name).
        User style: \(userProfile.style).
        \(userProfile.workContext.map { "Work context: \($0)." } ?? "Work context: infer only from the visible app/thread.")

        # Reply Target Priority
        Pick chips for the message/task the user is most likely replying to now.
        Use this priority order:
        1. If AX selected text exists, treat it as the primary reply target.
        2. Else, if the focused input belongs to a thread or chat, target the latest visible incoming message nearest the input/reply box.
        3. Else, target the active conversation/task in the main content area.
        4. Do not target older messages higher in the thread unless they are selected or visually active.
        5. If the visually latest message appears to be from \(userProfile.name) or is an outgoing bubble, use it as context only; target the latest incoming/counterparty message before it, or offer follow-up chips if the user is clearly composing a follow-up.
        6. Ignore sidebars, channel lists, nav labels, timestamps, avatars, buttons, and unrelated background text.

        This matters:
        - In Slack threads, prefer the latest message in the active thread/reply context, not an older message in channel history.
        - In iMessage, gray/left/incoming bubbles are usually from the other person; blue/right/outgoing bubbles are usually from \(userProfile.name).
        - In work chat, latest status/request/blocker near the composer is usually the reply target.

        # Hidden Analysis To Perform
        Before output, silently infer:
        - app/surface: Slack/work chat, Codex/agentic coding, iMessage/personal chat, email, docs, browser chat, or unknown
        - latest target: what exact visible message/task the user is responding to
        - speaker/context: Naga/manager/coworker/friend/family only if visible or strongly implied; never invent names or relationships
        - task state: request, status check, blocker, bug, implementation, social invite, ETA, follow-up, etc.
        - likely user need: accept, push timing, ask context, update status, trace bug, patch, plan, give ETA, soft no, joke, recover

        # Chip Quality Bar
        A chip is a move, not a reply.
        Good chips are action-level and instantly pickable:
        - Confirm
        - Push back
        - Clarify
        - Take it
        - Push timing
        - Ask context
        - No access
        - Ask for help
        - Check first
        - Implement
        - Inspect first
        - Plan steps
        - Trace bug
        - Patch directly
        - Say yes
        - Soft no
        - Not sure yet
        - Give ETA
        - Working late
        - Light joke

        Bad chips are full replies or vague filler:
        - Sure, I can do that
        - Let me check and get back to you
        - I don't have access to that
        - Reply politely
        - Need assistance

        # Surface Realization
        Generate chips that match the active app:
        - Slack/work chat: coordination moves like Take it, Push timing, Ask context, Update now, Still checking, Blocked
        - Codex/agentic coding: execution moves like Implement, Inspect first, Trace bug, Patch safely, Plan steps, Explain cause
        - iMessage/personal: human moves like Say yes, Soft no, Not sure yet, Give ETA, Working late, Light joke
        - Email: Confirm, Defer, Decline, Ask details, Follow up
        - Docs/browser/unknown: choose safe moves specific to visible context

        # Relationship And Tone
        - If the visible context is work-related, chips should reflect work coordination or execution.
        - If it is casual/personal, chips should reflect human/social moves.
        - If the other person is Naga or any named person, use that as relationship context, but do not put their name in every chip.
        - Do not produce chips that imply \(userProfile.name) is the other person.

        # Output Rules
        Return JSON only.
        Return exactly 3 chips.
        Each chip must be 1 to 3 words.
        Chips must be distinct in intent.
        Chips must be specific to the latest target when possible.
        Do not mention screenshots, AX, OCR, AI, or Caspr.
        Do not include explanations.

        # Few-Shot Examples
        Slack latest target: "Can you add LinkedList access handling to the onboarding flow today?"
        -> {"chips":["Take it","Push timing","Ask context"]}

        Codex prompt after that same task is active:
        -> {"chips":["Implement","Inspect first","Plan steps"]}

        iMessage latest target: "Bro are you free tonight?"
        -> {"chips":["Say yes","Soft no","Not sure yet"]}

        Slack manager latest target: "Any update on the retry bug?"
        -> {"chips":["Update now","Need more time","Still checking"]}

        Codex/debugging context around a retry bug:
        -> {"chips":["Trace bug","Patch directly","Explain cause"]}

        Slack latest target: "Should we refactor this now or just patch it?"
        -> {"chips":["Patch now","Refactor now","Patch then refactor"]}

        iMessage latest target: "You vanished lol"
        -> {"chips":["Light joke","Busy reply","Warm recovery"]}

        Slack latest target: "Did you start?"
        -> {"chips":["Started","Starting now","Blocked"]}

        # AX Context
        This is supporting context only. Do not treat it as OCR. Use selected text and focused field strongly.
        \(axContext(for: bundle))

        Return exactly: {"chips":["...","...","..."]}
        """
    }

    static func expansionPrompt(
        chip: Chip,
        bundle: ScreenContextBundle,
        edit: String?,
        previousDraft: String? = nil,
        momentum: IntentMomentum? = nil,
        userProfile: UserProfile
    ) -> String {
        var parts: [String] = [
            """
            # Role
            You are Caspr's expansion writer.

            # Product Model
            context -> 3 intent chips -> pick one -> full response / action expands.

            The user chose one chip. Expand only that chosen move into the exact text the user can paste into the current app.

            # Inputs
            You receive:
            - one screenshot of the active app/window
            - AX context extracted from the focused app
            - the chosen chip
            - optional previous generated draft
            - optional editor text written by the user before regenerate
            - optional adjacent previous move for cross-app momentum
            - the local user's identity/style profile

            Do not use OCR text. Use the screenshot as primary visual source and AX as supporting metadata/text.

            # User Identity
            The person using Caspr is \(userProfile.name).
            You are writing as \(userProfile.name), not to \(userProfile.name).
            If the visible message starts with "hey \(userProfile.name)" or otherwise addresses \(userProfile.name), answer from \(userProfile.name)'s perspective.
            Do not begin the reply with "Hey \(userProfile.name)" unless \(userProfile.name) is genuinely the recipient in the text being composed, which should almost never be true here.
            User style: \(userProfile.style).
            \(userProfile.workContext.map { "Work context: \($0)." } ?? "Work context: infer only from the visible app/thread.")

            # Reply Target Priority
            Expand against the latest relevant target, not stale history.
            1. If AX selected text exists, reply to that.
            2. Else reply to the latest visible incoming message nearest the focused input/reply box.
            3. Else use the active main conversation/task.
            4. If the visually latest message is from \(userProfile.name)/outgoing, use it as context only; answer the latest incoming/counterparty message before it, or write a follow-up if the chosen chip clearly asks for one.
            5. Ignore sidebars, nav, buttons, timestamps, avatars, and older messages unless selected.

            # Surface Realization
            - Slack/work chat: concise coordination language. Be specific about ownership, status, timing, blocker, or ask.
            - Codex/agentic coding: write an imperative instruction for an agent. Include inspect/implement/test/guardrail detail when relevant.
            - iMessage/personal chat: short, natural, human. Avoid corporate tone.
            - Email: polished but not verbose. Use clear structure when helpful.
            - Docs/browser/unknown: clear and direct.

            # Context Graph Constraint
            A future Caspr knowledge layer may know people, projects, tasks, and user style. In this MVP, infer only from visible screenshot/AX and adjacent move. Do not invent names, relationships, promises, access, deadlines, or completed work.

            # Style
            Default user style: direct, casual when appropriate, not over-polished, no fake enthusiasm, no generic "hope you're well", no markdown unless the target is a coding/agent prompt.

            # Chosen Move
            Chosen intent: \(chip.label)

            # AX Context
            \(axContext(for: bundle))
            """
        ]

        if let momentum {
            parts.append(
                """
                Recent adjacent move:
                - previous chip: \(momentum.chipLabel)
                - previous surface: \(momentum.surfaceKind.rawValue)
                - previous app: \(momentum.appName ?? "unknown")
                - previous context summary: \(momentum.contextSummary)
                Use this only if it clearly helps continuity across adjacent apps.
                """
            )
        }

        if let previousDraft = SelectionTextNormalizer.clean(previousDraft) {
            parts.append(
                """
                # Previous generated draft
                \(previousDraft)
                """
            )
        }

        if let edit = SelectionTextNormalizer.clean(edit) {
            parts.append(
                """
                # User editor text before regenerate
                \(edit)

                Interpret this carefully:
                - If it is a short instruction/cue like "make it shorter", "more casual", "warmer", "ask if tomorrow works", or "write a follow up", treat it as a regenerate instruction applied to the previous draft and current screenshot context.
                - If it is a partial or full draft, preserve its meaning and user tone while improving or completing it.
                - If it conflicts with the chosen chip, prefer the latest editor cue as long as it still fits the visible context.
                """
            )
        }

        parts.append(
            """
            # Output
            Write only the final pasteable text.
            No quotes.
            No alternatives.
            No explanations.
            Do not say what you are doing.
            """
        )
        return parts.joined(separator: "\n\n")
    }

    static func axContext(for bundle: ScreenContextBundle) -> String {
        var parts: [String] = []
        parts.append("Surface kind: \(bundle.surface.kind.rawValue)")
        if let appName = bundle.surface.appName {
            parts.append("App: \(appName)")
        }
        if let bundleId = bundle.surface.bundleId {
            parts.append("Bundle id: \(bundleId)")
        }
        if let windowTitle = bundle.surface.windowTitle {
            parts.append("Window: \(windowTitle)")
        }
        parts.append("Input focused: \(bundle.surface.isInputFocused ? "yes" : "no")")

        if let focused = bundle.focused {
            if let role = focused.role {
                parts.append("Focused role: \(role)")
            }
            parts.append("Focused field kind: \(focused.fieldKind.rawValue)")
            if let value = cleanAXText(focused.value) {
                parts.append("Focused field value:\n\(value)")
            }
        }

        if let selection = cleanAXText(bundle.selection) {
            parts.append("Selected text:\n\(selection)")
        }

        let candidates = uniqueAXCandidates(bundle.debug.rawAXCandidates)
        if !candidates.isEmpty {
            parts.append("Visible AX text candidates:\n" + candidates.map { "- \($0)" }.joined(separator: "\n"))
        }

        return String(parts.joined(separator: "\n\n").prefix(2400))
    }

    private static func uniqueAXCandidates(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []

        for value in values {
            guard let cleaned = cleanAXText(value),
                  !isLikelyChrome(cleaned) else {
                continue
            }

            let key = cleaned
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            guard seen.insert(key).inserted else { continue }
            out.append(cleaned)
            if out.count >= 16 { break }
        }

        return out
    }

    private static func cleanAXText(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else { return nil }
        return String(cleaned.prefix(420))
    }

    private static func isLikelyChrome(_ value: String) -> Bool {
        let lower = value.lowercased()
        let exactChrome: Set<String> = [
            "send", "submit", "cancel", "close", "minimize", "search", "new message",
            "reply", "edit", "copy", "paste", "share", "back", "next", "done"
        ]
        if exactChrome.contains(lower) { return true }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return true }
        if lower.count <= 3 && !lower.contains("?") { return true }
        return false
    }
}

final class OpenAIResponsesClient {
    static var chipJSONFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "casprflow_chips",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "chips": [
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": [
                            "type": "string"
                        ]
                    ]
                ],
                "required": ["chips"],
                "additionalProperties": false
            ]
        ]
    }

    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let session: URLSession

    init(
        apiKey: String,
        model: String,
        endpoint: URL,
        session: URLSession
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.session = session
    }

    func createResponse(
        prompt: String,
        textFormat: [String: Any]?,
        maxOutputTokens: Int,
        screenshots: [ScreenshotAttachment],
        imageDetail: String,
        reasoningEffort: String
    ) async throws -> String {
        let body = Self.requestBody(
            model: model,
            prompt: prompt,
            textFormat: textFormat,
            maxOutputTokens: maxOutputTokens,
            screenshots: screenshots,
            imageDetail: imageDetail,
            reasoningEffort: reasoningEffort
        )

        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            throw GenerationServiceError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationServiceError.requestFailed("OpenAI returned a non-HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: responseData, encoding: .utf8)
                .map { String($0.prefix(220)) }
                ?? "No response body"
            throw GenerationServiceError.requestFailed("OpenAI request failed (\(httpResponse.statusCode)): \(message)")
        }

        guard let output = Self.extractOutputText(from: responseData),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GenerationServiceError.emptyResponse
        }
        return output
    }

    static func requestBody(
        model: String,
        prompt: String,
        textFormat: [String: Any]?,
        maxOutputTokens: Int,
        screenshots: [ScreenshotAttachment],
        imageDetail: String,
        reasoningEffort: String
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "instructions": "You are CasprFlow, a Mac reply layer. Follow the product prompt exactly. Prioritize the latest active message, write as the configured user, and keep output concise.",
            "input": [
                [
                    "role": "user",
                    "content": inputContent(
                        prompt: prompt,
                        screenshots: screenshots,
                        imageDetail: imageDetail
                    )
                ]
            ],
            "max_output_tokens": maxOutputTokens,
            "reasoning": [
                "effort": reasoningEffort
            ],
            "store": false
        ]

        if let textFormat {
            body["text"] = ["format": textFormat]
        }

        return body
    }

    static func inputContent(
        prompt: String,
        screenshots: [ScreenshotAttachment],
        imageDetail: String = "high"
    ) -> [[String: Any]] {
        var content: [[String: Any]] = [
            [
                "type": "input_text",
                "text": prompt
            ]
        ]

        for screenshot in screenshots.prefix(1) {
            content.append([
                "type": "input_image",
                "image_url": screenshot.dataURL,
                "detail": imageDetail
            ])
        }
        return content
    }

    static func extractOutputText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let direct = object["output_text"] as? String,
           !direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return direct
        }

        if let output = object["output"] as? [[String: Any]] {
            let text = output
                .flatMap { item -> [[String: Any]] in
                    item["content"] as? [[String: Any]] ?? []
                }
                .compactMap { part -> String? in
                    part["text"] as? String
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }

        return nil
    }
}
