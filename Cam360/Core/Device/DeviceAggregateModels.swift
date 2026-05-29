import Foundation

enum DeviceStateSyncScope: String, Equatable {
    case initial
    case home
    case storage
    case settingsHome = "settings_home"
    case recording
    case safety
    case watermark
    case wifi
    case systemPreferences = "system_preferences"
    case statistics
}

enum DeviceMediaIndexGroupBy: String, Equatable {
    case none
    case date
}

struct DeviceMediaIndexQuery: Equatable {
    let mediaType: DeviceFileType
    let groupBy: DeviceMediaIndexGroupBy
    let eventOnly: Bool
    let pageNo: Int
    let pageSize: Int

    init(
        mediaType: DeviceFileType = .video,
        groupBy: DeviceMediaIndexGroupBy = .date,
        eventOnly: Bool = false,
        pageNo: Int = 1,
        pageSize: Int = 20
    ) {
        self.mediaType = mediaType
        self.groupBy = groupBy
        self.eventOnly = eventOnly
        self.pageNo = pageNo
        self.pageSize = pageSize
    }
}

struct DeviceRecentEventsQuery: Equatable {
    let limit: Int
    let eventType: String
    let includeLockedOnly: Bool

    init(limit: Int = 4, eventType: String = "all", includeLockedOnly: Bool = false) {
        self.limit = limit
        self.eventType = eventType
        self.includeLockedOnly = includeLockedOnly
    }
}

struct DeviceStateSyncSnapshot: Equatable {
    let scope: DeviceStateSyncScope
    let sections: [String: DeviceProtocolValue]
}

struct DeviceRecentEventsPage: Equatable {
    let limit: Int
    let totalRecentCount: Int
    let items: [DeviceRecentEventItem]
}

struct DeviceRecentEventItem: Equatable, Identifiable {
    let id: String
    let path: String?
    let eventType: String
    let titleKey: String?
    let title: String
    let createTime: String?
    let duration: Int?
    let locked: Bool
}

struct DeviceMediaIndexResult: Equatable {
    let filters: [String: DeviceProtocolValue]
    let summary: [String: DeviceProtocolValue]
    let groups: [DeviceMediaIndexGroup]
}

struct DeviceMediaIndexGroup: Equatable {
    let groupKey: String
    let items: [DeviceMediaIndexItem]
}

struct DeviceMediaIndexItem: Equatable {
    let name: String
    let path: String
    let eventType: String?
    let title: String?
    let createTime: String?
    let duration: Int?
    let resolution: String?
    let size: Int?
    let locked: Bool
    let hasThumbnail: Bool
}

enum DeviceAggregateResponseParser {
    static func stateSync(from parameters: [String: DeviceProtocolValue]) throws -> DeviceStateSyncSnapshot {
        guard let scopeText = parameters.string("scope"),
              let scope = DeviceStateSyncScope(rawValue: scopeText) else {
            throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.scope 缺失")
        }

        guard let sections = parameters.object("sections") else {
            throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.sections 缺失")
        }

        return DeviceStateSyncSnapshot(scope: scope, sections: sections)
    }

    static func recentEvents(from parameters: [String: DeviceProtocolValue]) throws -> DeviceRecentEventsPage {
        guard let itemValues = parameters["items"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.items 缺失")
        }

        return DeviceRecentEventsPage(
            limit: parameters.int("limit") ?? itemValues.count,
            totalRecentCount: parameters.int("total_recent_count") ?? itemValues.count,
            items: try itemValues.map(recentEvent(from:))
        )
    }

    static func mediaIndex(from parameters: [String: DeviceProtocolValue]) throws -> DeviceMediaIndexResult {
        guard let groupValues = parameters["groups"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.groups 缺失")
        }

        return DeviceMediaIndexResult(
            filters: parameters.object("filters") ?? [:],
            summary: parameters.object("summary") ?? [:],
            groups: try groupValues.map(mediaIndexGroup(from:))
        )
    }

    static func configurationPayload(from parameters: [String: DeviceProtocolValue]) -> [String: DeviceProtocolValue] {
        parameters
    }

    nonisolated private static func recentEvent(from value: DeviceProtocolValue) throws -> DeviceRecentEventItem {
        guard let object = value.objectValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.items 包含非对象")
        }

        guard let id = object.string("event_id") ?? object.string("id") else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.event_id 缺失")
        }

        let eventType = object.string("event_type") ?? "normal"
        return DeviceRecentEventItem(
            id: id,
            path: object.string("path"),
            eventType: eventType,
            titleKey: object.string("title_key"),
            title: object.string("title") ?? Self.title(for: eventType),
            createTime: object.string("create_time"),
            duration: object.int("duration"),
            locked: object.bool("locked") ?? false
        )
    }

    nonisolated private static func mediaIndexGroup(from value: DeviceProtocolValue) throws -> DeviceMediaIndexGroup {
        guard let object = value.objectValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.groups 包含非对象")
        }
        guard let itemValues = object["items"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.groups.items 缺失")
        }

        return DeviceMediaIndexGroup(
            groupKey: object.string("group_key") ?? "all",
            items: try itemValues.map(mediaIndexItem(from:))
        )
    }

    nonisolated private static func mediaIndexItem(from value: DeviceProtocolValue) throws -> DeviceMediaIndexItem {
        guard let object = value.objectValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.items 包含非对象")
        }
        guard let path = object.string("path") else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.path 缺失")
        }

        let eventType = object.string("event_type") ?? object.string("record_type")
        let name = object.string("name") ?? URL(fileURLWithPath: path).lastPathComponent
        return DeviceMediaIndexItem(
            name: name,
            path: path,
            eventType: eventType,
            title: object.string("title"),
            createTime: object.string("create_time"),
            duration: object.int("duration"),
            resolution: object.string("resolution"),
            size: object.int("size"),
            locked: object.bool("locked") ?? false,
            hasThumbnail: object.bool("has_thumbnail") ?? false
        )
    }

    nonisolated private static func title(for eventType: String) -> String {
        switch eventType {
        case "impact":
            return "Collision Detected"
        case "motion":
            return "Motion Detected"
        case "manual":
            return "Manual Save"
        case "parking":
            return "Parking Incident"
        case "emergency":
            return "Emergency Event"
        default:
            return "Recording Event"
        }
    }
}

extension Dictionary where Key == String, Value == DeviceProtocolValue {
    nonisolated func object(_ key: String) -> [String: DeviceProtocolValue]? {
        self[key]?.objectValue
    }

    nonisolated func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    nonisolated func int(_ key: String) -> Int? {
        self[key]?.intValue
    }

    nonisolated func double(_ key: String) -> Double? {
        self[key]?.doubleValue
    }

    nonisolated func bool(_ key: String) -> Bool? {
        self[key]?.boolValue
    }
}

extension DeviceProtocolValue {
    nonisolated var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }
}
