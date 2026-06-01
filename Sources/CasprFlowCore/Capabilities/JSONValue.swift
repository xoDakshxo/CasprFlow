import Foundation

public enum JSONValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    public var intValue: Int? {
        guard case .number(let value) = self, value.rounded() == value else { return nil }
        return Int(value)
    }

    public var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    public var anyValue: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .array(let values):
            return values.map(\.anyValue)
        case .object(let values):
            return Self.anyDictionary(from: values)
        case .null:
            return NSNull()
        }
    }

    public init?(any value: Any) {
        switch value {
        case let value as JSONValue:
            self = value
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .number(Double(value))
        case let value as Int8:
            self = .number(Double(value))
        case let value as Int16:
            self = .number(Double(value))
        case let value as Int32:
            self = .number(Double(value))
        case let value as Int64:
            self = .number(Double(value))
        case let value as UInt:
            self = .number(Double(value))
        case let value as UInt8:
            self = .number(Double(value))
        case let value as UInt16:
            self = .number(Double(value))
        case let value as UInt32:
            self = .number(Double(value))
        case let value as UInt64:
            self = .number(Double(value))
        case let value as Float:
            self = .number(Double(value))
        case let value as Double:
            self = .number(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        case let value as [Any]:
            var values: [JSONValue] = []
            values.reserveCapacity(value.count)
            for element in value {
                guard let json = JSONValue(any: element) else { return nil }
                values.append(json)
            }
            self = .array(values)
        case let value as [String: Any]:
            guard let object = Self.dictionary(from: value) else { return nil }
            self = .object(object)
        case _ as NSNull:
            self = .null
        default:
            return nil
        }
    }

    public static func dictionary(from value: [String: Any]) -> [String: JSONValue]? {
        var object: [String: JSONValue] = [:]
        object.reserveCapacity(value.count)

        for (key, item) in value {
            guard let json = JSONValue(any: item) else { return nil }
            object[key] = json
        }

        return object
    }

    public static func anyDictionary(from value: [String: JSONValue]) -> [String: Any] {
        value.mapValues(\.anyValue)
    }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let values):
            try container.encode(values)
        case .null:
            try container.encodeNil()
        }
    }
}
