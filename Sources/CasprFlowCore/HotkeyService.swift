import Carbon
import Foundation

enum HotkeyRegistrationError: Error, Equatable {
    case eventHandlerInstallFailed(OSStatus)
    case registrationFailed(OSStatus)
}

@MainActor
final class HotkeyService {
    private static let signature = FourCharCode("CSPF")
    private static let hotkeyID = UInt32(1)

    private var eventHandlerRef: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var onPress: (() -> Void)?
    private var onRelease: (() -> Void)?

    /// Register the default hotkey as a simple trigger (press only).
    func registerDefaultHotkey(handler: @escaping () -> Void) throws {
        try registerDefaultHotkey(onPress: handler, onRelease: nil)
    }

    /// Register the default hotkey as **push-to-talk**: `onPress` fires on key-down
    /// (start listening), `onRelease` fires on key-up (stop listening → process).
    func registerDefaultHotkey(onPress: @escaping () -> Void, onRelease: (() -> Void)?) throws {
        self.onPress = onPress
        self.onRelease = onRelease
        try installEventHandlerIfNeeded()
        try registerHotkey(HotkeyDescriptor.defaultHotkey)
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else { return }

        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        var installedHandler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                let kind = event.map { GetEventKind($0) } ?? 0
                Task { @MainActor in
                    service.handleHotkeyEvent(event, kind: kind)
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )

        guard status == noErr else {
            throw HotkeyRegistrationError.eventHandlerInstallFailed(status)
        }
        eventHandlerRef = installedHandler
    }

    private func registerHotkey(_ descriptor: HotkeyDescriptor) throws {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        let eventHotkeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.hotkeyID
        )
        var registeredHotkey: EventHotKeyRef?

        let status = RegisterEventHotKey(
            descriptor.keyCode,
            descriptor.carbonModifiers,
            eventHotkeyID,
            GetApplicationEventTarget(),
            0,
            &registeredHotkey
        )

        guard status == noErr else {
            throw HotkeyRegistrationError.registrationFailed(status)
        }
        hotkeyRef = registeredHotkey
    }

    private func handleHotkeyEvent(_ event: EventRef?, kind: UInt32) {
        guard let event else { return }
        var eventHotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventHotkeyID
        )

        guard status == noErr,
              eventHotkeyID.signature == Self.signature,
              eventHotkeyID.id == Self.hotkeyID else {
            return
        }

        switch Int(kind) {
        case kEventHotKeyPressed:
            onPress?()
        case kEventHotKeyReleased:
            onRelease?()
        default:
            break
        }
    }
}

private extension FourCharCode {
    init(_ string: String) {
        self = string.utf8.reduce(0) { result, byte in
            (result << 8) + FourCharCode(byte)
        }
    }
}
