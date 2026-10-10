import Foundation

public struct CapabilityDescriptor: @unchecked Sendable {
    public let name: String
    public let summary: String
    public let sideEffect: SideEffect
    public let schema: [String: Any]

    public init(name: String, summary: String, sideEffect: SideEffect, schema: [String: Any]) {
        self.name = name
        self.summary = summary
        self.sideEffect = sideEffect
        self.schema = schema
    }
}

@MainActor
public final class CapabilityRegistry {
    private let capabilities: [any Capability]
    private let capabilitiesByName: [String: any Capability]

    public init(_ capabilities: [any Capability]) {
        var ordered: [any Capability] = []
        var byName: [String: any Capability] = [:]

        for capability in capabilities where byName[capability.name] == nil {
            ordered.append(capability)
            byName[capability.name] = capability
        }

        self.capabilities = ordered
        self.capabilitiesByName = byName
    }

    public func capability(named name: String) -> (any Capability)? {
        capabilitiesByName[name]
    }

    public func catalog() -> [CapabilityDescriptor] {
        capabilities.map { capability in
            CapabilityDescriptor(
                name: capability.name,
                summary: capability.summary,
                sideEffect: capability.sideEffect,
                schema: capability.parameters.jsonSchema()
            )
        }
    }

    public func fastMatch(_ text: String) -> CapabilityCall? {
        for capability in capabilities {
            if let call = capability.fastMatch(text) {
                return call
            }
        }
        return nil
    }

    public func dispatch(_ call: CapabilityCall, context: ExecutionContext) async -> CapabilityResult {
        guard let capability = capability(named: call.capability) else {
            return .failure("Unknown capability: \(call.capability).")
        }

        if let validationFailure = validate(call, against: capability) {
            return validationFailure
        }

        do {
            return try await capability.execute(call, context: context)
        } catch {
            return .failure("Action failed: \(error.localizedDescription)")
        }
    }

    private func validate(_ call: CapabilityCall, against capability: any Capability) -> CapabilityResult? {
        var parametersByName: [String: CapabilityParameter] = [:]
        for parameter in capability.parameters.parameters {
            parametersByName[parameter.name] = parameter
        }

        for argumentName in call.arguments.keys where parametersByName[argumentName] == nil {
            return .failure("Unknown argument '\(argumentName)' for capability \(capability.name).")
        }

        for parameter in capability.parameters.parameters {
            let value = call.arguments[parameter.name]
            if parameter.required && (value == nil || value == .null) {
                return .failure("Missing required argument '\(parameter.name)' for capability \(capability.name).")
            }

            guard let value, value != .null else { continue }
            guard Self.value(value, matchesType: parameter.type) else {
                return .failure(
                    "Argument '\(parameter.name)' for capability \(capability.name) must be \(parameter.type)."
                )
            }
        }

        return nil
    }

    private static func value(_ value: JSONValue, matchesType type: String) -> Bool {
        switch (type, value) {
        case ("string", .string), ("number", .number), ("boolean", .bool),
             ("object", .object), ("array", .array):
            return true
        case ("integer", .number):
            return value.intValue != nil
        default:
            return false
        }
    }
}
