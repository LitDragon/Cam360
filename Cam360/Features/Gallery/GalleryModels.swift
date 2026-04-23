import SwiftUI

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

struct GallerySectionModel: Identifiable {
    let kind: GallerySectionKind
    let items: [GalleryItem]

    var id: GallerySectionKind { kind }
}

struct GalleryItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let detail: String
    let duration: String?
    let kind: GalleryMediaKind
    let section: GallerySectionKind
    let thumbnailSymbol: String
    let thumbnailColors: [Color]

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

    static let sampleData: [GalleryItem] = [
        GalleryItem(
            title: "紧急刹车",
            subtitle: "10:15",
            detail: "4K · 245 MB",
            duration: "00:45",
            kind: .event,
            section: .today,
            thumbnailSymbol: "car.fill",
            thumbnailColors: [
                Color(red: 0.09, green: 0.20, blue: 0.32),
                Color(red: 0.36, green: 0.52, blue: 0.72)
            ]
        ),
        GalleryItem(
            title: "日常录制",
            subtitle: "09:42",
            detail: "4K · 245 MB",
            duration: "03:00",
            kind: .video,
            section: .today,
            thumbnailSymbol: "road.lanes",
            thumbnailColors: [
                Color(red: 0.13, green: 0.32, blue: 0.29),
                Color(red: 0.47, green: 0.67, blue: 0.40)
            ]
        ),
        GalleryItem(
            title: "停车监控",
            subtitle: "08:12",
            detail: "4K · 245 MB",
            duration: "03:00",
            kind: .event,
            section: .today,
            thumbnailSymbol: "parkingsign.circle.fill",
            thumbnailColors: [
                Color(red: 0.34, green: 0.25, blue: 0.15),
                Color(red: 0.72, green: 0.57, blue: 0.34)
            ]
        ),
        GalleryItem(
            title: "高速抓拍",
            subtitle: "18:45",
            detail: "12 MP · 6.2 MB",
            duration: nil,
            kind: .photo,
            section: .yesterday,
            thumbnailSymbol: "camera.macro",
            thumbnailColors: [
                Color(red: 0.11, green: 0.25, blue: 0.20),
                Color(red: 0.45, green: 0.66, blue: 0.53)
            ]
        ),
        GalleryItem(
            title: "晚高峰录制",
            subtitle: "17:08",
            detail: "1080P · 182 MB",
            duration: "02:10",
            kind: .video,
            section: .yesterday,
            thumbnailSymbol: "tram.fill",
            thumbnailColors: [
                Color(red: 0.18, green: 0.16, blue: 0.33),
                Color(red: 0.51, green: 0.35, blue: 0.63)
            ]
        ),
        GalleryItem(
            title: "碰撞提醒",
            subtitle: "前天 22:12",
            detail: "4K · 301 MB",
            duration: "01:30",
            kind: .event,
            section: .earlier,
            thumbnailSymbol: "exclamationmark.triangle.fill",
            thumbnailColors: [
                Color(red: 0.35, green: 0.12, blue: 0.18),
                Color(red: 0.76, green: 0.33, blue: 0.28)
            ]
        )
    ]
}
