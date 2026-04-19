import AppKit
import CoreGraphics

struct SystemSettingsWindowSnapshot: Equatable {
    let frame: NSRect
    let visibleFrame: NSRect
}

enum SystemSettingsWindowLocator {
    static func frontmostWindow() -> SystemSettingsWindowSnapshot? {
        guard isSystemSettingsFrontmost,
              let app = settingsApplication(),
              let rawWindows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[CFString: Any]] else {
            return nil
        }

        let windows = rawWindows.compactMap { info -> SystemSettingsWindowSnapshot? in
            guard let ownerPID = (info[kCGWindowOwnerPID] as? NSNumber)?.int32Value,
                  ownerPID == app.processIdentifier,
                  let bounds = windowBounds(from: info[kCGWindowBounds]) else {
                return nil
            }

            let layer = (info[kCGWindowLayer] as? NSNumber)?.intValue ?? 0
            guard layer == 0,
                  bounds.width > 120,
                  bounds.height > 120 else {
                return nil
            }

            let geometry = appKitGeometry(from: bounds)
            return SystemSettingsWindowSnapshot(
                frame: geometry.frame,
                visibleFrame: geometry.visibleFrame
            )
        }

        return windows.max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }
    }

    private static var isSystemSettingsFrontmost: Bool {
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return bundleId == "com.apple.systempreferences" || bundleId == "com.apple.systemsettings"
    }

    private static func settingsApplication() -> NSRunningApplication? {
        let bundleIds = [
            "com.apple.systempreferences",
            "com.apple.systemsettings"
        ]

        return bundleIds
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .max { lhs, rhs in
                let lhsScore = lhs.activationPolicy == .prohibited ? 0 : 1
                let rhsScore = rhs.activationPolicy == .prohibited ? 0 : 1
                return lhsScore < rhsScore
            }
    }

    private static func appKitGeometry(from cgFrame: CGRect) -> (frame: CGRect, visibleFrame: CGRect) {
        let screens = NSScreen.screens.compactMap { screen -> (frame: CGRect, visibleFrame: CGRect, cgBounds: CGRect)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            return (
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                cgBounds: CGDisplayBounds(displayID)
            )
        }

        let matchedScreen = screens
            .filter { $0.cgBounds.intersects(cgFrame) }
            .max { lhs, rhs in
                let lhsIntersection = lhs.cgBounds.intersection(cgFrame)
                let rhsIntersection = rhs.cgBounds.intersection(cgFrame)
                return lhsIntersection.width * lhsIntersection.height < rhsIntersection.width * rhsIntersection.height
            }

        guard let matchedScreen else {
            return (
                frame: cgFrame,
                visibleFrame: NSScreen.main?.visibleFrame ?? CGRect(origin: .zero, size: cgFrame.size)
            )
        }

        let localX = cgFrame.minX - matchedScreen.cgBounds.minX
        let localY = cgFrame.minY - matchedScreen.cgBounds.minY
        let frame = CGRect(
            x: matchedScreen.frame.minX + localX,
            y: matchedScreen.frame.maxY - localY - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )

        return (frame: frame, visibleFrame: matchedScreen.visibleFrame)
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
}
