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
        self.pageNo = max(pageNo, 1)
        self.pageSize = min(max(pageSize, 1), 100)
    }
}

struct DeviceRecentEventsQuery: Equatable {
    let limit: Int
    let eventType: String
    let includeLockedOnly: Bool

    init(limit: Int = 4, eventType: String = "all", includeLockedOnly: Bool = false) {
        self.limit = min(max(limit, 1), 20)
        self.eventType = Self.normalizedEventType(eventType)
        self.includeLockedOnly = includeLockedOnly
    }

    private static let documentedEventTypes: Set<String> = [
        "all",
        "normal",
        "impact",
        "motion",
        "manual",
        "parking",
        "emergency",
        "photo"
    ]

    private static func normalizedEventType(_ eventType: String) -> String {
        let normalized = eventType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return documentedEventTypes.contains(normalized) ? normalized : "all"
    }
}

struct DeviceStateSyncSnapshot: Equatable {
    let scope: DeviceStateSyncScope
    let schemaVersion: String?
    let generatedAt: String?
    let cacheTTLMilliseconds: Int?
    let truncated: Bool
    let omittedSections: [String]
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
    let mediaType: DeviceFileType?
    let eventType: String
    let titleKey: String?
    let title: String
    let createTime: String?
    let duration: Int?
    let size: Int?
    let locked: Bool
    let thumbReady: Bool
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
    let mediaType: DeviceFileType?
    let eventType: String?
    let titleKey: String?
    let title: String?
    let createTime: String?
    let duration: Int?
    let resolution: String?
    let size: Int?
    let locked: Bool
    let hasThumbnail: Bool
}

enum DeviceAggregateResponseParser {
    nonisolated static func stateSync(from parameters: [String: DeviceProtocolValue]) throws -> DeviceStateSyncSnapshot {
        guard let scopeText = parameters.string("scope"),
              let scope = DeviceStateSyncScope(rawValue: scopeText) else {
            throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.scope 缺失")
        }

        guard let sections = parameters.object("sections") else {
            throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.sections 缺失")
        }

        return DeviceStateSyncSnapshot(
            scope: scope,
            schemaVersion: parameters.string("schema_version"),
            generatedAt: parameters.string("generated_at"),
            cacheTTLMilliseconds: try optionalNonNegativeInteger(
                "cache_ttl_ms",
                in: parameters,
                errorPrefix: "STATE_SYNC"
            ),
            truncated: try stateSyncTruncatedFlag(from: parameters["truncated"]),
            omittedSections: try omittedStateSyncSections(from: parameters["omitted_sections"]),
            sections: sections
        )
    }

    nonisolated static func recentEvents(from parameters: [String: DeviceProtocolValue]) throws -> DeviceRecentEventsPage {
        guard let itemValues = parameters["items"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.items 缺失")
        }

        return DeviceRecentEventsPage(
            limit: try optionalRecentEventsLimit(from: parameters["limit"]) ?? itemValues.count,
            totalRecentCount: try optionalRecentEventsTotalCount(from: parameters["total_recent_count"]) ?? itemValues.count,
            items: try itemValues.map(recentEvent(from:))
        )
    }

    nonisolated static func mediaIndex(from parameters: [String: DeviceProtocolValue]) throws -> DeviceMediaIndexResult {
        guard let groupValues = parameters["groups"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.groups 缺失")
        }

        return DeviceMediaIndexResult(
            filters: parameters.object("filters") ?? [:],
            summary: parameters.object("summary") ?? [:],
            groups: try groupValues.map(mediaIndexGroup(from:))
        )
    }

    nonisolated static func configurationPayload(from parameters: [String: DeviceProtocolValue]) -> [String: DeviceProtocolValue] {
        parameters
    }

    nonisolated private static func optionalNonNegativeInteger(
        _ key: String,
        in parameters: [String: DeviceProtocolValue],
        errorPrefix: String
    ) throws -> Int? {
        guard let value = parameters[key] else {
            return nil
        }

        guard case .int(let intValue) = value, intValue >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(errorPrefix).\(key) 无效")
        }

        return intValue
    }

    nonisolated private static func omittedStateSyncSections(from value: DeviceProtocolValue?) throws -> [String] {
        guard let value else {
            return []
        }

        guard let sections = value.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.omitted_sections 无效")
        }

        return try sections.map { section in
            guard let section = section.stringValue else {
                throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.omitted_sections 无效")
            }

            return section
        }
    }

    nonisolated private static func stateSyncTruncatedFlag(from value: DeviceProtocolValue?) throws -> Bool {
        guard let value else {
            return false
        }
        guard let flag = value.boolValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.truncated 无效")
        }
        return flag
    }

    nonisolated private static func optionalRecentEventsLimit(from value: DeviceProtocolValue?) throws -> Int? {
        guard let value else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.limit 无效")
        }
        guard let limit = value.intValue, (1...20).contains(limit) else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.limit 无效")
        }
        return limit
    }

    nonisolated private static func optionalRecentEventsTotalCount(from value: DeviceProtocolValue?) throws -> Int? {
        guard let value else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.total_recent_count 无效")
        }
        guard let totalCount = value.intValue, totalCount >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.total_recent_count 无效")
        }
        return totalCount
    }

    nonisolated private static func recentEvent(from value: DeviceProtocolValue) throws -> DeviceRecentEventItem {
        guard let object = value.objectValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.items 包含非对象")
        }

        guard let id = nonBlankString(object.string("event_id") ?? object.string("id")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.event_id 缺失")
        }

        guard let path = nonBlankString(object.string("path")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.path 缺失")
        }

        let eventType = object.string("event_type") ?? "normal"
        let titleKey = object.string("title_key")
        return DeviceRecentEventItem(
            id: id,
            path: path,
            mediaType: try optionalMediaType("media_type", in: object, topic: "RECENT_EVENTS"),
            eventType: eventType,
            titleKey: titleKey,
            title: titleKey.flatMap(Self.title(forTitleKey:))
                ?? Self.title(forKnownEventType: eventType)
                ?? object.string("title")
                ?? "Recording Event",
            createTime: object.string("create_time") ?? object.string("start_time"),
            duration: try (
                optionalNonNegativeEventInteger("duration", in: object, topic: "RECENT_EVENTS")
                    ?? optionalNonNegativeEventInteger("duration_sec", in: object, topic: "RECENT_EVENTS")
            ),
            size: try optionalNonNegativeEventInteger("size", in: object, topic: "RECENT_EVENTS"),
            locked: try optionalEventFlag("locked", in: object, topic: "RECENT_EVENTS") ?? false,
            thumbReady: try (
                optionalEventFlag("thumb_ready", in: object, topic: "RECENT_EVENTS")
                    ?? object.bool("has_thumbnail")
                    ?? false
            )
        )
    }

    nonisolated private static func mediaIndexGroup(from value: DeviceProtocolValue) throws -> DeviceMediaIndexGroup {
        guard let object = value.objectValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.groups 包含非对象")
        }
        guard let itemValues = object["items"]?.arrayValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.groups.items 缺失")
        }
        let groupKey: String
        if object.keys.contains("group_key") {
            guard let value = nonBlankString(object.string("group_key")) else {
                throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.group_key 缺失")
            }
            groupKey = value
        } else {
            groupKey = "all"
        }

        return DeviceMediaIndexGroup(
            groupKey: groupKey,
            items: try itemValues.map(mediaIndexItem(from:))
        )
    }

    nonisolated private static func mediaIndexItem(from value: DeviceProtocolValue) throws -> DeviceMediaIndexItem {
        guard let object = value.objectValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.items 包含非对象")
        }
        guard let path = nonBlankString(object.string("path")) else {
            throw DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.path 缺失")
        }

        let eventType = object.string("event_type") ?? object.string("record_type")
        let name = object.string("name") ?? URL(fileURLWithPath: path).lastPathComponent
        let titleKey = object.string("title_key")
        return DeviceMediaIndexItem(
            name: name,
            path: path,
            mediaType: try optionalMediaType("media_type", in: object, topic: "MEDIA_INDEX"),
            eventType: eventType,
            titleKey: titleKey,
            title: titleKey.flatMap(Self.title(forTitleKey:))
                ?? Self.title(forKnownEventType: eventType)
                ?? object.string("title"),
            createTime: object.string("create_time") ?? object.string("start_time"),
            duration: try (
                optionalNonNegativeEventInteger("duration", in: object, topic: "MEDIA_INDEX")
                    ?? optionalNonNegativeEventInteger("duration_sec", in: object, topic: "MEDIA_INDEX")
            ),
            resolution: object.string("resolution"),
            size: try optionalNonNegativeEventInteger("size", in: object, topic: "MEDIA_INDEX"),
            locked: try optionalEventFlag("locked", in: object, topic: "MEDIA_INDEX") ?? false,
            hasThumbnail: try (
                object.bool("has_thumbnail")
                    ?? optionalEventFlag("thumb_ready", in: object, topic: "MEDIA_INDEX")
                    ?? false
            )
        )
    }

    nonisolated private static func nonBlankString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func optionalMediaType(
        _ key: String,
        in parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> DeviceFileType? {
        guard let value = parameters[key] else {
            return nil
        }
        guard let rawMediaType = value.stringValue else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 无效")
        }
        let mediaType = rawMediaType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let documentedType = DeviceFileType(rawValue: mediaType) else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 无效")
        }
        return documentedType
    }

    nonisolated private static func optionalNonNegativeEventInteger(
        _ key: String,
        in parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> Int? {
        guard let value = parameters[key] else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 无效")
        }
        guard let intValue = value.intValue, intValue >= 0 else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 无效")
        }
        return intValue
    }

    nonisolated private static func optionalEventFlag(
        _ key: String,
        in parameters: [String: DeviceProtocolValue],
        topic: String
    ) throws -> Bool? {
        guard let value = parameters[key] else {
            return nil
        }
        if case .bool = value {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 无效")
        }
        guard let intValue = value.intValue, intValue == 0 || intValue == 1 else {
            throw DeviceSessionReadOnlyError.invalidResponse("\(topic).\(key) 无效")
        }
        return intValue == 1
    }

    nonisolated private static func title(forTitleKey titleKey: String) -> String? {
        switch titleKey {
        case "event.normal_recording":
            return "Normal Recording"
        case "event.collision_detected":
            return "Collision Detected"
        case "event.motion_detected":
            return "Motion Detected"
        case "event.manual_save":
            return "Manual Save"
        case "event.parking_incident":
            return "Parking Incident"
        case "event.emergency_event":
            return "Emergency Event"
        case "event.photo":
            return "Photo"
        default:
            return nil
        }
    }

    nonisolated private static func title(forKnownEventType eventType: String?) -> String? {
        switch eventType {
        case "normal":
            return "Normal Recording"
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
        case "photo":
            return "Photo"
        default:
            return nil
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
