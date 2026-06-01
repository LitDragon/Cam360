import Foundation

enum GalleryFilter: CaseIterable, Identifiable, Equatable {
    case all
    case events
    case videos
    case photos

    var id: String { title }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .events:
            return "事件"
        case .videos:
            return "视频"
        case .photos:
            return "照片"
        }
    }

    func matches(_ item: GalleryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .events:
            return item.kind == .event
        case .videos:
            return item.kind == .video
        case .photos:
            return item.kind == .photo
        }
    }
}

enum GallerySectionKind: CaseIterable, Hashable {
    case today
    case yesterday
    case earlier

    var title: String {
        switch self {
        case .today:
            return "今天"
        case .yesterday:
            return "昨天"
        case .earlier:
            return "更早"
        }
    }

    var trailingText: String {
        switch self {
        case .today:
            return "最近"
        case .yesterday:
            return "昨日"
        case .earlier:
            return "历史"
        }
    }
}

enum GalleryMediaKind: Equatable {
    case event
    case video
    case photo
}

enum GalleryArtworkStyle: Equatable {
    case emergencyBrake
    case dailyRecording
    case parkingMonitor
    case snapshot
    case rushHour
    case collisionAlert
}

struct GallerySectionModel: Identifiable {
    let kind: GallerySectionKind
    let items: [GalleryItem]

    var id: GallerySectionKind { kind }
}

struct GalleryItem: Identifiable {
    let id: UUID
    let devicePath: String?
    let title: String
    let subtitle: String
    let detail: String
    let duration: String?
    let kind: GalleryMediaKind
    let section: GallerySectionKind
    let thumbnailSymbol: String
    let thumbnailStyle: GalleryArtworkStyle
    let thumbnailImageBase64: String?

    nonisolated init(
        id: UUID = UUID(),
        devicePath: String? = nil,
        title: String,
        subtitle: String,
        detail: String,
        duration: String?,
        kind: GalleryMediaKind,
        section: GallerySectionKind,
        thumbnailSymbol: String,
        thumbnailStyle: GalleryArtworkStyle,
        thumbnailImageBase64: String? = nil
    ) {
        self.id = id
        self.devicePath = devicePath
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.duration = duration
        self.kind = kind
        self.section = section
        self.thumbnailSymbol = thumbnailSymbol
        self.thumbnailStyle = thumbnailStyle
        self.thumbnailImageBase64 = thumbnailImageBase64
    }

    var badgeTitle: String? {
        kind == .event ? "紧急事件" : nil
    }

    var badgeTone: StatusTagTone {
        kind == .event ? .danger : .neutral
    }

    func matches(_ keyword: String) -> Bool {
        let normalizedKeyword = keyword.lowercased()
        return title.lowercased().contains(normalizedKeyword) ||
            subtitle.lowercased().contains(normalizedKeyword) ||
            detail.lowercased().contains(normalizedKeyword)
    }

    func withThumbnailImageBase64(_ imageBase64: String?) -> GalleryItem {
        GalleryItem(
            id: id,
            devicePath: devicePath,
            title: title,
            subtitle: subtitle,
            detail: detail,
            duration: duration,
            kind: kind,
            section: section,
            thumbnailSymbol: thumbnailSymbol,
            thumbnailStyle: thumbnailStyle,
            thumbnailImageBase64: imageBase64
        )
    }
}

protocol GalleryMediaProviding {
    func fetchItems() -> [GalleryItem]
}

struct GallerySampleMediaProvider: GalleryMediaProviding {
    func fetchItems() -> [GalleryItem] {
        Self.items
    }
}

private extension GallerySampleMediaProvider {
    static let items: [GalleryItem] = [
        GalleryItem(
            title: "紧急刹车",
            subtitle: "10:15",
            detail: "4K · 245 MB",
            duration: "00:45",
            kind: .event,
            section: .today,
            thumbnailSymbol: "car.fill",
            thumbnailStyle: .emergencyBrake
        ),
        GalleryItem(
            title: "日常录制",
            subtitle: "09:42",
            detail: "4K · 245 MB",
            duration: "03:00",
            kind: .video,
            section: .today,
            thumbnailSymbol: "road.lanes",
            thumbnailStyle: .dailyRecording
        ),
        GalleryItem(
            title: "停车监控",
            subtitle: "08:12",
            detail: "4K · 245 MB",
            duration: "03:00",
            kind: .event,
            section: .today,
            thumbnailSymbol: "parkingsign.circle.fill",
            thumbnailStyle: .parkingMonitor
        ),
        GalleryItem(
            title: "高速抓拍",
            subtitle: "18:45",
            detail: "12 MP · 6.2 MB",
            duration: nil,
            kind: .photo,
            section: .yesterday,
            thumbnailSymbol: "camera.macro",
            thumbnailStyle: .snapshot
        ),
        GalleryItem(
            title: "晚高峰录制",
            subtitle: "17:08",
            detail: "1080P · 182 MB",
            duration: "02:10",
            kind: .video,
            section: .yesterday,
            thumbnailSymbol: "tram.fill",
            thumbnailStyle: .rushHour
        ),
        GalleryItem(
            title: "碰撞提醒",
            subtitle: "前天 22:12",
            detail: "4K · 301 MB",
            duration: "01:30",
            kind: .event,
            section: .earlier,
            thumbnailSymbol: "exclamationmark.triangle.fill",
            thumbnailStyle: .collisionAlert
        )
    ]
}
