import AppKit
import SwiftUI

enum CasprFlowLogo {
    enum Variant: Sendable {
        case black
        case white

        var nsColor: NSColor {
            switch self {
            case .black:
                return .black
            case .white:
                return .white
            }
        }

        var swiftUIColor: Color {
            switch self {
            case .black:
                return .black
            case .white:
                return .white
            }
        }

        static func foreground(for appearance: NSAppearance) -> Variant {
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
        }

        static func foreground(for colorScheme: ColorScheme) -> Variant {
            colorScheme == .dark ? .white : .black
        }
    }

    static func image(variant: Variant, size: NSSize, isTemplate: Bool = false) -> NSImage {
        let image = image(color: variant.nsColor, size: size)
        image.isTemplate = isTemplate
        return image
    }

    private static func image(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.addPath(path(in: CGRect(origin: .zero, size: size)))
        context.setFillColor(color.cgColor)
        context.fillPath()
        context.restoreGState()

        image.unlockFocus()
        return image
    }

    static func path(in rect: CGRect) -> CGPath {
        let base = basePath()
        return scaledPath(base, in: rect)
    }

    static func elementPath(index: Int, in rect: CGRect) -> CGPath {
        let paths = baseElementPaths()
        guard paths.indices.contains(index) else {
            return CGMutablePath()
        }
        return scaledPath(paths[index], in: rect)
    }

    private static func scaledPath(_ base: CGPath, in rect: CGRect) -> CGPath {
        let scale = min(rect.width, rect.height) / 100
        let width = 100 * scale
        let height = 100 * scale
        var transform = CGAffineTransform(
            translationX: rect.midX - width / 2,
            y: rect.midY - height / 2
        ).scaledBy(x: scale, y: scale)
        return base.copy(using: &transform) ?? base
    }

    private static func basePath() -> CGPath {
        let combined = CGMutablePath()
        for path in baseElementPaths() {
            combined.addPath(path)
        }
        return combined
    }

    private static func baseElementPaths() -> [CGPath] {
        [baseElementPath1(), baseElementPath2(), baseElementPath3()]
    }

    private static func baseElementPath1() -> CGPath {
        let builder = LogoPathBuilder()

        builder.move(to: CGPoint(x: 64.2, y: 60.7))
        builder.curveBy(c1: CGPoint(x: -3.3, y: 2.3), c2: CGPoint(x: -7.1, y: 4.5), end: CGPoint(x: -10.8, y: 5.9))
        builder.curveBy(c1: CGPoint(x: -6.2, y: 2.3), c2: CGPoint(x: -13.5, y: 4.5), end: CGPoint(x: -22.6, y: 4))
        builder.curveBy(c1: CGPoint(x: -2.8, y: -0.2), c2: CGPoint(x: -6.4, y: -1.2), end: CGPoint(x: -8.4, y: -2.3))
        builder.curveBy(c1: CGPoint(x: -5.6, y: -3.1), c2: CGPoint(x: -9.3, y: -8.6), end: CGPoint(x: -9.6, y: -18))
        builder.curveBy(c1: CGPoint(x: -4.2, y: 7.2), c2: CGPoint(x: -11, y: 16.9), end: CGPoint(x: -11, y: 27.7))
        builder.curveBy(c1: CGPoint(x: 0.1, y: 3.5), c2: CGPoint(x: 1.7, y: 8.7), end: CGPoint(x: 6.4, y: 11.6))
        builder.curveBy(c1: CGPoint(x: 4.9, y: 3), c2: CGPoint(x: 12.4, y: 4), end: CGPoint(x: 23.9, y: 4))
        builder.curveBy(c1: CGPoint(x: 5.5, y: 0), c2: CGPoint(x: 14.7, y: -0.2), end: CGPoint(x: 20, y: -0.8))
        builder.curveBy(c1: CGPoint(x: 4.5, y: -0.5), c2: CGPoint(x: 8.3, y: -1), end: CGPoint(x: 12.2, y: -3.6))
        builder.curveBy(c1: CGPoint(x: 3.1, y: -1.9), c2: CGPoint(x: 6.2, y: -5.6), end: CGPoint(x: 6.2, y: -12))
        builder.curveBy(c1: CGPoint(x: 0.1, y: -5.1), c2: CGPoint(x: -2.7, y: -11.4), end: CGPoint(x: -6.3, y: -16.5))
        builder.close()

        return builder.path
    }

    private static func baseElementPath2() -> CGPath {
        let builder = LogoPathBuilder()

        builder.move(to: CGPoint(x: 34.7, y: 67.3))
        builder.lineBy(dx: 0.1, dy: 0)
        builder.curveBy(c1: CGPoint(x: 2.3, y: -8.7), c2: CGPoint(x: 6.1, y: -16.6), end: CGPoint(x: 11.2, y: -23.6))
        builder.curveBy(c1: CGPoint(x: 4.1, y: -5.5), c2: CGPoint(x: 10.5, y: -13.2), end: CGPoint(x: 19.6, y: -14.4))
        builder.curveBy(c1: CGPoint(x: 3.1, y: -0.3), c2: CGPoint(x: 7.1, y: 0.3), end: CGPoint(x: 10.5, y: 2.7))
        builder.curveBy(c1: CGPoint(x: -2.8, y: -6.2), c2: CGPoint(x: -7.7, y: -14.5), end: CGPoint(x: -12.8, y: -19.5))
        builder.curveBy(c1: CGPoint(x: -2.9, y: -3), c2: CGPoint(x: -6.7, y: -6.2), end: CGPoint(x: -12.4, y: -6.2))
        builder.curveBy(c1: CGPoint(x: -3.4, y: -0.1), c2: CGPoint(x: -6.8, y: 1), end: CGPoint(x: -9.7, y: 3.4))
        builder.curveBy(c1: CGPoint(x: -3.7, y: 2.9), c2: CGPoint(x: -7.1, y: 8.4), end: CGPoint(x: -9.7, y: 12.4))
        builder.curveBy(c1: CGPoint(x: -3.9, y: 6), c2: CGPoint(x: -9.6, y: 15.1), end: CGPoint(x: -11.9, y: 19.4))
        builder.curveBy(c1: CGPoint(x: -1.6, y: 3.2), c2: CGPoint(x: -3.3, y: 7.1), end: CGPoint(x: -3.3, y: 10.5))
        builder.curveBy(c1: CGPoint(x: 0, y: 8.1), c2: CGPoint(x: 5.5, y: 15.3), end: CGPoint(x: 18.4, y: 15.3))
        builder.close()

        return builder.path
    }

    private static func baseElementPath3() -> CGPath {
        let builder = LogoPathBuilder()

        builder.move(to: CGPoint(x: 98.5, y: 77.4))
        builder.curveBy(c1: CGPoint(x: -0.1, y: -5.3), c2: CGPoint(x: -2.8, y: -10.8), end: CGPoint(x: -6.1, y: -16.7))
        builder.curveBy(c1: CGPoint(x: -3.7, y: -6.5), c2: CGPoint(x: -8.8, y: -14.8), end: CGPoint(x: -11.7, y: -18.6))
        builder.smoothCurveBy(c2: CGPoint(x: -6.9, y: -9.1), end: CGPoint(x: -13.4, y: -9.6))
        builder.curveBy(c1: CGPoint(x: -6.1, y: -0.3), c2: CGPoint(x: -10.5, y: 3), end: CGPoint(x: -14.7, y: 7.3))
        builder.curveBy(c1: CGPoint(x: -2, y: 2.1), c2: CGPoint(x: -3.7, y: 4.3), end: CGPoint(x: -5.8, y: 7.4))
        builder.curveBy(c1: CGPoint(x: 7.8, y: 0.8), c2: CGPoint(x: 14.3, y: 5), end: CGPoint(x: 19.1, y: 10.6))
        builder.curveBy(c1: CGPoint(x: 4.1, y: 4.8), c2: CGPoint(x: 7.9, y: 11.3), end: CGPoint(x: 7.9, y: 20))
        builder.curveBy(c1: CGPoint(x: -0.1, y: 7.1), c2: CGPoint(x: -4.4, y: 12.1), end: CGPoint(x: -11.2, y: 15.3))
        builder.curveBy(c1: CGPoint(x: 3.8, y: 0.2), c2: CGPoint(x: 7.2, y: 0.5), end: CGPoint(x: 12.3, y: 0.5))
        builder.curveBy(c1: CGPoint(x: 6, y: -0.1), c2: CGPoint(x: 11.5, y: -0.7), end: CGPoint(x: 16.3, y: -3))
        builder.curveBy(c1: CGPoint(x: 4.8, y: -2.2), c2: CGPoint(x: 7.4, y: -7.1), end: CGPoint(x: 7.3, y: -13.2))
        builder.close()

        return builder.path
    }
}

private final class LogoPathBuilder {
    let path = CGMutablePath()
    private var current = CGPoint.zero
    private var lastControl: CGPoint?

    func move(to point: CGPoint) {
        path.move(to: point)
        current = point
        lastControl = nil
    }

    func lineBy(dx: CGFloat, dy: CGFloat) {
        let end = CGPoint(x: current.x + dx, y: current.y + dy)
        path.addLine(to: end)
        current = end
        lastControl = nil
    }

    func curveBy(c1: CGPoint, c2: CGPoint, end: CGPoint) {
        let control1 = CGPoint(x: current.x + c1.x, y: current.y + c1.y)
        let control2 = CGPoint(x: current.x + c2.x, y: current.y + c2.y)
        let endpoint = CGPoint(x: current.x + end.x, y: current.y + end.y)
        path.addCurve(to: endpoint, control1: control1, control2: control2)
        current = endpoint
        lastControl = control2
    }

    func smoothCurveBy(c2: CGPoint, end: CGPoint) {
        let control1: CGPoint
        if let lastControl {
            control1 = CGPoint(x: (2 * current.x) - lastControl.x, y: (2 * current.y) - lastControl.y)
        } else {
            control1 = current
        }
        let control2 = CGPoint(x: current.x + c2.x, y: current.y + c2.y)
        let endpoint = CGPoint(x: current.x + end.x, y: current.y + end.y)
        path.addCurve(to: endpoint, control1: control1, control2: control2)
        current = endpoint
        lastControl = control2
    }

    func close() {
        path.closeSubpath()
        lastControl = nil
    }
}

struct CasprFlowLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CasprFlowLogo.path(in: rect))
    }
}

struct CasprFlowLogoElementShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        Path(CasprFlowLogo.elementPath(index: index, in: rect))
    }
}

struct CasprFlowLogoMark: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CasprFlowLogoShape()
            .fill(CasprFlowLogo.Variant.foreground(for: colorScheme).swiftUIColor)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CasprFlowLoadingLogoMark: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    CasprFlowLogoElementShape(index: index)
                        .fill(fillColor.opacity(fillOpacity(for: index, at: timeline.date)))
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    private var fillColor: Color {
        CasprFlowLogo.Variant.foreground(for: colorScheme).swiftUIColor
    }

    private func fillOpacity(for index: Int, at date: Date) -> Double {
        let cycleDuration = 1.15
        let fillDuration = 0.4
        let holdUntil = 0.92
        let delay = 0.1 + (Double(index) * 0.1)
        let cycleTime = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration)
        let localTime = cycleTime - delay

        guard localTime >= 0 else { return 0 }
        guard localTime < holdUntil else { return 0 }
        guard localTime < fillDuration else { return 1 }

        return cubicEaseOut(localTime / fillDuration)
    }

    private func cubicEaseOut(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}
