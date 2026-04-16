import AppKit
import SwiftUI

@MainActor
final class ReplyCapsuleController {
    private let productPanel: ReplyCapsulePanel
    private let debugPanel: ReplyCapsulePanel
    private let productHostingView: NSHostingView<AnyView>
    private let debugHostingView: NSHostingView<AnyView>
    private var currentContext: ScreenContext?

    init() {
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

        let productSize = NSSize(width: 420, height: 216)
        productHostingView.rootView = AnyView(ProductReplyCapsulePreviewView(context: context))
        productHostingView.frame = NSRect(origin: .zero, size: productSize)
        productPanel.setContentSize(productSize)
        positionProductPanel()
        productPanel.orderFrontRegardless()

        let debugSize = NSSize(width: 480, height: 520)
        debugHostingView.rootView = AnyView(ContextCapsuleView(context: context))
        debugHostingView.frame = NSRect(origin: .zero, size: debugSize)
        debugPanel.setContentSize(debugSize)
        positionDebugPanel()
        debugPanel.orderFrontRegardless()
    }

    func hide() {
        productPanel.orderOut(nil)
        debugPanel.orderOut(nil)
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

// MARK: - Product capsule preview

struct ProductReplyCapsulePreviewView: View {
    let context: ScreenContext

    @State private var draftText: String

    init(context: ScreenContext) {
        self.context = context
        _draftText = State(initialValue: Self.previewDraft(for: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("CasprFlow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("product preview")
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

            if let selected = context.selectedText {
                Text("Replying to: \(selected)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Highlight a message first.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $draftText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(height: 86)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )

            HStack {
                Text("Preview only")
                Spacer()
                Text("Enter paste | Cmd+R regenerate | Esc")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 420, height: 216, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private static func previewDraft(for context: ScreenContext) -> String {
        guard let selected = context.selectedText, !selected.isEmpty else {
            return "Select a message, then press Option + Space."
        }

        let trimmed = selected.replacingOccurrences(of: "\n", with: " ")
        let preview = trimmed.count > 110 ? String(trimmed.prefix(110)) + "..." : trimmed
        return "Draft preview for: \(preview)"
    }
}

struct DebugContextPlaceholderView: View {
    var body: some View {
        Text("Debug context appears after selected text is captured.")
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
    @State private var isAIDescExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Debug Context")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                // Header: app + window
                contextHeader

                Divider().opacity(0.3)

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

                // AI Description dump
                collapsibleSection(
                    label: "AI Description",
                    isExpanded: $isAIDescExpanded
                ) {
                    Text(context.aiDescription)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
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
