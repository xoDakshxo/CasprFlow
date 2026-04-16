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
    private var handler: (() -> Void)?

    func registerDefaultHotkey(handler: @escaping () -> Void) throws {
        self.handler = handler
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

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var installedHandler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    service.handleHotkeyEvent(event)
                }
                return noErr
            },
            1,
            &eventType,
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

    private func handleHotkeyEvent(_ event: EventRef?) {
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

        handler?()
    }
}

private extension FourCharCode {
    init(_ string: String) {
        self = string.utf8.reduce(0) { result, byte in
            (result << 8) + FourCharCode(byte)
        }
    }
}
