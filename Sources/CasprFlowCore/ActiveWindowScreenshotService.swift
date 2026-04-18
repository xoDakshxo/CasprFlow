import AppKit
import CoreGraphics
import Foundation

struct ActiveWindowScreenshot {
    let image: CGImage
    let metadata: ScreenshotMetadata

    func attachment() -> ScreenshotAttachment? {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.68]
        ) else {
            return nil
        }
        return ScreenshotAttachment(
            metadata: metadata,
            data: data,
            mimeType: "image/jpeg"
        )
    }
}

struct ScreenshotAttachment: Equatable, Sendable {
    let metadata: ScreenshotMetadata
    let data: Data
    let mimeType: String

    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}

enum ActiveWindowScreenshotService {
    static func captureInteractionRegions(
        processIdentifier pid: pid_t?,
        windowTitle: String?,
        focusedElementFrame: CGRect?,
        cursorLocation: CGPoint?
    ) -> [ActiveWindowScreenshot] {
        guard let pid,
              let windowInfo = activeWindowInfo(processIdentifier: pid, windowTitle: windowTitle) else {
            return []
        }

        var regions: [(source: String, rect: CGRect)] = []

        if let focusedElementFrame,
           focusedElementFrame.intersects(windowInfo.bounds) {
            regions.append((
                source: "focusedInteractionRegion",
                rect: focusedInteractionRegion(
                    focusedElementFrame: focusedElementFrame,
                    windowBounds: windowInfo.bounds
                )
            ))
        }

        if let cursorLocation,
           windowInfo.bounds.contains(cursorLocation) {
            regions.append((
                source: "cursorInteractionRegion",
                rect: cursorInteractionRegion(
                    cursorLocation: cursorLocation,
                    windowBounds: windowInfo.bounds
                )
            ))
        }

        return deduped(regions)
            .compactMap { region in
                captureRegion(
                    region.rect,
                    source: region.source,
                    windowID: windowInfo.windowID
                )
            }
    }

    static func capturePrimary(processIdentifier pid: pid_t?, windowTitle: String?) -> ActiveWindowScreenshot? {
        guard let pid,
              let windowInfo = activeWindowInfo(processIdentifier: pid, windowTitle: windowTitle),
              let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(windowInfo.windowID),
                [.bestResolution, .boundsIgnoreFraming]
              ) else {
            return nil
        }

        return ActiveWindowScreenshot(
            image: image,
            metadata: ScreenshotMetadata(
                source: "activeWindowImage",
                windowID: windowInfo.windowID,
                width: image.width,
                height: image.height
            )
        )
    }

    static func captureVisibleRegionFallback(
        processIdentifier pid: pid_t?,
        windowTitle: String?
    ) -> ActiveWindowScreenshot? {
        guard let pid,
              let windowInfo = activeWindowInfo(processIdentifier: pid, windowTitle: windowTitle) else {
            return nil
        }

        let bounds = windowInfo.bounds.integral
        guard bounds.width > 20,
              bounds.height > 20,
              let image = CGWindowListCreateImage(
                bounds,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
              ) else {
            return nil
        }

        return ActiveWindowScreenshot(
            image: image,
            metadata: ScreenshotMetadata(
                source: "visibleWindowRegion",
                windowID: windowInfo.windowID,
                width: image.width,
                height: image.height
            )
        )
    }

    private static func focusedInteractionRegion(
        focusedElementFrame: CGRect,
        windowBounds: CGRect
    ) -> CGRect {
        // Chat input is usually narrow at the bottom of the window with the
        // message history rendered above. Bias the crop heavily upward so
        // wrapped multi-line messages fit in a single OCR pass.
        let targetWidth = min(windowBounds.width, max(640, min(1100, focusedElementFrame.width + 560)))
        let minX = clamp(
            focusedElementFrame.midX - targetWidth / 2,
            lower: windowBounds.minX,
            upper: max(windowBounds.minX, windowBounds.maxX - targetWidth)
        )

        let top = max(windowBounds.minY, focusedElementFrame.minY - 1100)
        let bottom = min(windowBounds.maxY, focusedElementFrame.maxY + 220)
        let height = max(360, bottom - top)

        return CGRect(
            x: minX,
            y: clamp(top, lower: windowBounds.minY, upper: max(windowBounds.minY, windowBounds.maxY - height)),
            width: targetWidth,
            height: min(height, windowBounds.height)
        ).intersection(windowBounds).integral
    }

    private static func cursorInteractionRegion(
        cursorLocation: CGPoint,
        windowBounds: CGRect
    ) -> CGRect {
        let targetWidth = min(windowBounds.width, 980)
        let targetHeight = min(windowBounds.height, 820)
        let minX = clamp(
            cursorLocation.x - targetWidth / 2,
            lower: windowBounds.minX,
            upper: windowBounds.maxX - targetWidth
        )
        let minY = clamp(
            cursorLocation.y - targetHeight / 2,
            lower: windowBounds.minY,
            upper: windowBounds.maxY - targetHeight
        )

        return CGRect(x: minX, y: minY, width: targetWidth, height: targetHeight)
            .intersection(windowBounds)
            .integral
    }

    private static func captureRegion(
        _ region: CGRect,
        source: String,
        windowID: UInt32
    ) -> ActiveWindowScreenshot? {
        guard region.width > 20,
              region.height > 20,
              let image = CGWindowListCreateImage(
                region,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
              ) else {
            return nil
        }

        return ActiveWindowScreenshot(
            image: image,
            metadata: ScreenshotMetadata(
                source: source,
                windowID: windowID,
                width: image.width,
                height: image.height
            )
        )
    }

    private static func deduped(
        _ regions: [(source: String, rect: CGRect)]
    ) -> [(source: String, rect: CGRect)] {
        var dedupedRegions: [(source: String, rect: CGRect)] = []

        for region in regions {
            let isDuplicate = dedupedRegions.contains { existing in
                existing.rect.intersection(region.rect).area > min(existing.rect.area, region.rect.area) * 0.82
            }
            if !isDuplicate {
                dedupedRegions.append(region)
            }
        }

        return dedupedRegions
    }

    private static func activeWindowInfo(
        processIdentifier pid: pid_t,
        windowTitle: String?
    ) -> (windowID: UInt32, title: String?, bounds: CGRect)? {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else {
            return nil
        }

        let appWindows = rawWindows.compactMap { info -> (windowID: UInt32, title: String?, bounds: CGRect)? in
            guard let ownerPID = (info[kCGWindowOwnerPID] as? NSNumber)?.int32Value,
                  ownerPID == pid,
                  let windowID = (info[kCGWindowNumber] as? NSNumber)?.uint32Value else {
                return nil
            }

            let layer = (info[kCGWindowLayer] as? NSNumber)?.intValue ?? 0
            guard layer == 0 else { return nil }

            let title = info[kCGWindowName] as? String
            let bounds = Self.windowBounds(from: info[kCGWindowBounds]) ?? .zero
            return (windowID, title, bounds)
        }

        guard !appWindows.isEmpty else { return nil }

        if let windowTitle, !windowTitle.isEmpty {
            if let exact = appWindows.first(where: { $0.title == windowTitle }) {
                return exact
            }
            if let contains = appWindows.first(where: { candidate in
                guard let title = candidate.title else { return false }
                return title.contains(windowTitle) || windowTitle.contains(title)
            }) {
                return contains
            }
        }

        return appWindows
            .filter { $0.bounds.width > 20 && $0.bounds.height > 20 }
            .max { lhs, rhs in
                lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
            } ?? appWindows.first
    }

    private static func windowBounds(from value: Any?) -> CGRect? {
        if let dictionary = value as? NSDictionary,
           let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary) {
            return rect
        }

        guard let dictionary = value as? [String: Any],
              let x = (dictionary["X"] as? NSNumber)?.doubleValue,
              let y = (dictionary["Y"] as? NSNumber)?.doubleValue,
              let width = (dictionary["Width"] as? NSNumber)?.doubleValue,
              let height = (dictionary["Height"] as? NSNumber)?.doubleValue else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper >= lower else { return lower }
        return min(max(value, lower), upper)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard width > 0, height > 0 else { return 0 }
        return width * height
    }
}
