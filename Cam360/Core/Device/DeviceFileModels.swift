import Foundation

enum DeviceSessionReadOnlyError: Error, Equatable {
    case sessionNotReady
    case protocolClientUnavailable
    case staleSession
    case invalidResponse(String)
    case protocolFailure(DeviceProtocolError)

    var message: String {
        switch self {
        case .sessionNotReady:
            return "设备会话未就绪"
        case .protocolClientUnavailable:
            return "控制通道未配置"
        case .staleSession:
            return "设备会话已变更"
        case .invalidResponse(let reason):
            return "设备响应无效: \(reason)"
        case .protocolFailure(let error):
            return DeviceProtocolFailureReason.message(for: error)
        }
    }
}

enum DeviceSessionCommandError: Error, Equatable {
    case sessionNotReady
    case protocolClientUnavailable
    case staleSession
    case invalidResponse(String)
    case protocolFailure(DeviceProtocolError)

    var message: String {
        switch self {
        case .sessionNotReady:
            return "设备会话未就绪"
        case .protocolClientUnavailable:
            return "控制通道未配置"
        case .staleSession:
            return "设备会话已变更"
        case .invalidResponse(let reason):
            return "设备响应无效: \(reason)"
        case .protocolFailure(let error):
            return DeviceProtocolFailureReason.message(for: error)
        }
    }
}

enum DeviceFileType: String, Equatable {
    case video
    case photo
}

struct DeviceFileListQuery: Equatable {
    let type: DeviceFileType
    let page: Int
    let pageSize: Int
    let sortBy: String
    let sortOrder: String

    init(
        type: DeviceFileType = .video,
        page: Int = 1,
        pageSize: Int = 20,
        sortBy: String = "time",
        sortOrder: String = "desc"
    ) {
        self.type = type
        self.page = max(page, 1)
        self.pageSize = min(max(pageSize, 1), 100)
        self.sortBy = Self.normalizedSortBy(sortBy)
        self.sortOrder = Self.normalizedSortOrder(sortOrder)
    }

    private static func normalizedSortBy(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["time", "size"].contains(normalized) ? normalized : "time"
    }

    private static func normalizedSortOrder(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["asc", "desc"].contains(normalized) ? normalized : "desc"
    }
}

struct DeviceFileListPage: Equatable {
    let type: DeviceFileType?
    let total: Int
    let page: Int
    let pageSize: Int
    let files: [DeviceFileItem]
}

struct DeviceFileItem: Equatable {
    let name: String
    let path: String
    let size: Int?
    let duration: Int?
    let resolution: String?
    let createTime: String?
    let hasThumbnail: Bool
    let locked: Bool
    let recordType: String?
}

struct DeviceFileInfo: Equatable {
    let item: DeviceFileItem
    let codec: String?
    let bitrate: Int?
    let framerate: Int?
    let gpsData: String?

    var path: String {
        item.path
    }
}

struct DeviceFilePlaybackResource: Equatable {
    let path: String
    let rtspURL: String
    let transport: String?
    let size: Int?
    let duration: Int?
    let seekable: Bool
    let sessionTimeout: Int?
    let authType: String?
    let username: String?
    let password: String?
    let maxSessions: Int?
    let seekGranularityMilliseconds: Int?
    let keepaliveInterval: Int?
}

struct DeviceFileThumbnail: Equatable {
    let path: String
    let format: String?
    let width: Int?
    let height: Int?
    let size: Int?
    let imageBase64: String?
    let thumbURL: String?
}

enum DeviceSnapshotMode: String, Equatable {
    case preview
}

struct DeviceSnapshotResource: Equatable {
    let snapshotID: String
    let url: String?
    let format: String?
    let width: Int?
    let height: Int?
    let size: Int?
    let createTime: String?
    let imageBase64: String?
}

struct DeviceRecordingState: Equatable {
    let isRecording: Bool
    let path: String?
}

struct DeviceFileDeletionResult: Equatable {
    let path: String
    let deleted: Bool
}

struct DeviceFileLockResult: Equatable {
    let path: String
    let locked: Bool
}

struct DeviceAccessPointIdentity: Equatable {
    let ssid: String
    let password: String?
    let isEnabled: Bool
}

struct DeviceStorageFormatResult: Equatable {
    let formatted: Bool
}

struct DeviceSystemDefaultResult: Equatable {
    let restored: Bool
}

struct DeviceBasicInfo: Equatable {
    let deviceName: String
    let model: String
    let serialNumber: String
    let uuid: String
    let firmwareVersion: String
    let protocolVersion: String
}

struct DeviceRealtimeGPSData: Equatable {
    let info: String
}

enum DeviceHourType: Int, Equatable {
    case twelveHour = 12
    case twentyFourHour = 24
}

struct DeviceHourTypeSetting: Equatable {
    let type: DeviceHourType
}

struct DeviceVideoSizeSetting: Equatable {
    let supportedResolutions: [String]
    let selectedIndex: Int
}

enum DeviceVideoLoopCycle: Int, Equatable {
    case off = 0
    case oneMinute = 1
    case threeMinutes = 2
    case fiveMinutes = 3
    case tenMinutes = 4
}

struct DeviceVideoLoopSetting: Equatable {
    let cycle: DeviceVideoLoopCycle
}

struct DeviceVideoMicrophoneSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceVideoWideDynamicRangeSetting: Equatable {
    let isEnabled: Bool
}

enum DeviceVideoExposureLevel: Int, Equatable {
    case plusTwo = 0
    case plusFiveThirds = 1
    case plusFourThirds = 2
    case plusOne = 3
    case plusTwoThirds = 4
    case plusOneThird = 5
    case zero = 6
    case minusOneThird = 7
    case minusTwoThirds = 8
    case minusOne = 9
    case minusFourThirds = 10
    case minusFiveThirds = 11
    case minusTwo = 12
}

struct DeviceVideoExposureSetting: Equatable {
    let level: DeviceVideoExposureLevel
}

enum DeviceCollisionSensitivity: Int, Equatable {
    case off = 0
    case low = 1
    case medium = 2
    case high = 3
}

struct DeviceCollisionSensitivitySetting: Equatable {
    let sensitivity: DeviceCollisionSensitivity
}

struct DeviceMotionDetectionSetting: Equatable {
    let isEnabled: Bool
}

enum DeviceParkingMonitorMode: Int, Equatable {
    case off = 0
    case timeLapse = 1
    case normalRecording = 2
}

struct DeviceParkingMonitorModeSetting: Equatable {
    let mode: DeviceParkingMonitorMode
}

enum DeviceParkingMonitorDuration: Int, Equatable {
    case unlimited = 0
    case sixHours = 6
    case twelveHours = 12
    case twentyFourHours = 24
    case fortyEightHours = 48
    case ninetySixHours = 96
}

struct DeviceParkingMonitorDurationSetting: Equatable {
    let duration: DeviceParkingMonitorDuration
}

enum DeviceVoltageProtectionThreshold: Int, Equatable {
    case elevenPointEightVolts = 0
    case twelveVolts = 1
    case twelvePointTwoVolts = 2
    case twelvePointFiveVolts = 3
}

struct DeviceVoltageProtectionSetting: Equatable {
    let threshold: DeviceVoltageProtectionThreshold
}

struct DeviceVideoDateWatermarkSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceHorizontalMirrorSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceVerticalFlipSetting: Equatable {
    let isEnabled: Bool
}

enum DeviceAutoShutdownDelay: Int, Equatable {
    case off = 0
    case threeMinutes = 1
    case fiveMinutes = 2
    case tenMinutes = 3
}

struct DeviceAutoShutdownSetting: Equatable {
    let delay: DeviceAutoShutdownDelay
}

enum DeviceScreenProtectionDelay: Int, Equatable {
    case off = 0
    case thirtySeconds = 1
    case oneMinute = 2
    case twoMinutes = 3
}

struct DeviceScreenProtectionSetting: Equatable {
    let delay: DeviceScreenProtectionDelay
}

enum DeviceVideoEncodingFormat: Int, Equatable {
    case jpeg = 0
    case h264 = 1
}

struct DeviceVideoParameterSetting: Equatable {
    let width: Int
    let height: Int
    let encodingFormat: DeviceVideoEncodingFormat
}

struct DevicePhotoResolutionSetting: Equatable {
    let resolution: String
}

enum DevicePhotoQuality: String, Equatable {
    case low
    case middle
    case high
}

struct DevicePhotoQualitySetting: Equatable {
    let quality: DevicePhotoQuality
}

struct DevicePhotoDateWatermarkSetting: Equatable {
    let isEnabled: Bool
}

enum DeviceTVMode: String, Equatable {
    case pal = "PAL"
    case ntsc = "NTSC"
}

struct DeviceTVModeSetting: Equatable {
    let mode: DeviceTVMode
}

struct DeviceParkingGuardSetting: Equatable {
    let isEnabled: Bool
}

enum DeviceParkingCollisionSensitivity: Int, Equatable {
    case low = 0
    case medium = 1
    case high = 2
}

struct DeviceParkingCollisionSensitivitySetting: Equatable {
    let sensitivity: DeviceParkingCollisionSensitivity
}

struct DeviceIntervalRecordingSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceGPSTimeSyncSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceDrivingRestReminderSetting: Equatable {
    let isEnabled: Bool
}

enum DeviceLightFrequency: String, Equatable {
    case hz50 = "50Hz"
    case hz60 = "60Hz"
}

struct DeviceLightFrequencySetting: Equatable {
    let frequency: DeviceLightFrequency
}

struct DeviceSpeakerVolumeSetting: Equatable {
    let volume: Int
}

struct DeviceSpeechSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceKeyVoiceSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceAntiTremorSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceElectronicDogVoiceSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceInfraredLightSetting: Equatable {
    let isEnabled: Bool
}

struct DeviceDateTimeSyncResult: Equatable {
    let date: String
    let timeZoneOffsetMinutes: Int
}

private let firmwareUpgradeChecksumPrefix = "sha256:"
private let firmwareUpgradeChecksumHexScalars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

private func isValidFirmwareUpgradeChecksum(_ checksum: String) -> Bool {
    guard checksum.hasPrefix(firmwareUpgradeChecksumPrefix) else {
        return false
    }
    let digest = checksum.dropFirst(firmwareUpgradeChecksumPrefix.count)
    return digest.count == 64 && digest.unicodeScalars.allSatisfy {
        firmwareUpgradeChecksumHexScalars.contains($0)
    }
}

private func isValidFirmwareUpgradeSignature(_ signature: String) -> Bool {
    guard let decodedSignature = Data(base64Encoded: signature) else {
        return false
    }
    return decodedSignature.isEmpty == false
}

private func isValidFirmwareUpgradeSignatureAlgorithm(_ signatureAlgorithm: String) -> Bool {
    signatureAlgorithm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
}

private func isValidFirmwareUpgradeVersion(_ version: String) -> Bool {
    version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
}

private func isValidFirmwareUpgradePackageURL(_ packageURL: String) -> Bool {
    guard
        let components = URLComponents(string: packageURL),
        let scheme = components.scheme?.lowercased(),
        (scheme == "http" || scheme == "https"),
        let host = components.host,
        host.isEmpty == false
    else {
        return false
    }
    return true
}

struct DeviceFirmwareUpgradeCandidate: Equatable {
    let latestVersion: String
    let packageSize: Int
    let checksum: String
    let rollbackIndex: Int
    let signatureAlgorithm: String
    let signature: String
    let releaseNotes: [String]

    init?(
        latestVersion: String,
        packageSize: Int,
        checksum: String,
        rollbackIndex: Int,
        signatureAlgorithm: String,
        signature: String,
        releaseNotes: [String]
    ) {
        guard
            isValidFirmwareUpgradeVersion(latestVersion),
            packageSize > 0,
            rollbackIndex > 0,
            isValidFirmwareUpgradeChecksum(checksum),
            isValidFirmwareUpgradeSignatureAlgorithm(signatureAlgorithm),
            isValidFirmwareUpgradeSignature(signature)
        else {
            return nil
        }
        self.latestVersion = latestVersion
        self.packageSize = packageSize
        self.checksum = checksum
        self.rollbackIndex = rollbackIndex
        self.signatureAlgorithm = signatureAlgorithm
        self.signature = signature
        self.releaseNotes = releaseNotes
    }
}

struct DeviceFirmwareUpgradePackage: Equatable {
    let targetVersion: String
    let packageURL: String
    let packageSize: Int
    let checksum: String
    let rollbackIndex: Int
    let signatureAlgorithm: String
    let signature: String

    init?(
        targetVersion: String,
        packageURL: String,
        packageSize: Int,
        checksum: String,
        rollbackIndex: Int,
        signatureAlgorithm: String,
        signature: String
    ) {
        guard
            isValidFirmwareUpgradeVersion(targetVersion),
            packageSize > 0,
            rollbackIndex > 0,
            isValidFirmwareUpgradePackageURL(packageURL),
            isValidFirmwareUpgradeChecksum(checksum),
            isValidFirmwareUpgradeSignatureAlgorithm(signatureAlgorithm),
            isValidFirmwareUpgradeSignature(signature)
        else {
            return nil
        }
        self.targetVersion = targetVersion
        self.packageURL = packageURL
        self.packageSize = packageSize
        self.checksum = checksum
        self.rollbackIndex = rollbackIndex
        self.signatureAlgorithm = signatureAlgorithm
        self.signature = signature
    }
}

struct DeviceFirmwareUpgradeCheckResult: Equatable {
    let currentVersion: String
    let latestVersion: String
    let hasUpdate: Bool
    let upgradeAllowed: Bool
    let reason: String?
    let releaseNotes: [String]
}

struct DeviceFirmwareUpgradeStartResult: Equatable {
    let taskID: String
    let accepted: Bool
    let status: String
    let targetVersion: String
}

enum DeviceFileResponseParser {
    private static let thumbnailMaxBytes = 64 * 1024
    private static let thumbnailListMaxBytes = 512 * 1024
    private static let snapshotMaxBytes = 512 * 1024
    private static let documentedFileItemTypes: Set<String> = [
        "normal",
        "impact",
        "motion",
        "manual",
        "parking",
        "emergency",
        "photo"
    ]

    static func fileListPage(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileListPage {
        guard let fileValues = parameters["files"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.files 缺失")
        }

        let files = try fileValues.map { value -> DeviceFileItem in
            guard let object = value.objectValue else {
                throw DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.files 包含非对象")
            }
            return try fileItem(from: object)
        }

        return DeviceFileListPage(
            type: try fileListPageType(from: parameters),
            total: parameters.int("total") ?? files.count,
            page: parameters.int("page") ?? 1,
            pageSize: parameters.int("page_size") ?? files.count,
            files: files
        )
    }

    private static func fileListPageType(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceFileType? {
        guard let value = parameters["type"] else {
            return nil
        }
        guard let rawType = value.stringValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.type 无效")
        }
        let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let documentedType = DeviceFileType(rawValue: type) else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.type 无效")
        }
        return documentedType
    }

    static func fileInfo(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileInfo {
        DeviceFileInfo(
            item: try fileItem(from: parameters),
            codec: parameters.string("codec"),
            bitrate: try optionalNonNegativeFileInfoInteger("bitrate", from: parameters),
            framerate: try optionalNonNegativeFileInfoInteger("framerate", from: parameters),
            gpsData: parameters.string("gps_data")
        )
    }

    private static func optionalNonNegativeFileInfoInteger(
        _ key: String,
        from parameters: [String: DeviceProtocolValue]
    ) throws -> Int? {
        guard let value = parameters[key] else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_INFO.\(key) 无效")
        }
        guard let intValue = value.intValue, intValue >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_INFO.\(key) 无效")
        }
        return intValue
    }

    static func playbackResource(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFilePlaybackResource {
        guard let path = nonBlankString(parameters.string("path")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.path 缺失")
        }

        guard let rtspURL = nonBlankString(parameters.string("rtsp_url") ?? parameters.string("url")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.rtsp_url 缺失")
        }
        guard isValidPlaybackRTSPURL(rtspURL) else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.rtsp_url 无效")
        }

        return DeviceFilePlaybackResource(
            path: path,
            rtspURL: rtspURL,
            transport: try validatedPlaybackTransport(from: parameters),
            size: try validatedPositivePlaybackInt("size", from: parameters),
            duration: try validatedPositivePlaybackInt("duration", from: parameters),
            seekable: parameters.bool("seekable") ?? false,
            sessionTimeout: try validatedPositivePlaybackInt("session_timeout", from: parameters),
            authType: try validatedPlaybackAuthType(from: parameters),
            username: parameters.string("username"),
            password: parameters.string("password"),
            maxSessions: try validatedPositivePlaybackInt("max_sessions", from: parameters),
            seekGranularityMilliseconds: try validatedPositivePlaybackInt("seek_granularity_ms", from: parameters),
            keepaliveInterval: try validatedPositivePlaybackInt("keepalive_interval", from: parameters)
        )
    }

    private static func isValidPlaybackRTSPURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "rtsp",
              let host = components.host,
              host.isEmpty == false else {
            return false
        }
        return true
    }

    private static func validatedPlaybackTransport(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> String? {
        guard let rawValue = parameters.string("transport") else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value == "TCP" else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.transport 无效")
        }
        return value
    }

    private static func validatedPlaybackAuthType(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> String? {
        guard let rawValue = parameters.string("auth_type") else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["none", "basic", "digest"].contains(value) else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.auth_type 无效")
        }
        return value
    }

    private static func validatedPositivePlaybackInt(
        _ key: String,
        from parameters: [String: DeviceProtocolValue]
    ) throws -> Int? {
        guard let value = parameters[key] else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.\(key) 无效")
        }
        guard let intValue = value.intValue, intValue > 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.\(key) 无效")
        }
        return intValue
    }

    static func thumbnails(from parameters: [String: DeviceProtocolValue]) throws -> [DeviceFileThumbnail] {
        guard let thumbnailValues = parameters["thumbs"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 缺失")
        }

        var totalImageByteCount = 0
        let thumbnails = try thumbnailValues.map { value -> DeviceFileThumbnail in
            guard let object = value.objectValue else {
                throw DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 包含非对象")
            }
            let parsed = try parsedThumbnail(from: object, topic: "THUMB_LIST")
            totalImageByteCount += parsed.imageByteCount
            return parsed.thumbnail
        }
        guard totalImageByteCount <= thumbnailListMaxBytes else {
            throw DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 总大小无效")
        }
        return thumbnails
    }

    static func thumbnail(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileThumbnail {
        try parsedThumbnail(from: parameters, topic: "THUMB_GET").thumbnail
    }

    private static func parsedThumbnail(
        from parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> (thumbnail: DeviceFileThumbnail, imageByteCount: Int) {
        guard let path = nonBlankString(parameters.string("path")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).path 缺失")
        }
        let format = try validatedMediaFormat(
            "format",
            from: parameters,
            topic: topic,
            allowedValues: ["JPEG"],
            invalid: { DeviceSessionReadOnlyError.invalidResponse($0) }
        )
        let width = try validatedPositiveMediaInt(
            "width",
            from: parameters,
            topic: topic,
            maxValue: nil,
            invalid: { DeviceSessionReadOnlyError.invalidResponse($0) }
        )
        let height = try validatedPositiveMediaInt(
            "height",
            from: parameters,
            topic: topic,
            maxValue: nil,
            invalid: { DeviceSessionReadOnlyError.invalidResponse($0) }
        )
        let size = try validatedPositiveMediaInt(
            "size",
            from: parameters,
            topic: topic,
            maxValue: thumbnailMaxBytes,
            invalid: { DeviceSessionReadOnlyError.invalidResponse($0) }
        )
        let image = try validatedBase64Media(
            "image_base64",
            from: parameters,
            topic: topic,
            maxBytes: thumbnailMaxBytes,
            invalid: { DeviceSessionReadOnlyError.invalidResponse($0) }
        )

        return (
            DeviceFileThumbnail(
                path: path,
                format: format,
                width: width,
                height: height,
                size: size,
                imageBase64: image.value,
                thumbURL: parameters.string("thumb_url")
            ),
            image.byteCount
        )
    }

    static func snapshotResource(from parameters: [String: DeviceProtocolValue]) throws -> DeviceSnapshotResource {
        guard let snapshotID = nonBlankString(parameters.string("snapshot_id")) else {
            throw DeviceSessionCommandError.invalidResponse("SNAPSHOT_DATA.snapshot_id 缺失")
        }
        let format = try validatedMediaFormat(
            "format",
            from: parameters,
            topic: "SNAPSHOT_DATA",
            allowedValues: ["JPEG", "PNG"],
            invalid: { DeviceSessionCommandError.invalidResponse($0) }
        )
        let width = try validatedPositiveMediaInt(
            "width",
            from: parameters,
            topic: "SNAPSHOT_DATA",
            maxValue: nil,
            invalid: { DeviceSessionCommandError.invalidResponse($0) }
        )
        let height = try validatedPositiveMediaInt(
            "height",
            from: parameters,
            topic: "SNAPSHOT_DATA",
            maxValue: nil,
            invalid: { DeviceSessionCommandError.invalidResponse($0) }
        )
        let size = try validatedPositiveMediaInt(
            "size",
            from: parameters,
            topic: "SNAPSHOT_DATA",
            maxValue: snapshotMaxBytes,
            invalid: { DeviceSessionCommandError.invalidResponse($0) }
        )
        let image = try validatedBase64Media(
            "image_base64",
            from: parameters,
            topic: "SNAPSHOT_DATA",
            maxBytes: snapshotMaxBytes,
            invalid: { DeviceSessionCommandError.invalidResponse($0) }
        )

        return DeviceSnapshotResource(
            snapshotID: snapshotID,
            url: parameters.string("url"),
            format: format,
            width: width,
            height: height,
            size: size,
            createTime: parameters.string("create_time"),
            imageBase64: image.value
        )
    }

    static func snapshotID(from parameters: [String: DeviceProtocolValue]) throws -> String {
        guard let snapshotID = nonBlankString(parameters.string("snapshot_id")) else {
            throw DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.snapshot_id 缺失")
        }
        if let rawStatus = parameters.string("status") {
            let status = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard ["ok", "failed"].contains(status) else {
                throw DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.status 无效")
            }
        }
        return snapshotID
    }

    private static func nonBlankString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func validatedMediaFormat(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String,
        allowedValues: Set<String>,
        invalid: (String) -> Error
    ) throws -> String {
        guard let value = nonBlankString(parameters.string(key))?.uppercased(),
              allowedValues.contains(value) else {
            throw invalid("\(topic).\(key) 无效")
        }
        return value
    }

    private static func validatedPositiveMediaInt(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String,
        maxValue: Int?,
        invalid: (String) -> Error
    ) throws -> Int {
        guard let value = parameters[key] else {
            throw invalid("\(topic).\(key) 无效")
        }
        if case .bool = value {
            throw invalid("\(topic).\(key) 无效")
        }
        guard let intValue = value.intValue, intValue > 0 else {
            throw invalid("\(topic).\(key) 无效")
        }
        if let maxValue, intValue > maxValue {
            throw invalid("\(topic).\(key) 无效")
        }
        return intValue
    }

    private static func validatedBase64Media(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String,
        maxBytes: Int,
        invalid: (String) -> Error
    ) throws -> (value: String, byteCount: Int) {
        guard let value = nonBlankString(parameters.string(key)),
              let data = Data(base64Encoded: value),
              data.isEmpty == false,
              data.count <= maxBytes else {
            throw invalid("\(topic).\(key) 无效")
        }
        return (value, data.count)
    }

    static func recordingState(from parameters: [String: DeviceProtocolValue]) throws -> DeviceRecordingState {
        let isRecording = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "VIDEO_CTRL"
        )

        let path = parameters.string("path") ?? parameters.string("dir")
        return DeviceRecordingState(
            isRecording: isRecording,
            path: path?.isEmpty == true ? nil : path
        )
    }

    static func sdCardStatus(from parameters: [String: DeviceProtocolValue]) throws -> Int {
        if case .bool? = parameters["online"] {
            throw DeviceSessionReadOnlyError.invalidResponse("SD_STATUS.online 缺失")
        }

        guard let online = parameters.int("online"), online >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("SD_STATUS.online 缺失")
        }

        return online
    }

    static func batteryStatus(from parameters: [String: DeviceProtocolValue]) throws -> Int {
        if case .bool? = parameters["level"] {
            throw DeviceSessionReadOnlyError.invalidResponse("BAT_STATUS.level 缺失")
        }

        guard let level = parameters.int("level"), (0...4).contains(level) else {
            throw DeviceSessionReadOnlyError.invalidResponse("BAT_STATUS.level 缺失")
        }
        return level
    }

    static func storageCapacity(from parameters: [String: DeviceProtocolValue]) throws -> DeviceStorageCapacity {
        if case .bool? = parameters["left"] {
            throw DeviceSessionReadOnlyError.invalidResponse("TF_CAP.left 缺失")
        }
        if case .bool? = parameters["total"] {
            throw DeviceSessionReadOnlyError.invalidResponse("TF_CAP.total 缺失")
        }

        guard let remainingMegabytes = parameters.int("left"), remainingMegabytes >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("TF_CAP.left 缺失")
        }
        guard let totalMegabytes = parameters.int("total"), totalMegabytes >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("TF_CAP.total 缺失")
        }
        guard remainingMegabytes <= totalMegabytes else {
            throw DeviceSessionReadOnlyError.invalidResponse("TF_CAP.left 无效")
        }

        return DeviceStorageCapacity(
            remainingMegabytes: remainingMegabytes,
            totalMegabytes: totalMegabytes
        )
    }

    static func fileDeletionResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileDeletionResult {
        guard let path = nonBlankString(parameters.string("path")) else {
            throw DeviceSessionCommandError.invalidResponse("FILE_DELETE.path 缺失")
        }

        let deleted = try documentedCommandFlag(
            "deleted",
            from: parameters,
            topic: "FILE_DELETE"
        )

        return DeviceFileDeletionResult(path: path, deleted: deleted)
    }

    static func fileLockResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileLockResult {
        guard let path = nonBlankString(parameters.string("file")) ?? nonBlankString(parameters.string("path")) else {
            throw DeviceSessionCommandError.invalidResponse("FILE_LOCK.file 缺失")
        }

        let locked = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "FILE_LOCK"
        )

        return DeviceFileLockResult(path: path, locked: locked)
    }

    static func accessPointIdentity(from parameters: [String: DeviceProtocolValue]) throws -> DeviceAccessPointIdentity {
        guard let ssid = parameters.string("ssid") else {
            throw DeviceSessionCommandError.invalidResponse("AP_SSID_INFO.ssid 缺失")
        }

        return DeviceAccessPointIdentity(
            ssid: ssid,
            password: parameters.string("pwd"),
            isEnabled: try optionalDocumentedCommandFlag(
                "status",
                from: parameters,
                topic: "AP_SSID_INFO",
                defaultValue: true
            )
        )
    }

    static func storageFormatResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceStorageFormatResult {
        let formatted = try documentedCommandFlag(
            "frm",
            from: parameters,
            topic: "FORMAT"
        )

        return DeviceStorageFormatResult(formatted: formatted)
    }

    static func systemDefaultResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceSystemDefaultResult {
        let restored = try documentedCommandFlag(
            "def",
            from: parameters,
            topic: "SYSTEM_DEFAULT"
        )

        return DeviceSystemDefaultResult(restored: restored)
    }

    private static func documentedCommandFlag(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> Bool {
        guard let value = parameters[key] else {
            throw DeviceSessionCommandError.invalidResponse("\(topic).\(key) 缺失")
        }
        if case .bool = value {
            throw DeviceSessionCommandError.invalidResponse("\(topic).\(key) 无效")
        }
        guard let intValue = value.intValue, intValue == 0 || intValue == 1 else {
            throw DeviceSessionCommandError.invalidResponse("\(topic).\(key) 无效")
        }
        return intValue == 1
    }

    private static func optionalDocumentedCommandFlag(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String,
        defaultValue: Bool
    ) throws -> Bool {
        guard parameters[key] != nil else {
            return defaultValue
        }
        return try documentedCommandFlag(key, from: parameters, topic: topic)
    }

    static func deviceBasicInfo(from parameters: [String: DeviceProtocolValue]) throws -> DeviceBasicInfo {
        let deviceName = try requiredNonBlankReadOnlyString(
            "device_name",
            from: parameters,
            topic: "DEVICE_INFO"
        )
        let model = try requiredNonBlankReadOnlyString(
            "model",
            from: parameters,
            topic: "DEVICE_INFO"
        )
        let serialNumber = try requiredNonBlankReadOnlyString(
            "serial_no",
            from: parameters,
            topic: "DEVICE_INFO"
        )
        let uuid = try requiredNonBlankReadOnlyString(
            "uuid",
            from: parameters,
            topic: "DEVICE_INFO"
        )
        let firmwareVersion = try requiredNonBlankReadOnlyString(
            "fw_version",
            from: parameters,
            topic: "DEVICE_INFO"
        )
        let protocolVersion = try requiredNonBlankReadOnlyString(
            "protocol_version",
            from: parameters,
            topic: "DEVICE_INFO"
        )

        return DeviceBasicInfo(
            deviceName: deviceName,
            model: model,
            serialNumber: serialNumber,
            uuid: uuid,
            firmwareVersion: firmwareVersion,
            protocolVersion: protocolVersion
        )
    }

    static func realtimeGPSData(from parameters: [String: DeviceProtocolValue]) throws -> DeviceRealtimeGPSData {
        let info = try requiredNonBlankReadOnlyString(
            "info",
            from: parameters,
            topic: "VI_GPS_RTDATA"
        )

        return DeviceRealtimeGPSData(info: info)
    }

    private static func requiredNonBlankReadOnlyString(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> String {
        guard let value = nonBlankString(parameters.string(key)) else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 缺失")
        }

        return value
    }

    static func hourTypeSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceHourTypeSetting {
        if case .bool? = parameters["type"] {
            throw DeviceSessionCommandError.invalidResponse("HOUR_TYPE.type 缺失")
        }
        guard let rawType = parameters.int("type") else {
            throw DeviceSessionCommandError.invalidResponse("HOUR_TYPE.type 缺失")
        }
        guard let type = DeviceHourType(rawValue: rawType) else {
            throw DeviceSessionCommandError.invalidResponse("HOUR_TYPE.type 无效")
        }

        return DeviceHourTypeSetting(type: type)
    }

    static func videoSizeSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceVideoSizeSetting {
        guard let resolutionText = parameters.string("str") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_SIZE.str 缺失")
        }
        if case .bool? = parameters["val"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_SIZE.val 缺失")
        }
        let supportedResolutions = resolutionText.split(separator: ";").map(String.init)
        guard let selectedIndex = parameters.int("val") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_SIZE.val 缺失")
        }
        guard supportedResolutions.indices.contains(selectedIndex) else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_SIZE.val 无效")
        }

        return DeviceVideoSizeSetting(
            supportedResolutions: supportedResolutions,
            selectedIndex: selectedIndex
        )
    }

    static func videoLoopSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceVideoLoopSetting {
        if case .bool? = parameters["cyc"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_LOOP.cyc 缺失")
        }
        guard let rawCycle = parameters.int("cyc") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_LOOP.cyc 缺失")
        }
        guard let cycle = DeviceVideoLoopCycle(rawValue: rawCycle) else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_LOOP.cyc 无效")
        }

        return DeviceVideoLoopSetting(cycle: cycle)
    }

    static func videoMicrophoneSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceVideoMicrophoneSetting {
        let isEnabled = try documentedCommandFlag(
            "mic",
            from: parameters,
            topic: "VIDEO_MIC"
        )

        return DeviceVideoMicrophoneSetting(isEnabled: isEnabled)
    }

    static func videoWideDynamicRangeSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceVideoWideDynamicRangeSetting {
        let isEnabled = try documentedCommandFlag(
            "wdr",
            from: parameters,
            topic: "VIDEO_WDR"
        )

        return DeviceVideoWideDynamicRangeSetting(isEnabled: isEnabled)
    }

    static func videoExposureSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceVideoExposureSetting {
        if case .bool? = parameters["exp"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_EXP.exp 缺失")
        }
        guard let rawLevel = parameters.int("exp") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_EXP.exp 缺失")
        }
        guard let level = DeviceVideoExposureLevel(rawValue: rawLevel) else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_EXP.exp 无效")
        }

        return DeviceVideoExposureSetting(level: level)
    }

    static func collisionSensitivitySetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceCollisionSensitivitySetting {
        if case .bool? = parameters["gra"] {
            throw DeviceSessionCommandError.invalidResponse("GRA_SEN.gra 缺失")
        }
        guard let rawSensitivity = parameters.int("gra") else {
            throw DeviceSessionCommandError.invalidResponse("GRA_SEN.gra 缺失")
        }
        guard let sensitivity = DeviceCollisionSensitivity(rawValue: rawSensitivity) else {
            throw DeviceSessionCommandError.invalidResponse("GRA_SEN.gra 无效")
        }

        return DeviceCollisionSensitivitySetting(sensitivity: sensitivity)
    }

    static func motionDetectionSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceMotionDetectionSetting {
        let isEnabled = try documentedCommandFlag(
            "mot",
            from: parameters,
            topic: "MOVE_CHECK"
        )

        return DeviceMotionDetectionSetting(isEnabled: isEnabled)
    }

    static func parkingMonitorModeSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceParkingMonitorModeSetting {
        if case .bool? = parameters["mode"] {
            throw DeviceSessionCommandError.invalidResponse("MONITOR_MODE.mode 缺失")
        }
        guard let rawMode = parameters.int("mode") else {
            throw DeviceSessionCommandError.invalidResponse("MONITOR_MODE.mode 缺失")
        }
        guard let mode = DeviceParkingMonitorMode(rawValue: rawMode) else {
            throw DeviceSessionCommandError.invalidResponse("MONITOR_MODE.mode 无效")
        }

        return DeviceParkingMonitorModeSetting(mode: mode)
    }

    static func parkingMonitorDurationSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceParkingMonitorDurationSetting {
        if case .bool? = parameters["gaplen"] {
            throw DeviceSessionCommandError.invalidResponse("MONITOR_TIME.gaplen 缺失")
        }
        guard let rawDuration = parameters.int("gaplen") else {
            throw DeviceSessionCommandError.invalidResponse("MONITOR_TIME.gaplen 缺失")
        }
        guard let duration = DeviceParkingMonitorDuration(rawValue: rawDuration) else {
            throw DeviceSessionCommandError.invalidResponse("MONITOR_TIME.gaplen 无效")
        }

        return DeviceParkingMonitorDurationSetting(duration: duration)
    }

    static func voltageProtectionSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceVoltageProtectionSetting {
        if case .bool? = parameters["vpr"] {
            throw DeviceSessionCommandError.invalidResponse("VOLTAGE_PRO.vpr 缺失")
        }
        guard let rawThreshold = parameters.int("vpr") else {
            throw DeviceSessionCommandError.invalidResponse("VOLTAGE_PRO.vpr 缺失")
        }
        guard let threshold = DeviceVoltageProtectionThreshold(rawValue: rawThreshold) else {
            throw DeviceSessionCommandError.invalidResponse("VOLTAGE_PRO.vpr 无效")
        }

        return DeviceVoltageProtectionSetting(threshold: threshold)
    }

    static func videoDateWatermarkSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceVideoDateWatermarkSetting {
        let isEnabled = try documentedCommandFlag(
            "dat",
            from: parameters,
            topic: "VIDEO_DATE"
        )

        return DeviceVideoDateWatermarkSetting(isEnabled: isEnabled)
    }

    static func horizontalMirrorSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceHorizontalMirrorSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "MIRROR_HOR"
        )

        return DeviceHorizontalMirrorSetting(isEnabled: isEnabled)
    }

    static func verticalFlipSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceVerticalFlipSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "FLIP_VER"
        )

        return DeviceVerticalFlipSetting(isEnabled: isEnabled)
    }

    static func autoShutdownSetting(from parameters: [String: DeviceProtocolValue]) throws -> DeviceAutoShutdownSetting {
        if case .bool? = parameters["aff"] {
            throw DeviceSessionCommandError.invalidResponse("AUTO_SHUTDOWN.aff 缺失")
        }
        guard let rawDelay = parameters.int("aff") else {
            throw DeviceSessionCommandError.invalidResponse("AUTO_SHUTDOWN.aff 缺失")
        }
        guard let delay = DeviceAutoShutdownDelay(rawValue: rawDelay) else {
            throw DeviceSessionCommandError.invalidResponse("AUTO_SHUTDOWN.aff 无效")
        }

        return DeviceAutoShutdownSetting(delay: delay)
    }

    static func screenProtectionSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceScreenProtectionSetting {
        if case .bool? = parameters["pro"] {
            throw DeviceSessionCommandError.invalidResponse("SCREEN_PRO.pro 缺失")
        }
        guard let rawDelay = parameters.int("pro") else {
            throw DeviceSessionCommandError.invalidResponse("SCREEN_PRO.pro 缺失")
        }
        guard let delay = DeviceScreenProtectionDelay(rawValue: rawDelay) else {
            throw DeviceSessionCommandError.invalidResponse("SCREEN_PRO.pro 无效")
        }

        return DeviceScreenProtectionSetting(delay: delay)
    }

    static func videoParameterSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceVideoParameterSetting {
        if case .bool? = parameters["w"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.w 缺失")
        }
        guard let width = parameters.int("w") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.w 缺失")
        }
        if case .bool? = parameters["h"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.h 缺失")
        }
        guard let height = parameters.int("h") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.h 缺失")
        }
        if case .bool? = parameters["format"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.format 缺失")
        }
        guard let rawFormat = parameters.int("format") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.format 缺失")
        }
        guard let encodingFormat = DeviceVideoEncodingFormat(rawValue: rawFormat) else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.format 无效")
        }
        guard isSupportedVideoParameterDimensions(width: width, height: height) else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.w/h 无效")
        }

        return DeviceVideoParameterSetting(
            width: width,
            height: height,
            encodingFormat: encodingFormat
        )
    }

    private static func isSupportedVideoParameterDimensions(width: Int, height: Int) -> Bool {
        switch (width, height) {
        case (3840, 2160), (2560, 1440), (1920, 1080), (1280, 720), (800, 480):
            return true
        default:
            return false
        }
    }

    static func photoResolutionSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DevicePhotoResolutionSetting {
        guard let resolution = nonBlankString(parameters.string("reso")) else {
            throw DeviceSessionCommandError.invalidResponse("PHOTO_RESO.reso 缺失")
        }

        return DevicePhotoResolutionSetting(resolution: resolution)
    }

    static func photoQualitySetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DevicePhotoQualitySetting {
        guard let rawQuality = nonBlankString(parameters.string("quality")) else {
            throw DeviceSessionCommandError.invalidResponse("PHOTO_QUALITY.quality 缺失")
        }
        guard let quality = DevicePhotoQuality(rawValue: rawQuality) else {
            throw DeviceSessionCommandError.invalidResponse("PHOTO_QUALITY.quality 无效")
        }

        return DevicePhotoQualitySetting(quality: quality)
    }

    static func photoDateWatermarkSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DevicePhotoDateWatermarkSetting {
        let isEnabled = try documentedCommandFlag(
            "date",
            from: parameters,
            topic: "PHOTO_DATE"
        )

        return DevicePhotoDateWatermarkSetting(isEnabled: isEnabled)
    }

    static func tvModeSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceTVModeSetting {
        guard let rawMode = nonBlankString(parameters.string("mode")) else {
            throw DeviceSessionCommandError.invalidResponse("TV_MODE.mode 缺失")
        }
        guard let mode = DeviceTVMode(rawValue: rawMode) else {
            throw DeviceSessionCommandError.invalidResponse("TV_MODE.mode 无效")
        }

        return DeviceTVModeSetting(mode: mode)
    }

    static func parkingGuardSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceParkingGuardSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "VIDEO_PAR_CAR"
        )

        return DeviceParkingGuardSetting(isEnabled: isEnabled)
    }

    static func parkingCollisionSensitivitySetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceParkingCollisionSensitivitySetting {
        if case .bool? = parameters["level"] {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PAR_VSIX.level 缺失")
        }
        guard let rawSensitivity = parameters.int("level") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PAR_VSIX.level 缺失")
        }
        guard let sensitivity = DeviceParkingCollisionSensitivity(rawValue: rawSensitivity) else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_PAR_VSIX.level 无效")
        }

        return DeviceParkingCollisionSensitivitySetting(sensitivity: sensitivity)
    }

    static func intervalRecordingSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceIntervalRecordingSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "VIDEO_INV"
        )

        return DeviceIntervalRecordingSetting(isEnabled: isEnabled)
    }

    static func gpsTimeSyncSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceGPSTimeSyncSetting {
        let isEnabled = try documentedCommandFlag(
            "sync",
            from: parameters,
            topic: "VIDEO_SYNC"
        )

        return DeviceGPSTimeSyncSetting(isEnabled: isEnabled)
    }

    static func drivingRestReminderSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceDrivingRestReminderSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "VIDEO_RDER"
        )

        return DeviceDrivingRestReminderSetting(isEnabled: isEnabled)
    }

    static func lightFrequencySetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceLightFrequencySetting {
        guard let rawFrequency = nonBlankString(parameters.string("freq")) else {
            throw DeviceSessionCommandError.invalidResponse("LIGHT_FRE.freq 缺失")
        }
        guard let frequency = DeviceLightFrequency(rawValue: rawFrequency) else {
            throw DeviceSessionCommandError.invalidResponse("LIGHT_FRE.freq 无效")
        }

        return DeviceLightFrequencySetting(frequency: frequency)
    }

    static func speakerVolumeSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceSpeakerVolumeSetting {
        if case .bool? = parameters["volume"] {
            throw DeviceSessionCommandError.invalidResponse("SPEAKER_VOLUME.volume 缺失")
        }

        guard let volume = parameters.int("volume"), (0...10).contains(volume) else {
            throw DeviceSessionCommandError.invalidResponse("SPEAKER_VOLUME.volume 缺失")
        }

        return DeviceSpeakerVolumeSetting(volume: volume)
    }

    static func speechSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceSpeechSetting {
        let isEnabled = try documentedCommandFlag(
            "speech",
            from: parameters,
            topic: "SPEECH"
        )

        return DeviceSpeechSetting(isEnabled: isEnabled)
    }

    static func keyVoiceSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceKeyVoiceSetting {
        let isEnabled = try documentedCommandFlag(
            "voice",
            from: parameters,
            topic: "KEY_VOICE"
        )

        return DeviceKeyVoiceSetting(isEnabled: isEnabled)
    }

    static func antiTremorSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceAntiTremorSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "ANTI_TREMOR"
        )

        return DeviceAntiTremorSetting(isEnabled: isEnabled)
    }

    static func electronicDogVoiceSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceElectronicDogVoiceSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "EDOG_VOICE"
        )

        return DeviceElectronicDogVoiceSetting(isEnabled: isEnabled)
    }

    static func infraredLightSetting(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> DeviceInfraredLightSetting {
        let isEnabled = try documentedCommandFlag(
            "status",
            from: parameters,
            topic: "IR_SWITCH"
        )

        return DeviceInfraredLightSetting(isEnabled: isEnabled)
    }

    static func dateTimeSyncResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceDateTimeSyncResult {
        guard let date = parameters.string("date") else {
            throw DeviceSessionCommandError.invalidResponse("DATE_TIME.date 缺失")
        }
        guard DeviceProtocolCommand.normalizedProtocolTimestamp(date) != nil else {
            throw DeviceSessionCommandError.invalidResponse("DATE_TIME.date 无效")
        }
        if case .bool? = parameters["tz_offset_min"] {
            throw DeviceSessionCommandError.invalidResponse("DATE_TIME.tz_offset_min 缺失")
        }
        guard let timeZoneOffsetMinutes = parameters.int("tz_offset_min") else {
            throw DeviceSessionCommandError.invalidResponse("DATE_TIME.tz_offset_min 缺失")
        }

        return DeviceDateTimeSyncResult(
            date: date,
            timeZoneOffsetMinutes: timeZoneOffsetMinutes
        )
    }

    static func firmwareUpgradeCheckResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFirmwareUpgradeCheckResult {
        guard let currentVersion = nonBlankString(parameters.string("current_version")) else {
            throw DeviceSessionCommandError.invalidResponse("UPGRADE_CHECK.current_version 缺失")
        }
        guard let latestVersion = nonBlankString(parameters.string("latest_version")) else {
            throw DeviceSessionCommandError.invalidResponse("UPGRADE_CHECK.latest_version 缺失")
        }
        let hasUpdate = try documentedUpgradeFlag("has_update", from: parameters, topic: "UPGRADE_CHECK")
        let upgradeAllowed = try documentedUpgradeFlag("upgrade_allowed", from: parameters, topic: "UPGRADE_CHECK")

        return DeviceFirmwareUpgradeCheckResult(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            hasUpdate: hasUpdate,
            upgradeAllowed: upgradeAllowed,
            reason: parameters.string("reason"),
            releaseNotes: stringArray(from: parameters["release_notes"])
        )
    }

    static func firmwareUpgradeStartResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFirmwareUpgradeStartResult {
        guard let taskID = nonBlankString(parameters.string("task_id")) else {
            throw DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.task_id 缺失")
        }
        let accepted = try documentedUpgradeFlag("accepted", from: parameters, topic: "UPGRADE_CTRL")
        guard let rawStatus = parameters.string("status") else {
            throw DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.status 缺失")
        }
        let status = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["queued", "processing", "failed"].contains(status) else {
            throw DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.status 无效")
        }
        guard let targetVersion = nonBlankString(parameters.string("target_version")) else {
            throw DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.target_version 缺失")
        }

        return DeviceFirmwareUpgradeStartResult(
            taskID: taskID,
            accepted: accepted,
            status: status,
            targetVersion: targetVersion
        )
    }

    private static func documentedUpgradeFlag(
        _ key: String,
        from parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> Bool {
        guard let value = parameters[key] else {
            throw DeviceSessionCommandError.invalidResponse("\(topic).\(key) 缺失")
        }
        if case .bool = value {
            throw DeviceSessionCommandError.invalidResponse("\(topic).\(key) 缺失")
        }
        guard let intValue = value.intValue, intValue == 0 || intValue == 1 else {
            throw DeviceSessionCommandError.invalidResponse("\(topic).\(key) 缺失")
        }
        return intValue == 1
    }

    private static func fileItem(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileItem {
        guard let name = parameters.string("name") else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 name 缺失")
        }

        guard let path = nonBlankString(parameters.string("path")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 path 缺失")
        }

        let locked = try fileItemLockedFlag(from: parameters)

        return DeviceFileItem(
            name: name,
            path: path,
            size: try optionalNonNegativeFileItemInteger("size", from: parameters),
            duration: try optionalNonNegativeFileItemInteger("duration", from: parameters),
            resolution: parameters.string("resolution"),
            createTime: parameters.string("create_time"),
            hasThumbnail: parameters.bool("has_thumbnail") ?? false,
            locked: locked,
            recordType: try fileItemRecordType(from: parameters)
        )
    }

    private static func fileItemRecordType(
        from parameters: [String: DeviceProtocolValue]
    ) throws -> String? {
        guard let value = parameters["type"] else {
            return nil
        }
        guard let rawType = value.stringValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 type 无效")
        }
        let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard documentedFileItemTypes.contains(type) else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 type 无效")
        }
        return type
    }

    private static func fileItemLockedFlag(from parameters: [String: DeviceProtocolValue]) throws -> Bool {
        guard let value = parameters["locked"] else {
            return false
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 locked 无效")
        }
        guard let intValue = value.intValue, intValue == 0 || intValue == 1 else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 locked 无效")
        }
        return intValue == 1
    }

    private static func optionalNonNegativeFileItemInteger(
        _ key: String,
        from parameters: [String: DeviceProtocolValue]
    ) throws -> Int? {
        guard let value = parameters[key] else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 \(key) 无效")
        }
        guard let intValue = value.intValue, intValue >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 \(key) 无效")
        }
        return intValue
    }

    private static func stringArray(from value: DeviceProtocolValue?) -> [String] {
        value?.arrayValue?.compactMap(\.stringValue) ?? []
    }
}

extension DeviceProtocolValue {
    nonisolated var objectValue: [String: DeviceProtocolValue]? {
        if case .object(let object) = self {
            return object
        }
        return nil
    }

    nonisolated var arrayValue: [DeviceProtocolValue]? {
        if case .array(let array) = self {
            return array
        }
        return nil
    }
}
