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

    static func deleteFile(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_DELETE",
            operation: .post,
            parameters: ["path": .string(path)]
        )
    }

    static func setFileLocked(path: String, locked: Bool = true) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_LOCK",
            operation: .post,
            parameters: [
                "file": .string(path),
                "status": .int(locked ? 1 : 0)
            ]
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

    static let recordingState = DeviceProtocolCommand(topic: "VIDEO_CTRL", operation: .get)

    static let accessPointIdentity = DeviceProtocolCommand(topic: "AP_SSID_INFO", operation: .get)

    static func updateAccessPointIdentity(ssid: String, password: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "AP_SSID_INFO",
            operation: .post,
            parameters: [
                "ssid": .string(ssid),
                "pwd": .string(password),
                "status": .int(1)
            ]
        )
    }

    static func setRecording(enabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_CTRL",
            operation: .post,
            parameters: ["status": .int(enabled ? 1 : 0)]
        )
    }

    static func snapshotControl(mode: DeviceSnapshotMode = .preview) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SNAPSHOT_CTRL",
            operation: .post,
            parameters: ["mode": .string(mode.rawValue)]
        )
    }

    static func snapshotData(snapshotID: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SNAPSHOT_DATA",
            operation: .get,
            parameters: ["snapshot_id": .string(snapshotID)]
        )
    }

    static let formatStorage = DeviceProtocolCommand(topic: "FORMAT", operation: .post)

    static let restoreDefaultConfiguration = DeviceProtocolCommand(
        topic: "SYSTEM_DEFAULT",
        operation: .post,
        parameters: ["def": .int(1)]
    )
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
