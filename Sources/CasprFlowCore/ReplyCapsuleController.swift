import AppKit
import SwiftUI

@MainActor
final class ReplyCapsuleController {
    private let productPanel: ReplyCapsulePanel
    private let debugPanel: ReplyCapsulePanel
    private let productHostingView: NSHostingView<AnyView>
    private let debugHostingView: NSHostingView<AnyView>
    private let generationService: GenerationServicing
    private let pasteService = PasteService()
    private var currentContext: ScreenContext?

    init(generationService: GenerationServicing = OpenAIGenerationService()) {
        self.generationService = generationService

        let productSize = NSSize(width: 420, height: 216)
        let debugSize = NSSize(width: 480, height: 520)

        productPanel = Self.makePanel(size: productSize)
        debugPanel = Self.makePanel(size: debugSize)

        productHostingView = NSHostingView(
            rootView: AnyView(ReplyCapsulePlaceholderView(title: "CasprFlow", message: "Ready."))
        )
        productHostingView.frame = NSRect(origin: .zero, size: productSize)

        debugHostingView = NSHostingView(
            rootView: AnyView(DebugContextPlaceholderView())
        )
        debugHostingView.frame = NSRect(origin: .zero, size: debugSize)

        productPanel.contentView = productHostingView
        debugPanel.contentView = debugHostingView

        let hideAll: () -> Void = { [weak self] in
            self?.hide()
        }
        productPanel.onEscape = hideAll
        debugPanel.onEscape = hideAll
    }

    private static func makePanel(size: NSSize) -> ReplyCapsulePanel {
        let panel = ReplyCapsulePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        return panel
    }

    func show(title: String, message: String) {
        currentContext = nil
        let size = NSSize(width: 360, height: 132)
        debugPanel.orderOut(nil)
        productHostingView.rootView = AnyView(ReplyCapsulePlaceholderView(title: title, message: message))
        productHostingView.frame = NSRect(origin: .zero, size: size)
        productPanel.setContentSize(size)
        positionProductPanel()
        productPanel.orderFrontRegardless()
    }

    func showContext(_ context: ScreenContext) {
        currentContext = context

        let productSize = NSSize(width: 440, height: 286)
        productHostingView.rootView = AnyView(
            ProductReplyCapsuleView(
                context: context,
                onLoadChips: { [generationService] in
                    try await generationService.chips(
                        for: context.bundle,
                        screenshots: context.screenshotAttachments
                    )
                },
                onExpand: { [generationService] chip, edit, previousDraft in
                    try await generationService.expand(
                        chip: chip,
                        bundle: context.bundle,
                        edit: edit,
                        previousDraft: previousDraft,
                        screenshots: context.screenshotAttachments
                    )
                },
                onPaste: { [weak self] draft in
                    Task { @MainActor in
                        await self?.pasteCurrentDraft(draft, context: context)
                    }
                },
                onCancel: { [weak self] in
                    self?.hide()
                }
            )
        )
        productHostingView.frame = NSRect(origin: .zero, size: productSize)
        productPanel.setContentSize(productSize)
        positionProductPanel()
        productPanel.orderFrontRegardless()
        productPanel.makeKey()

        let debugSize = NSSize(width: 480, height: 520)
        debugHostingView.rootView = AnyView(ContextCapsuleView(context: context))
        debugHostingView.frame = NSRect(origin: .zero, size: debugSize)
        debugPanel.setContentSize(debugSize)
        positionDebugPanel()
        debugPanel.orderFrontRegardless()
    }

    func hide() {
        currentContext = nil
        productPanel.orderOut(nil)
        debugPanel.orderOut(nil)
        resetHiddenViews()
    }

    private func resetHiddenViews() {
        let productSize = NSSize(width: 420, height: 216)
        productHostingView.rootView = AnyView(
            ReplyCapsulePlaceholderView(title: "CasprFlow", message: "Ready.")
        )
        productHostingView.frame = NSRect(origin: .zero, size: productSize)
        productPanel.setContentSize(productSize)

        let debugSize = NSSize(width: 480, height: 520)
        debugHostingView.rootView = AnyView(DebugContextPlaceholderView())
        debugHostingView.frame = NSRect(origin: .zero, size: debugSize)
        debugPanel.setContentSize(debugSize)
    }

    private func pasteCurrentDraft(_ draft: String, context: ScreenContext) async {
        guard PasteService.validatedPasteText(draft) != nil else {
            show(title: "Nothing to paste", message: "Write a reply first.")
            return
        }

        hide()
        let didPaste = await pasteService.paste(draft, into: context.processIdentifier)
        if !didPaste {
            show(
                title: "Paste unavailable",
                message: "Could not restore the previous app. Try focusing the reply field and use the hotkey again."
            )
        }
    }

    private func positionProductPanel() {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 84
        let size = productPanel.frame.size
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - margin
        )
        productPanel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func positionDebugPanel() {
        guard let screen = NSScreen.main else { return }

        let spacing: CGFloat = 16
        let inset: CGFloat = 16
        let frame = screen.visibleFrame
        let productFrame = productPanel.frame
        let debugSize = debugPanel.frame.size

        var origin = NSPoint(
            x: productFrame.maxX + spacing,
            y: productFrame.maxY - debugSize.height
        )

        if origin.x + debugSize.width > frame.maxX - inset {
            origin.x = productFrame.minX - spacing - debugSize.width
        }

        if origin.x < frame.minX + inset {
            origin.x = frame.midX - debugSize.width / 2
            origin.y = productFrame.minY - spacing - debugSize.height
        }

        origin.x = min(max(origin.x, frame.minX + inset), frame.maxX - debugSize.width - inset)
        origin.y = min(max(origin.y, frame.minY + inset), frame.maxY - debugSize.height - inset)

        debugPanel.setFrame(NSRect(origin: origin, size: debugSize), display: false)
    }
}

private final class ReplyCapsulePanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Simple placeholder view (errors, empty state)

struct ReplyCapsulePlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text("Esc to close")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 360, height: 132, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Product reply capsule

struct ProductReplyCapsuleView: View {
    let context: ScreenContext
    let onLoadChips: () async throws -> [Chip]
    let onExpand: (Chip, String?, String?) async throws -> String
    let onPaste: (String) -> Void
    let onCancel: () -> Void

    @State private var phase: CapsulePhase = .loadingChips
    @State private var chips: [Chip] = []
    @State private var selectedIndex = 0
    @State private var activeChip: Chip?
    @State private var customIntentText = ""
    @State private var draftText = ""
    @State private var lastGeneratedText = ""
    @State private var feedbackText = ""
    @State private var didStartLoading = false
    @State private var isClosed = false
    @State private var requestToken = UUID()

    init(
        context: ScreenContext,
        onLoadChips: @escaping () async throws -> [Chip],
        onExpand: @escaping (Chip, String?, String?) async throws -> String,
        onPaste: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.onLoadChips = onLoadChips
        self.onExpand = onExpand
        self.onPaste = onPaste
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("CasprFlow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(phase.badgeText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(.primary.opacity(0.06))
                    )

                Spacer(minLength: 8)

                if let appName = context.appName {
                    Text(appName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Text(contextSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            phaseContent

            HStack {
                Text(footerLeadingText)
                Spacer()
                Text(phase.footerText)
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 440, height: 286, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .background(
            CapsuleKeyboardCatcher(
                isActive: phase.capturesKeyboard,
                onPick: { index in
                    Task { await pickChip(at: index, edit: nil) }
                },
                onCycle: {
                    Task { await cycleChip() }
                },
                onRegenerate: {
                    Task { await regenerateCurrent() }
                },
                onSubmit: {
                    onPaste(draftText)
                },
                onCancel: onCancel
            )
            .frame(width: 0, height: 0)
        )
        .task {
            isClosed = false
            guard !didStartLoading else { return }
            didStartLoading = true
            await loadChips()
        }
        .onDisappear {
            isClosed = true
            requestToken = UUID()
            chips = []
            activeChip = nil
            customIntentText = ""
            draftText = ""
            lastGeneratedText = ""
            feedbackText = ""
            phase = .loadingChips
            didStartLoading = false
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .loadingChips:
            loadingView("Drafting moves...")
        case .choosing:
            VStack(alignment: .leading, spacing: 8) {
                chipPicker
                customIntentRow
            }
        case .expanding:
            VStack(alignment: .leading, spacing: 8) {
                chipPicker
                loadingView("Expanding \(currentChip?.label ?? "move")...")
                    .frame(height: 38, alignment: .leading)
            }
        case .editing:
            ReplyDraftEditor(
                text: $draftText,
                onSubmit: { onPaste(draftText) },
                onRegenerate: {
                    Task { await regenerateCurrent() }
                },
                onCycleChip: {
                    Task { await cycleChip() }
                },
                onCancel: onCancel
            )
            .frame(height: 92)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            feedbackRow
        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if !chips.isEmpty {
                    chipPicker
                }
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        }
    }

    private var chipPicker: some View {
        HStack(spacing: 8) {
            ForEach(chips.indices, id: \.self) { index in
                chipButton(index: index, chip: chips[index])
            }
        }
        .frame(height: 50)
    }

    private var customIntentRow: some View {
        HStack(spacing: 8) {
            TextField("Custom move: write a follow-up, ask for context...", text: $customIntentText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .onSubmit {
                    Task { await pickCustomIntent() }
                }

            Button("Use") {
                Task { await pickCustomIntent() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.09))
            )
        }
        .frame(height: 34)
    }

    private func chipButton(index: Int, chip: Chip) -> some View {
        let isSelected = index == selectedIndex
        let number = String(index + 1)
        return Button {
            Task { await pickChip(at: index, edit: nil) }
        } label: {
            HStack(spacing: 6) {
                Text(number)
                    .underline()
                    .font(.system(size: 11, weight: .semibold))
                Text(chip.label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.11) : Color.primary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.primary.opacity(0.18) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadingView(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.72)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
    }

    private var feedbackRow: some View {
        HStack(spacing: 8) {
            TextField("Regenerate cue: make it shorter, warmer, add blocker...", text: $feedbackText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .onSubmit {
                    Task { await regenerateCurrent() }
                }

            Button("Apply") {
                Task { await regenerateCurrent() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.09))
            )
        }
        .frame(height: 34)
    }

    private var currentChip: Chip? {
        if let activeChip {
            return activeChip
        }
        guard chips.indices.contains(selectedIndex) else { return nil }
        return chips[selectedIndex]
    }

    private var contextSummary: String {
        if let selected = context.selectedText {
            return "Selected: \(selected)"
        }
        if !context.bundle.prompt.isEmpty {
            return Self.contextPreview(context.bundle.prompt)
        }
        return "Focus a reply field with visible context."
    }

    private var footerLeadingText: String {
        if !context.screenshotAttachments.isEmpty {
            return "Screenshot + AX"
        }
        return context.bundle.surface.kind.rawValue
    }

    @MainActor
    private func loadChips() async {
        let token = UUID()
        requestToken = token
        phase = .loadingChips
        do {
            let loaded = try await onLoadChips()
            guard isCurrent(token) else { return }
            chips = Array(loaded.prefix(3))
            selectedIndex = 0
            activeChip = nil
            phase = chips.count == 3 ? .choosing : .error("Could not create three moves. Press Cmd+R to retry or Esc.")
        } catch {
            guard isCurrent(token) else { return }
            phase = .error(Self.userMessage(for: error))
        }
    }

    @MainActor
    private func pickChip(at index: Int, edit: String?) async {
        guard chips.indices.contains(index) else { return }
        let token = UUID()
        requestToken = token
        selectedIndex = index
        activeChip = chips[index]
        phase = .expanding

        do {
            draftText = try await onExpand(chips[index], edit, lastGeneratedText.isEmpty ? nil : lastGeneratedText)
            guard isCurrent(token) else { return }
            lastGeneratedText = draftText
            phase = .editing
        } catch {
            guard isCurrent(token) else { return }
            phase = .error(Self.userMessage(for: error))
        }
    }

    @MainActor
    private func pickCustomIntent() async {
        let text = customIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let chip = Chip(label: text)
        let token = UUID()
        requestToken = token
        activeChip = chip
        phase = .expanding

        do {
            draftText = try await onExpand(chip, nil, lastGeneratedText.isEmpty ? nil : lastGeneratedText)
            guard isCurrent(token) else { return }
            lastGeneratedText = draftText
            customIntentText = ""
            phase = .editing
        } catch {
            guard isCurrent(token) else { return }
            phase = .error(Self.userMessage(for: error))
        }
    }

    @MainActor
    private func cycleChip() async {
        guard !chips.isEmpty else { return }
        let next = (selectedIndex + 1) % chips.count
        let edit = phase == .editing ? draftText : nil
        activeChip = chips[next]
        await pickChip(at: next, edit: edit)
    }

    @MainActor
    private func regenerateCurrent() async {
        if chips.isEmpty {
            await loadChips()
            return
        }
        let feedback = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        let chip = activeChip ?? currentChip
        guard let chip else { return }
        let edit = feedback.isEmpty
            ? (draftText.isEmpty ? nil : draftText)
            : feedback
        await regenerate(chip: chip, edit: edit)
        if !feedback.isEmpty {
            feedbackText = ""
        }
    }

    @MainActor
    private func regenerate(chip: Chip, edit: String?) async {
        let token = UUID()
        requestToken = token
        activeChip = chip
        phase = .expanding

        do {
            draftText = try await onExpand(chip, edit, lastGeneratedText.isEmpty ? nil : lastGeneratedText)
            guard isCurrent(token) else { return }
            lastGeneratedText = draftText
            phase = .editing
        } catch {
            guard isCurrent(token) else { return }
            phase = .error(Self.userMessage(for: error))
        }
    }

    private func isCurrent(_ token: UUID) -> Bool {
        !isClosed && requestToken == token
    }

    private static func userMessage(for error: Error) -> String {
        if let generationError = error as? GenerationServiceError,
           let description = generationError.errorDescription {
            return description
        }
        return "Couldn't reach OpenAI. Press Cmd+R to retry or Esc."
    }

    private static func contextPreview(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "Context: " + String(normalized.prefix(150))
    }

    private enum CapsulePhase: Equatable {
        case loadingChips
        case choosing
        case expanding
        case editing
        case error(String)

        var badgeText: String {
            switch self {
            case .loadingChips: return "drafting"
            case .choosing: return "pick a move"
            case .expanding: return "expanding"
            case .editing: return "editing"
            case .error: return "needs attention"
            }
        }

        var footerText: String {
            switch self {
            case .loadingChips:
                return "Esc"
            case .choosing:
                return "1/2/3 pick | Tab cycle | Esc"
            case .expanding:
                return "Esc"
            case .editing:
                return "Enter paste | Cmd+R regenerate | Tab next | Esc"
            case .error:
                return "Cmd+R retry | Esc"
            }
        }

        var capturesKeyboard: Bool {
            switch self {
            case .editing:
                return false
            case .loadingChips, .choosing, .expanding, .error:
                return true
            }
        }
    }
}

private struct CapsuleKeyboardCatcher: NSViewRepresentable {
    let isActive: Bool
    let onPick: (Int) -> Void
    let onCycle: () -> Void
    let onRegenerate: () -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> CapsuleKeyCaptureView {
        let view = CapsuleKeyCaptureView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: CapsuleKeyCaptureView, context: Context) {
        update(nsView)
        guard isActive else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    private func update(_ view: CapsuleKeyCaptureView) {
        view.onPick = onPick
        view.onCycle = onCycle
        view.onRegenerate = onRegenerate
        view.onSubmit = onSubmit
        view.onCancel = onCancel
    }
}

private final class CapsuleKeyCaptureView: NSView {
    var onPick: ((Int) -> Void)?
    var onCycle: (() -> Void)?
    var onRegenerate: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "r" {
            onRegenerate?()
            return
        }

        if event.keyCode == 48 {
            onCycle?()
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            onSubmit?()
            return
        }

        switch event.keyCode {
        case 18:
            onPick?(0)
        case 19:
            onPick?(1)
        case 20:
            onPick?(2)
        default:
            super.keyDown(with: event)
        }
    }
}

struct ReplyDraftEditor: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onRegenerate: () -> Void
    let onCycleChip: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 8, height: 7)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.onSubmit = { context.coordinator.parent.onSubmit() }
        textView.onRegenerate = { context.coordinator.parent.onRegenerate() }
        textView.onCycleChip = { context.coordinator.parent.onCycleChip() }
        textView.onCancel = { context.coordinator.parent.onCancel() }

        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? KeyHandlingTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.onSubmit = { context.coordinator.parent.onSubmit() }
        textView.onRegenerate = { context.coordinator.parent.onRegenerate() }
        textView.onCycleChip = { context.coordinator.parent.onCycleChip() }
        textView.onCancel = { context.coordinator.parent.onCancel() }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ReplyDraftEditor

        init(parent: ReplyDraftEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class KeyHandlingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onRegenerate: (() -> Void)?
    var onCycleChip: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "r" {
            onRegenerate?()
            return
        }

        if event.keyCode == 48 {
            onCycleChip?()
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }
}

struct DebugContextPlaceholderView: View {
    var body: some View {
        Text("Debug context appears after the hotkey captures the current window.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(width: 480, height: 520, alignment: .topLeading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Rich context view

struct ContextCapsuleView: View {
    let context: ScreenContext

    @State private var isBeforeExpanded = false
    @State private var isSelectedExpanded = false
    @State private var isAfterExpanded = false
    @State private var isFullValueExpanded = false
    @State private var isVisibleUIExpanded = false
    @State private var isMetadataExpanded = false
    @State private var isWindowsExpanded = false
    @State private var isScreenshotExpanded = false
    @State private var isOCRExpanded = false
    @State private var isPromptContextExpanded = false
    @State private var isSurfaceExpanded = true
    @State private var isRecentExpanded = true
    @State private var isBundleJSONExpanded = false

    private var bundle: ScreenContextBundle { context.bundle }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Debug Context")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                // Header: app + window
                contextHeader

                Divider().opacity(0.3)

                collapsibleSection(
                    label: "Surface (\(bundle.surface.kind.rawValue), confidence \(String(format: "%.2f", bundle.confidence)))",
                    isExpanded: $isSurfaceExpanded
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        metadataRow("Kind", bundle.surface.kind.rawValue)
                        metadataRow("App", bundle.surface.appName)
                        metadataRow("Bundle", bundle.surface.bundleId)
                        metadataRow("Window", bundle.surface.windowTitle)
                        metadataRow("Input focused", bundle.surface.isInputFocused ? "yes" : "no")
                        if let focused = bundle.focused {
                            metadataRow("Field role", focused.role)
                            metadataRow("Field kind", focused.fieldKind.rawValue)
                        }
                    }
                }

                if !bundle.recent.isEmpty {
                    collapsibleSection(
                        label: "Recent (\(bundle.recent.count) blocks)",
                        isExpanded: $isRecentExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(bundle.recent.enumerated()), id: \.offset) { _, block in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(block.source)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.green.opacity(0.85))
                                        Text(String(format: "%.2f", block.confidence))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.blue.opacity(0.8))
                                    }
                                    Text(block.text)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(.primary.opacity(0.04))
                                )
                            }
                        }
                    }
                }

                if !bundle.ambient.isEmpty {
                    collapsibleSection(
                        label: "Ambient (\(bundle.ambient.count))",
                        isExpanded: $isVisibleUIExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(bundle.ambient.enumerated()), id: \.offset) { _, item in
                                Text(item)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                collapsibleSection(
                    label: "Bundle JSON",
                    isExpanded: $isBundleJSONExpanded
                ) {
                    Text(bundle.prettyJSON)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                collapsibleSection(
                    label: "AI Prompt (confidence \(String(format: "%.2f", bundle.confidence)), fallback=\(bundle.needsScreenshotFallback ? "yes" : "no"))",
                    isExpanded: $isPromptContextExpanded
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        metadataRow("Recent blocks", "\(bundle.recent.count)")
                        metadataRow("Ambient", "\(bundle.ambient.count)")
                        metadataRow("Dropped", "\(bundle.debug.droppedCount)")
                        Text(bundle.prompt.isEmpty ? "No usable prompt." : bundle.prompt)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if !context.screenshotMetadata.isEmpty {
                    collapsibleSection(
                        label: "Screenshots (\(context.screenshotMetadata.count))",
                        isExpanded: $isScreenshotExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(context.screenshotMetadata.enumerated()), id: \.offset) { _, screenshot in
                                VStack(alignment: .leading, spacing: 2) {
                                    metadataRow("Source", screenshot.source)
                                    metadataRow("Window ID", screenshot.windowID.map(String.init))
                                    metadataRow("Size", "\(screenshot.width)x\(screenshot.height)")
                                }
                            }
                            Text("Image is compressed and attached to OpenAI with AX context. OCR text is not sent.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if !context.ocrTextCandidates.isEmpty {
                    collapsibleSection(
                        label: "OCR Text (\(context.ocrTextCandidates.count) candidates)",
                        isExpanded: $isOCRExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(context.ocrTextCandidates.prefix(30).enumerated()), id: \.offset) { _, candidate in
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 6) {
                                        Text(candidate.source)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.green.opacity(0.85))
                                            .frame(width: 110, alignment: .leading)
                                        Text(String(format: "%.2f", candidate.confidence))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.blue.opacity(0.8))
                                            .frame(width: 34, alignment: .leading)
                                        Text(Self.normalizedRectDescription(candidate.boundingBox))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Text(candidate.text)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                }

                // Selected text
                if let selected = context.selectedText {
                    contextSection(
                        label: "Selected Text",
                        text: selected,
                        isExpanded: $isSelectedExpanded,
                        color: .primary
                    )
                }

                // Before context
                if let surrounding = context.surroundingText, !surrounding.before.isEmpty {
                    contextSection(
                        label: "Before",
                        text: surrounding.before,
                        isExpanded: $isBeforeExpanded,
                        color: .secondary
                    )
                }

                // After context
                if let surrounding = context.surroundingText, !surrounding.after.isEmpty {
                    contextSection(
                        label: "After",
                        text: surrounding.after,
                        isExpanded: $isAfterExpanded,
                        color: .secondary
                    )
                }

                // Full element value
                if let fullVal = context.fullElementValue, !fullVal.isEmpty {
                    contextSection(
                        label: "Full Element Text (\(fullVal.count) chars)",
                        text: fullVal,
                        isExpanded: $isFullValueExpanded,
                        color: .secondary
                    )
                }

                // All windows
                if context.allWindows.count > 0 {
                    collapsibleSection(
                        label: "Windows (\(context.allWindows.count))",
                        isExpanded: $isWindowsExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(context.allWindows.enumerated()), id: \.offset) { _, win in
                                HStack(spacing: 4) {
                                    Text(win.isFocused ? "●" : "○")
                                        .font(.system(size: 8))
                                        .foregroundColor(win.isFocused ? .blue : .gray)
                                    Text(win.title)
                                        .font(.system(size: 11))
                                        .foregroundColor(win.isFocused ? .primary : .secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }

                // Visible UI tree
                if !context.visibleElements.isEmpty {
                    collapsibleSection(
                        label: "Visible UI (\(context.visibleElements.count) elements)",
                        isExpanded: $isVisibleUIExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(context.visibleElements.enumerated()), id: \.offset) { _, el in
                                HStack(spacing: 0) {
                                    Text(String(repeating: "  ", count: el.depth))
                                        .font(.system(size: 9, design: .monospaced))
                                    Text(el.role)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.blue.opacity(0.8))
                                    if let label = el.label {
                                        Text(" \(label)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    } else if let value = el.value {
                                        Text(" \(String(value.prefix(60)))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                }

                // Metadata
                collapsibleSection(
                    label: "Metadata",
                    isExpanded: $isMetadataExpanded
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        metadataRow("Role", context.focusedElementRole)
                        metadataRow("Subrole", context.focusedElementSubrole)
                        metadataRow("Description", context.elementDescription)
                        metadataRow("Identifier", context.elementIdentifier)
                        metadataRow("Bundle", context.bundleIdentifier)
                        metadataRow("Document", context.documentURL)
                    }
                }

                Text("Esc to close")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .frame(width: 480, height: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var contextHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if let appName = context.appName {
                    Text(appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                if let bundleId = context.bundleIdentifier {
                    Text(bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if let windowTitle = context.windowTitle {
                Text(windowTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let docURL = context.documentURL {
                Text(docURL)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func collapsibleSection<Content: View>(
        label: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.wrappedValue.toggle() }) {
                HStack(spacing: 4) {
                    Text(isExpanded.wrappedValue ? "▾" : "▸")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.primary.opacity(0.03))
                    )
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 70, alignment: .trailing)
                    Text(value)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private static func normalizedRectDescription(_ rect: NormalizedRect) -> String {
        let x = String(format: "%.2f", rect.x)
        let y = String(format: "%.2f", rect.y)
        let width = String(format: "%.2f", rect.width)
        let height = String(format: "%.2f", rect.height)
        return "x:\(x) y:\(y) w:\(width) h:\(height)"
    }

    private func contextSection(
        label: String,
        text: String,
        isExpanded: Binding<Bool>,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                if text.count > 120 {
                    Button(action: { isExpanded.wrappedValue.toggle() }) {
                        Text(isExpanded.wrappedValue ? "Less" : "More")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .lineLimit(isExpanded.wrappedValue ? nil : 3)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.primary.opacity(0.04))
        )
    }
}
