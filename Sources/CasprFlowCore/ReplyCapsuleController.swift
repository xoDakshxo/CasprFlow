import AppKit
import SwiftUI

@MainActor
final class ReplyCapsuleController {
    private let panel: ReplyCapsulePanel
    private let hostingView: NSHostingView<AnyView>
    private var currentContext: ScreenContext?
    init() {
        let contentSize = NSSize(width: 420, height: 360)
        panel = ReplyCapsulePanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        hostingView = NSHostingView(
            rootView: AnyView(ReplyCapsulePlaceholderView(title: "CasprFlow", message: "Ready."))
        )
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        panel.contentView = hostingView
        panel.onEscape = { [weak self] in
            self?.hide()
        }
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
    }

    func show(title: String, message: String) {
        currentContext = nil
        let size = NSSize(width: 360, height: 132)
        hostingView.rootView = AnyView(ReplyCapsulePlaceholderView(title: title, message: message))
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.setContentSize(size)
        positionNearTopCenter()
        panel.orderFrontRegardless()
    }

    func showContext(_ context: ScreenContext) {
        currentContext = context
        let size = NSSize(width: 420, height: 360)
        hostingView.rootView = AnyView(ContextCapsuleView(context: context))
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.setContentSize(size)
        positionNearTopCenter()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionNearTopCenter() {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 84
        let size = panel.frame.size
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - margin
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
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

// MARK: - Rich context view

struct ContextCapsuleView: View {
    let context: ScreenContext

    @State private var isBeforeExpanded = false
    @State private var isSelectedExpanded = false
    @State private var isAfterExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header: app + window
                contextHeader

                Divider().opacity(0.3)

                // Selected text section
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

                // Metadata section
                metadataSection

                Text("Esc to close")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .frame(width: 420, height: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var contextHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    .font(.system(size: 12))
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

    @State private var isMetadataExpanded = false

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isMetadataExpanded.toggle() }) {
                HStack(spacing: 4) {
                    Text("Metadata")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(isMetadataExpanded ? "▾" : "▸")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isMetadataExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    metadataRow("Role", context.focusedElementRole)
                    metadataRow("Subrole", context.focusedElementSubrole)
                    metadataRow("Description", context.elementDescription)
                    metadataRow("Identifier", context.elementIdentifier)
                    metadataRow("Bundle", context.bundleIdentifier)
                }
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
                .font(.system(size: 12))
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
