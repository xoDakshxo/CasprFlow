import Foundation

// MARK: - Shared OCR / screenshot value types
//
// These were originally nested inside `ScreenContext`. They are top-level public
// types now so the public `ScreenContextBundle` can use them without forcing
// `ScreenContext` to be public (which would drag main-actor isolation into
// places it does not belong).

public struct NormalizedRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct OCRTextCandidate: Codable, Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let boundingBox: NormalizedRect
    public let source: String

    public init(text: String, confidence: Double, boundingBox: NormalizedRect, source: String) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.source = source
    }
}

public struct ScreenshotMetadata: Codable, Equatable, Sendable {
    public let source: String
    public let windowID: UInt32?
    public let width: Int
    public let height: Int

    public init(source: String, windowID: UInt32?, width: Int, height: Int) {
        self.source = source
        self.windowID = windowID
        self.width = width
        self.height = height
    }
}

/// Canonical structured context for one hotkey capture.
/// Built from `ScreenContext` and consumed by the chip prompt, expansion prompt,
/// learning store, and debug UI. JSON-encodable so it can be serialized into
/// prompts and dumped for inspection.
public struct ScreenContextBundle: Codable, Equatable, Sendable {
    public enum SurfaceKind: String, Codable, Sendable {
        case chat
        case browserChat
        case casual
        case email
        case docs
        case code
        case other
    }

    public enum FieldKind: String, Codable, Sendable {
        case chat
        case code
        case email
        case note
        case url
        case other
    }

    public struct SurfaceInfo: Codable, Equatable, Sendable {
        public let kind: SurfaceKind
        public let appName: String?
        public let bundleId: String?
        public let windowTitle: String?
        public let isInputFocused: Bool
    }

    public struct FocusedField: Codable, Equatable, Sendable {
        public let role: String?
        public let subrole: String?
        public let value: String?
        public let fieldKind: FieldKind
    }

    public struct MessageBlock: Codable, Equatable, Sendable {
        public let text: String
        public let source: String
        public let confidence: Double
        public let boundingBox: NormalizedRect?
    }

    public struct ScreenshotMeta: Codable, Equatable, Sendable {
        public let source: String
        public let width: Int
        public let height: Int
        public let windowID: UInt32?
    }

    public struct DebugBundle: Codable, Equatable, Sendable {
        public let rawAXCandidates: [String]
        public let rawOCRCandidates: [OCRTextCandidate]
        public let screenshots: [ScreenshotMeta]
        public let droppedCount: Int
    }

    public let surface: SurfaceInfo
    public let focused: FocusedField?
    public let selection: String?
    public let recent: [MessageBlock]
    public let ambient: [String]
    public let prompt: String
    public let confidence: Double
    /// True when text-only context is too thin to deterministically infer intent.
    /// Phase 5 must attach a screenshot and ask the model to read the screen.
    public let needsScreenshotFallback: Bool
    public let debug: DebugBundle

    public static let promptCharBudget = 2400
    public static let maxRecentBlocks = 12
    public static let maxAmbient = 8
    /// Confidence at or above this threshold means text-only prompting is enough.
    public static let textOnlyConfidenceThreshold = 0.70
}

// MARK: - JSON helper

extension ScreenContextBundle {
    /// Pretty-printed JSON for debug rendering.
    public var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - Surface classification

public enum SurfaceClassifier {
    public static func classify(
        bundleId: String?,
        appName: String?,
        windowTitle: String?,
        focusedRole: String?,
        focusedSubrole: String?
    ) -> ScreenContextBundle.SurfaceKind {
        let id = (bundleId ?? "").lowercased()
        let app = (appName ?? "").lowercased()

        if id.contains("slack") || app.contains("slack") { return .chat }
        if id.contains("microsoft.teams") || app.contains("teams") { return .chat }
        if id.contains("hnc.discord") || app.contains("discord") { return .chat }
        if id.contains("telegram") || app.contains("telegram") { return .chat }
        if id.contains("whatsapp") { return .chat }
        if id.contains("mobilesms") || app.contains("messages") { return .casual }
        if id.contains("apple.mail") || app.contains("mail") { return .email }
        if id.contains("airmail") || id.contains("superhuman") || id.contains("spark.desktop") { return .email }
        if id.contains("apple.notes") || app.contains("notes") { return .docs }
        if id.contains("notion") || id.contains("obsidian") || id.contains("bear") { return .docs }
        if id.contains("apple.dt.xcode")
            || id.contains("vscode")
            || id.contains("visualstudio.code")
            || id.contains("cursor")
            || id.contains("jetbrains")
            || id.contains("zed")
            || app.contains("xcode")
            || app.contains("code")
            || app.contains("cursor")
            || app.contains("zed") {
            return .code
        }

        let isBrowser = id.contains("safari")
            || id.contains("googlechrome")
            || id.contains("chrome")
            || id.contains("firefox")
            || id.contains("microsoftedge")
            || id.contains("company.thebrowser.browser")
            || id.contains("brave")
            || id.contains("arc")
        if isBrowser {
            let title = (windowTitle ?? "").lowercased()
            if title.contains("chat")
                || title.contains("messages")
                || title.contains("inbox")
                || title.contains("conversation")
                || title.contains("dm") {
                return .browserChat
            }
        }

        if let role = focusedRole?.lowercased(),
           role.contains("textarea") || role.contains("textfield") {
            // generic editable surface — leave as other
        }
        _ = focusedSubrole
        return .other
    }
}

// MARK: - OCR block grouping

public enum OCRBlockGrouper {
    /// Merge per-line OCR candidates into message-like blocks.
    /// Lines from the same source whose vertical gap is smaller than ~1.4× line
    /// height and whose horizontal extents overlap are joined into one block.
    /// Output is sorted top-to-bottom (most recent chat content first).
    public static func group(
        _ candidates: [OCRTextCandidate]
    ) -> [ScreenContextBundle.MessageBlock] {
        guard !candidates.isEmpty else { return [] }

        let bySource = Dictionary(grouping: candidates, by: { $0.source })

        var blocks: [ScreenContextBundle.MessageBlock] = []

        for (source, group) in bySource {
            // Sort top-to-bottom (Vision normalized origin is bottom-left, so
            // higher y means visually higher on screen — closer to history).
            let sorted = group.sorted { lhs, rhs in
                if abs(lhs.boundingBox.y - rhs.boundingBox.y) > 0.005 {
                    return lhs.boundingBox.y > rhs.boundingBox.y
                }
                return lhs.boundingBox.x < rhs.boundingBox.x
            }

            var current: [OCRTextCandidate] = []

            func flush() {
                guard !current.isEmpty else { return }
                let text = current.map(\.text).joined(separator: " ")
                let avgConf = current.reduce(0.0) { $0 + $1.confidence } / Double(current.count)
                let rect = unionRect(current.map(\.boundingBox))
                blocks.append(ScreenContextBundle.MessageBlock(
                    text: text,
                    source: source,
                    confidence: avgConf,
                    boundingBox: rect
                ))
                current.removeAll()
            }

            for line in sorted {
                if let last = current.last {
                    let gap = last.boundingBox.y - (line.boundingBox.y + line.boundingBox.height)
                    let lineHeight = max(line.boundingBox.height, 0.012)
                    let xOverlap = horizontalOverlap(last.boundingBox, line.boundingBox)
                    if gap < lineHeight * 1.4, xOverlap > 0.2 {
                        current.append(line)
                        continue
                    }
                    flush()
                }
                current.append(line)
            }
            flush()
        }

        // Sort blocks across sources by source priority then by visual y (top-down).
        return blocks.sorted { lhs, rhs in
            let lp = sourcePriority(lhs.source)
            let rp = sourcePriority(rhs.source)
            if lp != rp { return lp < rp }
            let ly = lhs.boundingBox?.y ?? 0
            let ry = rhs.boundingBox?.y ?? 0
            return ly > ry
        }
    }

    private static func sourcePriority(_ source: String) -> Int {
        switch source {
        case "focusedInteractionRegion": return 0
        case "cursorInteractionRegion": return 1
        case "visibleWindowRegion": return 2
        case "activeWindowImage": return 3
        default: return 4
        }
    }

    private static func unionRect(_ rects: [NormalizedRect]) -> NormalizedRect {
        guard let first = rects.first else {
            return NormalizedRect(x: 0, y: 0, width: 0, height: 0)
        }
        var minX = first.x
        var maxX = first.x + first.width
        var minY = first.y
        var maxY = first.y + first.height
        for r in rects.dropFirst() {
            minX = min(minX, r.x)
            maxX = max(maxX, r.x + r.width)
            minY = min(minY, r.y)
            maxY = max(maxY, r.y + r.height)
        }
        return NormalizedRect(
            x: minX, y: minY, width: maxX - minX, height: maxY - minY
        )
    }

    private static func horizontalOverlap(
        _ a: NormalizedRect,
        _ b: NormalizedRect
    ) -> Double {
        let lo = max(a.x, b.x)
        let hi = min(a.x + a.width, b.x + b.width)
        let inter = max(0, hi - lo)
        let span = min(a.width, b.width)
        guard span > 0 else { return 0 }
        return inter / span
    }
}

// MARK: - Bundle assembly

extension ScreenContextBundle {
    public static func assemble(
        appName: String?,
        bundleId: String?,
        windowTitle: String?,
        focusedRole: String?,
        focusedSubrole: String?,
        focusedValue: String?,
        selection: String?,
        rawAXCandidates: [String],
        ocrCandidates: [OCRTextCandidate],
        screenshots: [ScreenshotMetadata],
        droppedCount: Int
    ) -> ScreenContextBundle {
        let kind = SurfaceClassifier.classify(
            bundleId: bundleId,
            appName: appName,
            windowTitle: windowTitle,
            focusedRole: focusedRole,
            focusedSubrole: focusedSubrole
        )

        let isInputFocused: Bool = {
            guard let role = focusedRole?.lowercased() else { return false }
            return role.contains("textarea")
                || role.contains("textfield")
                || role.contains("combobox")
                || role.contains("searchfield")
        }()

        let fieldKind: FieldKind = inferFieldKind(
            kind: kind,
            role: focusedRole,
            value: focusedValue
        )

        let focused: FocusedField? = {
            guard focusedRole != nil || focusedValue != nil else { return nil }
            return FocusedField(
                role: focusedRole,
                subrole: focusedSubrole,
                value: focusedValue.map { String($0.prefix(800)) },
                fieldKind: fieldKind
            )
        }()

        let groupedBlocks = OCRBlockGrouper.group(ocrCandidates)

        // Split AX candidates into recent vs ambient by simple heuristic:
        // long, sentence-like strings go into recent; short label-like strings go into ambient.
        var recentBlocks: [MessageBlock] = []
        var ambient: [String] = []
        for raw in rawAXCandidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { continue }
            if isMessageLike(trimmed) {
                recentBlocks.append(MessageBlock(
                    text: trimmed,
                    source: "ax",
                    confidence: 1.0,
                    boundingBox: nil
                ))
            } else {
                ambient.append(trimmed)
            }
        }
        recentBlocks.append(contentsOf: groupedBlocks)

        // Dedupe by normalized text, preserve first occurrence (preserves source priority).
        recentBlocks = dedupeBlocks(recentBlocks)
        recentBlocks = Array(recentBlocks.prefix(maxRecentBlocks))
        ambient = Array(uniquePreservingOrder(ambient).prefix(maxAmbient))

        let selectionClean = selection.flatMap(SelectionTextNormalizer.clean)

        let promptText = buildPromptText(
            kind: kind,
            appName: appName,
            windowTitle: windowTitle,
            focused: focused,
            selection: selectionClean,
            recent: recentBlocks
        )

        let confidence = scoreConfidence(
            isInputFocused: isInputFocused,
            hasSelection: selectionClean != nil,
            focusedValueLength: focused?.value?.count ?? 0,
            recentCount: recentBlocks.count,
            ambientCount: ambient.count
        )
        let needsScreenshotFallback = confidence < textOnlyConfidenceThreshold

        let debug = DebugBundle(
            rawAXCandidates: rawAXCandidates,
            rawOCRCandidates: ocrCandidates,
            screenshots: screenshots.map {
                ScreenshotMeta(
                    source: $0.source,
                    width: $0.width,
                    height: $0.height,
                    windowID: $0.windowID
                )
            },
            droppedCount: droppedCount
        )

        return ScreenContextBundle(
            surface: SurfaceInfo(
                kind: kind,
                appName: appName,
                bundleId: bundleId,
                windowTitle: windowTitle,
                isInputFocused: isInputFocused
            ),
            focused: focused,
            selection: selectionClean,
            recent: recentBlocks,
            ambient: ambient,
            prompt: promptText,
            confidence: confidence,
            needsScreenshotFallback: needsScreenshotFallback,
            debug: debug
        )
    }

    private static func inferFieldKind(
        kind: SurfaceKind,
        role: String?,
        value: String?
    ) -> FieldKind {
        switch kind {
        case .chat, .browserChat: return .chat
        case .casual: return .chat
        case .email: return .email
        case .code: return .code
        case .docs: return .note
        case .other:
            if let role = role?.lowercased(),
               role.contains("url") || role.contains("address") {
                return .url
            }
            return .other
        }
    }

    private static func isMessageLike(_ text: String) -> Bool {
        if text.count < 16 { return false }
        let punct: Set<Character> = [".", "?", "!", ":", ","]
        let hasPunct = text.contains(where: { punct.contains($0) })
        let hasSpace = text.contains(" ")
        return hasPunct || (hasSpace && text.count > 28)
    }

    private static func dedupeBlocks(_ blocks: [MessageBlock]) -> [MessageBlock] {
        var seen = Set<String>()
        var out: [MessageBlock] = []
        for block in blocks {
            let key = block.text
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(block)
        }
        return out
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for v in values {
            let key = v.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                out.append(v)
            }
        }
        return out
    }

    private static func buildPromptText(
        kind: SurfaceKind,
        appName: String?,
        windowTitle: String?,
        focused: FocusedField?,
        selection: String?,
        recent: [MessageBlock]
    ) -> String {
        var parts: [String] = []
        parts.append("Surface: \(kind.rawValue)")
        if let appName { parts.append("App: \(appName)") }
        if let windowTitle { parts.append("Window: \(windowTitle)") }
        if let focused, let value = focused.value, !value.isEmpty {
            parts.append("Focused field (\(focused.fieldKind.rawValue)):\n\(value)")
        }
        if let selection, !selection.isEmpty {
            parts.append("Selection:\n\(selection)")
        }

        if !recent.isEmpty {
            var block = "Recent context:"
            var used = block.count
            for entry in recent {
                let line = "\n- \(entry.text)"
                if used + line.count > promptCharBudget { break }
                block.append(line)
                used += line.count
            }
            parts.append(block)
        }

        let joined = parts.joined(separator: "\n\n")
        return String(joined.prefix(promptCharBudget))
    }

    /// Deterministic confidence ladder. First match wins; no additive fuzz.
    /// 1.00 — user explicitly highlighted text.
    /// 0.85 — focused field has substantial text (>=40 chars) and there is recent context.
    /// 0.70 — input is focused and we have at least one grouped recent block.
    /// 0.50 — recent blocks only (no input focus). Text-only prompt is risky.
    /// 0.30 — only ambient labels (chrome/UI fragments).
    /// 0.00 — nothing usable.
    private static func scoreConfidence(
        isInputFocused: Bool,
        hasSelection: Bool,
        focusedValueLength: Int,
        recentCount: Int,
        ambientCount: Int
    ) -> Double {
        if hasSelection { return 1.00 }
        if focusedValueLength >= 40 && recentCount >= 1 { return 0.85 }
        if isInputFocused && recentCount >= 1 { return 0.70 }
        if recentCount >= 1 { return 0.50 }
        if ambientCount >= 1 { return 0.30 }
        return 0.00
    }
}
