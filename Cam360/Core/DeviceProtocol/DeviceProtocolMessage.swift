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

        let decodedTopic = try container.decode(String.self, forKey: .topic)
        guard Self.isNonEmptyProtocolHeader(decodedTopic) else {
            throw DecodingError.dataCorruptedError(
                forKey: .topic,
                in: container,
                debugDescription: "topic must not be blank"
            )
        }
        topic = decodedTopic

        operation = try container.decode(DeviceProtocolOperation.self, forKey: .operation)

        let decodedMessageID = try container.decode(String.self, forKey: .messageID)
        guard Self.isNonEmptyProtocolHeader(decodedMessageID) else {
            throw DecodingError.dataCorruptedError(
                forKey: .messageID,
                in: container,
                debugDescription: "msg_id must not be blank"
            )
        }
        messageID = decodedMessageID

        notifyType = try container.decodeIfPresent(DeviceProtocolNotifyType.self, forKey: .notifyType)
        if operation == .notify, notifyType == nil {
            throw DecodingError.dataCorruptedError(
                forKey: .notifyType,
                in: container,
                debugDescription: "notify_type is required for NOTIFY messages"
            )
        }

        let decodedReplyTo = try container.decodeIfPresent(String.self, forKey: .replyTo)
        if notifyType == .response,
           Self.isNonEmptyProtocolHeader(decodedReplyTo) == false {
            throw DecodingError.dataCorruptedError(
                forKey: .replyTo,
                in: container,
                debugDescription: "reply_to must not be blank for response messages"
            )
        }
        replyTo = decodedReplyTo

        parameters = try container.decode([String: DeviceProtocolValue].self, forKey: .parameters)

        let decodedErrno: Int?
        if (try? container.decodeIfPresent(Bool.self, forKey: .errno)) != nil {
            throw DecodingError.dataCorruptedError(
                forKey: .errno,
                in: container,
                debugDescription: "errno must not be boolean"
            )
        } else if let errno = try? container.decodeIfPresent(Int.self, forKey: .errno) {
            decodedErrno = errno
        } else if let errnoText = try? container.decodeIfPresent(String.self, forKey: .errno) {
            decodedErrno = Int(errnoText)
        } else {
            decodedErrno = nil
        }

        if (notifyType == .response || notifyType == .event), decodedErrno == nil {
            throw DecodingError.dataCorruptedError(
                forKey: .errno,
                in: container,
                debugDescription: "errno is required for device messages"
            )
        }

        errno = decodedErrno
    }

    private static func isNonEmptyProtocolHeader(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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
