import Foundation

enum DeviceProtocolValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: DeviceProtocolValue])
    case array([DeviceProtocolValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([DeviceProtocolValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: DeviceProtocolValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value) where value.rounded() == value:
            return Int(value)
        case .string(let value):
            return Int(value)
        case .bool(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .int(let value):
            return value == 1 ? true : value == 0 ? false : nil
        case .string(let value):
            if value == "1" {
                return true
            }
            if value == "0" {
                return false
            }
            return nil
        default:
            return nil
        }
    }
}

extension DeviceProtocolValue: ExpressibleByStringLiteral,
    ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral,
    ExpressibleByDictionaryLiteral,
    ExpressibleByArrayLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }

    init(integerLiteral value: Int) {
        self = .int(value)
    }

    init(floatLiteral value: Double) {
        self = .double(value)
    }

    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }

    init(dictionaryLiteral elements: (String, DeviceProtocolValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }

    init(arrayLiteral elements: DeviceProtocolValue...) {
        self = .array(elements)
    }
}
