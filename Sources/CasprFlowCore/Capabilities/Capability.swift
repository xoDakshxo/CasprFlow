import Foundation

public enum SideEffect: String, Sendable {
    case readOnly
    case local
    case confirm
}

public struct CapabilityParameter: Sendable {
    public let name: String
    public let type: String
    public let description: String
    public let required: Bool

    public init(name: String, type: String, description: String, required: Bool) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
    }
}

public struct CapabilitySchema: Sendable {
    public let parameters: [CapabilityParameter]

    public init(parameters: [CapabilityParameter]) {
        self.parameters = parameters
    }

    public func jsonSchema() -> [String: Any] {
        let properties = parameters.reduce(into: [String: Any]()) { partial, parameter in
            partial[parameter.name] = [
                "type": parameter.type,
                "description": parameter.description
            ]
        }

        return [
            "type": "object",
            "properties": properties,
            "required": parameters.filter(\.required).map(\.name),
            "additionalProperties": false
        ]
    }
}

public struct CapabilityCall: Equatable, Sendable {
    public let capability: String
    public let arguments: [String: JSONValue]

    public init(capability: String, arguments: [String: JSONValue] = [:]) {
        self.capability = capability
        self.arguments = arguments
    }

    public func string(_ key: String) -> String? {
        arguments[key]?.stringValue
    }

    public func int(_ key: String) -> Int? {
        arguments[key]?.intValue
    }

    public func number(_ key: String) -> Double? {
        arguments[key]?.numberValue
    }

    public func bool(_ key: String) -> Bool? {
        arguments[key]?.boolValue
    }
}

public struct CapabilityResult: Sendable {
    public let ok: Bool
    public let message: String?
    public let observation: String?
    public let data: [String: JSONValue]

    public init(
        ok: Bool,
        message: String? = nil,
        observation: String? = nil,
        data: [String: JSONValue] = [:]
    ) {
        self.ok = ok
        self.message = message
        self.observation = observation
        self.data = data
    }

    public static func success(_ message: String?) -> CapabilityResult {
        CapabilityResult(ok: true, message: message, observation: message)
    }

    public static func failure(_ message: String) -> CapabilityResult {
        CapabilityResult(ok: false, message: message, observation: message)
    }

    public var actionResult: ActionResult {
        ActionResult(ok: ok, message: message)
    }
}

public extension ActionResult {
    var capabilityResult: CapabilityResult {
        CapabilityResult(ok: ok, message: message, observation: message)
    }
}

public protocol Capability: Sendable {
    var name: String { get }
    var summary: String { get }
    var parameters: CapabilitySchema { get }
    var sideEffect: SideEffect { get }
    func fastMatch(_ text: String) -> CapabilityCall?
    func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult
}

public extension Capability {
    func fastMatch(_ text: String) -> CapabilityCall? {
        nil
    }
}
