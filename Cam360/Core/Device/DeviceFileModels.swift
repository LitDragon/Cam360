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
        self.page = page
        self.pageSize = pageSize
        self.sortBy = sortBy
        self.sortOrder = sortOrder
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

enum DeviceFileResponseParser {
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
            type: parameters.string("type").flatMap(DeviceFileType.init(rawValue:)),
            total: parameters.int("total") ?? files.count,
            page: parameters.int("page") ?? 1,
            pageSize: parameters.int("page_size") ?? files.count,
            files: files
        )
    }

    static func fileInfo(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileInfo {
        DeviceFileInfo(
            item: try fileItem(from: parameters),
            codec: parameters.string("codec"),
            bitrate: parameters.int("bitrate"),
            framerate: parameters.int("framerate"),
            gpsData: parameters.string("gps_data")
        )
    }

    static func playbackResource(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFilePlaybackResource {
        guard let path = parameters.string("path") else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.path 缺失")
        }

        guard let rtspURL = parameters.string("rtsp_url") ?? parameters.string("url") else {
            throw DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.rtsp_url 缺失")
        }

        return DeviceFilePlaybackResource(
            path: path,
            rtspURL: rtspURL,
            transport: parameters.string("transport"),
            size: parameters.int("size"),
            duration: parameters.int("duration"),
            seekable: parameters.bool("seekable") ?? false,
            sessionTimeout: parameters.int("session_timeout")
        )
    }

    static func thumbnails(from parameters: [String: DeviceProtocolValue]) throws -> [DeviceFileThumbnail] {
        guard let thumbnailValues = parameters["thumbs"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 缺失")
        }

        return try thumbnailValues.map { value -> DeviceFileThumbnail in
            guard let object = value.objectValue else {
                throw DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 包含非对象")
            }
            return try thumbnail(from: object)
        }
    }

    static func thumbnail(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileThumbnail {
        guard let path = parameters.string("path") else {
            throw DeviceSessionReadOnlyError.invalidResponse("THUMB_GET.path 缺失")
        }

        return DeviceFileThumbnail(
            path: path,
            format: parameters.string("format"),
            width: parameters.int("width"),
            height: parameters.int("height"),
            size: parameters.int("size"),
            imageBase64: parameters.string("image_base64"),
            thumbURL: parameters.string("thumb_url")
        )
    }

    static func snapshotResource(from parameters: [String: DeviceProtocolValue]) throws -> DeviceSnapshotResource {
        guard let snapshotID = parameters.string("snapshot_id") else {
            throw DeviceSessionCommandError.invalidResponse("SNAPSHOT_DATA.snapshot_id 缺失")
        }

        return DeviceSnapshotResource(
            snapshotID: snapshotID,
            url: parameters.string("url"),
            format: parameters.string("format"),
            width: parameters.int("width"),
            height: parameters.int("height"),
            size: parameters.int("size"),
            createTime: parameters.string("create_time"),
            imageBase64: parameters.string("image_base64")
        )
    }

    static func snapshotID(from parameters: [String: DeviceProtocolValue]) throws -> String {
        guard let snapshotID = parameters.string("snapshot_id") else {
            throw DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.snapshot_id 缺失")
        }
        return snapshotID
    }

    static func recordingState(from parameters: [String: DeviceProtocolValue]) throws -> DeviceRecordingState {
        guard let isRecording = parameters.bool("status") else {
            throw DeviceSessionCommandError.invalidResponse("VIDEO_CTRL.status 缺失")
        }

        let path = parameters.string("path") ?? parameters.string("dir")
        return DeviceRecordingState(
            isRecording: isRecording,
            path: path?.isEmpty == true ? nil : path
        )
    }

    static func fileDeletionResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileDeletionResult {
        guard let path = parameters.string("path") else {
            throw DeviceSessionCommandError.invalidResponse("FILE_DELETE.path 缺失")
        }

        guard let deleted = parameters.bool("deleted") else {
            throw DeviceSessionCommandError.invalidResponse("FILE_DELETE.deleted 缺失")
        }

        return DeviceFileDeletionResult(path: path, deleted: deleted)
    }

    static func fileLockResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileLockResult {
        guard let path = parameters.string("file") ?? parameters.string("path") else {
            throw DeviceSessionCommandError.invalidResponse("FILE_LOCK.file 缺失")
        }

        guard let locked = parameters.bool("status") else {
            throw DeviceSessionCommandError.invalidResponse("FILE_LOCK.status 缺失")
        }

        return DeviceFileLockResult(path: path, locked: locked)
    }

    static func accessPointIdentity(from parameters: [String: DeviceProtocolValue]) throws -> DeviceAccessPointIdentity {
        guard let ssid = parameters.string("ssid") else {
            throw DeviceSessionCommandError.invalidResponse("AP_SSID_INFO.ssid 缺失")
        }

        return DeviceAccessPointIdentity(
            ssid: ssid,
            password: parameters.string("pwd"),
            isEnabled: parameters.bool("status") ?? true
        )
    }

    static func storageFormatResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceStorageFormatResult {
        guard let formatted = parameters.bool("frm") else {
            throw DeviceSessionCommandError.invalidResponse("FORMAT.frm 缺失")
        }

        return DeviceStorageFormatResult(formatted: formatted)
    }

    static func systemDefaultResult(from parameters: [String: DeviceProtocolValue]) throws -> DeviceSystemDefaultResult {
        guard let restored = parameters.bool("def") else {
            throw DeviceSessionCommandError.invalidResponse("SYSTEM_DEFAULT.def 缺失")
        }

        return DeviceSystemDefaultResult(restored: restored)
    }

    private static func fileItem(from parameters: [String: DeviceProtocolValue]) throws -> DeviceFileItem {
        guard let name = parameters.string("name") else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 name 缺失")
        }

        guard let path = parameters.string("path") else {
            throw DeviceSessionReadOnlyError.invalidResponse("文件 path 缺失")
        }

        return DeviceFileItem(
            name: name,
            path: path,
            size: parameters.int("size"),
            duration: parameters.int("duration"),
            resolution: parameters.string("resolution"),
            createTime: parameters.string("create_time"),
            hasThumbnail: parameters.bool("has_thumbnail") ?? false,
            locked: parameters.bool("locked") ?? false,
            recordType: parameters.string("type")
        )
    }
}

extension DeviceProtocolValue {
    var objectValue: [String: DeviceProtocolValue]? {
        if case .object(let object) = self {
            return object
        }
        return nil
    }

    var arrayValue: [DeviceProtocolValue]? {
        if case .array(let array) = self {
            return array
        }
        return nil
    }
}

private extension Dictionary where Key == String, Value == DeviceProtocolValue {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func int(_ key: String) -> Int? {
        self[key]?.intValue
    }

    func bool(_ key: String) -> Bool? {
        self[key]?.boolValue
    }
}
