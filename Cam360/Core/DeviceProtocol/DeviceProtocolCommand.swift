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

    func withTimeout(_ timeout: TimeInterval) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: topic,
            operation: operation,
            parameters: parameters,
            timeout: timeout
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

    static func fileList(query: DeviceFileListQuery) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_LIST",
            operation: .get,
            parameters: [
                "type": .string(query.type.rawValue),
                "page": .int(query.page),
                "page_size": .int(query.pageSize),
                "sort_by": .string(query.sortBy),
                "sort_order": .string(query.sortOrder)
            ]
        )
    }

    static func fileInfo(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_INFO",
            operation: .get,
            parameters: ["path": .string(path)]
        )
    }

    static func filePlaybackResource(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_DOWNLOAD_URL",
            operation: .get,
            parameters: ["path": .string(path)]
        )
    }

    static func thumbnailList(paths: [String]) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "THUMB_LIST",
            operation: .get,
            parameters: ["paths": .array(paths.map { .string($0) })]
        )
    }

    static func thumbnail(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "THUMB_GET",
            operation: .get,
            parameters: ["path": .string(path)]
        )
    }
}

struct DeviceProtocolHandshakePlan {
    let appVersion: String
    let commandTimeout: TimeInterval

    init(appVersion: String, commandTimeout: TimeInterval = 10) {
        self.appVersion = appVersion
        self.commandTimeout = commandTimeout
    }

    var commands: [DeviceProtocolCommand] {
        let baseCommands: [DeviceProtocolCommand] = [
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

        return baseCommands.map { $0.withTimeout(commandTimeout) }
    }
}
