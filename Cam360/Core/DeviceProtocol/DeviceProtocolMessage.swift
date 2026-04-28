import Foundation

enum DeviceProtocolOperation: String, Codable, Equatable {
    case get = "GET"
    case post = "POST"
    case notify = "NOTIFY"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).uppercased()

        guard let operation = DeviceProtocolOperation(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported operation: \(rawValue)"
            )
        }

        self = operation
    }
}

enum DeviceProtocolNotifyType: String, Codable, Equatable {
    case request
    case response
    case event

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()

        switch rawValue {
        case "request", "req":
            self = .request
        case "response", "resp":
            self = .response
        case "event", "evt":
            self = .event
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported notify_type: \(rawValue)"
            )
        }
    }
}

struct DeviceProtocolMessage: Codable, Equatable {
    let topic: String
    let operation: DeviceProtocolOperation
    let messageID: String
    let notifyType: DeviceProtocolNotifyType?
    let replyTo: String?
    let errno: Int?
    let parameters: [String: DeviceProtocolValue]

    init(
        topic: String,
        operation: DeviceProtocolOperation,
        messageID: String,
        notifyType: DeviceProtocolNotifyType? = nil,
        replyTo: String? = nil,
        errno: Int? = nil,
        parameters: [String: DeviceProtocolValue] = [:]
    ) {
        self.topic = topic
        self.operation = operation
        self.messageID = messageID
        self.notifyType = notifyType
        self.replyTo = replyTo
        self.errno = errno
        self.parameters = parameters
    }

    var isResponse: Bool {
        operation == .notify && notifyType == .response && replyTo != nil
    }

    var isEvent: Bool {
        operation == .notify && notifyType == .event
    }

    private enum CodingKeys: String, CodingKey {
        case topic
        case operation = "op"
        case messageID = "msg_id"
        case notifyType = "notify_type"
        case replyTo = "reply_to"
        case errno
        case parameters = "param"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try container.decode(String.self, forKey: .topic)
        operation = try container.decode(DeviceProtocolOperation.self, forKey: .operation)
        messageID = try container.decode(String.self, forKey: .messageID)
        notifyType = try container.decodeIfPresent(DeviceProtocolNotifyType.self, forKey: .notifyType)
        replyTo = try container.decodeIfPresent(String.self, forKey: .replyTo)
        parameters = try container.decodeIfPresent(
            [String: DeviceProtocolValue].self,
            forKey: .parameters
        ) ?? [:]

        if let errno = try? container.decodeIfPresent(Int.self, forKey: .errno) {
            self.errno = errno
        } else if let errnoText = try? container.decodeIfPresent(String.self, forKey: .errno) {
            errno = Int(errnoText)
        } else {
            errno = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topic, forKey: .topic)
        try container.encode(operation, forKey: .operation)
        try container.encode(messageID, forKey: .messageID)
        try container.encodeIfPresent(notifyType, forKey: .notifyType)
        try container.encodeIfPresent(replyTo, forKey: .replyTo)
        try container.encodeIfPresent(errno, forKey: .errno)
        try container.encode(parameters, forKey: .parameters)
    }
}
