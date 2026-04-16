import Carbon

public struct HotkeyDescriptor: Equatable, Sendable {
    public let displayName: String
    public let keyCode: UInt32
    public let carbonModifiers: UInt32

    public static let defaultHotkey = HotkeyDescriptor(
        displayName: "Option + Space",
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey)
    )
}
