import Foundation

struct DeviceProtocolCommand: Equatable {
    let topic: String
    let operation: DeviceProtocolOperation
    let parameters: [String: DeviceProtocolValue]
    let timeout: TimeInterval

    init(
        topic: String,
        operation: DeviceProtocolOperation,
        parameters: [String: DeviceProtocolValue] = [:],
        timeout: TimeInterval = 10
    ) {
        self.topic = topic
        self.operation = operation
        self.parameters = parameters
        self.timeout = timeout
    }

    func message(messageID: String) -> DeviceProtocolMessage {
        DeviceProtocolMessage(
            topic: topic,
            operation: operation,
            messageID: messageID,
            parameters: parameters
        )
    }
}

extension DeviceProtocolCommand {
    static func appAccess(appVersion: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "APP_ACCESS",
            operation: .post,
            parameters: [
                "type": 1,
                "ver": .string(appVersion)
            ]
        )
    }

    static let protocolVersion = DeviceProtocolCommand(topic: "PROTOCOL_VERSION", operation: .get)
    static func openApp(page: String = "home") -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "CTP_CMD_OPENAPP", operation: .post, parameters: ["page": .string(page)])
    }

    static let uuid = DeviceProtocolCommand(topic: "UUID", operation: .get)
    static let firmwareVersion = DeviceProtocolCommand(topic: "FW_VERSION", operation: .get)
    static let sdStatus = DeviceProtocolCommand(topic: "SD_STATUS", operation: .get)
    static let batteryStatus = DeviceProtocolCommand(topic: "BAT_STATUS", operation: .get)
    static let tfCapacity = DeviceProtocolCommand(topic: "TF_CAP", operation: .get)
    static let cameraCapability = DeviceProtocolCommand(topic: "CAMERA_CAPABILITY", operation: .get)

    static func exitApp(page: String = "home") -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "CTP_CMD_EXITAPP", operation: .post, parameters: ["page": .string(page)])
    }
}

struct DeviceProtocolHandshakePlan {
    let appVersion: String

    var commands: [DeviceProtocolCommand] {
        [
            .appAccess(appVersion: appVersion),
            .protocolVersion,
            .openApp(),
            .uuid,
            .firmwareVersion,
            .sdStatus,
            .batteryStatus,
            .tfCapacity,
            .cameraCapability
        ]
    }
}
