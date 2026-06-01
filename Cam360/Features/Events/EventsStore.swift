import Combine
import Foundation

enum EventsFilter: String, CaseIterable, Equatable {
    case all = "全部"
    case safety = "安全"
    case parking = "停车"
    case manual = "手动"
}

enum EventsFeedState: Equatable {
    case empty
    case refreshing
    case available
    case unavailable(message: String)
}

struct EventCategory: Identifiable, Equatable {
    let id: EventsFilter
    let iconName: String
    let title: String
    let message: String
    let tone: StatusTagTone
}

final class EventsStore: ObservableObject {
    @Published private(set) var feedState: EventsFeedState = .empty
    @Published private(set) var recentEvents: [DeviceRecentEventItem] = []
    @Published var selectedFilter: EventsFilter = .all

    private let deviceSession: DeviceSession?
    private let offlineRefreshDelay: TimeInterval = 0.2
    private var refreshGeneration = 0
    private var cancellables = Set<AnyCancellable>()

    init(deviceSession: DeviceSession? = nil) {
        self.deviceSession = deviceSession
        bindDeviceSession()
    }

    var statusTitle: String {
        switch feedState {
        case .empty:
            return "离线空态"
        case .refreshing:
            return "刷新中"
        case .available:
            return "已同步"
        case .unavailable:
            return "事件索引不可用"
        }
    }

    var statusMessage: String {
        switch feedState {
        case .empty:
            return "控制通道 ready 后会读取 MEDIA_INDEX(event_only=1)；离线状态只展示分类和空态。"
        case .refreshing:
            return "正在检查安全告警、停车守护和手动保存入口。"
        case .available:
            return "已读取设备事件媒体索引。"
        case .unavailable(let message):
            return message
        }
    }

    var emptyTitle: String {
        switch feedState {
        case .empty:
            return "暂无事件数据"
        case .refreshing:
            return "正在检查事件列表"
        case .available:
            return "最近事件"
        case .unavailable:
            return "事件索引不可用"
        }
    }

    var emptyMessage: String {
        switch feedState {
        case .empty:
            return "离线阶段不展示模拟事件；控制通道 ready 后会读取设备事件媒体索引。"
        case .refreshing:
            return "正在等待离线检查结果。"
        case .available:
            return visibleEvents.isEmpty ? "当前筛选下没有事件媒体。" : "事件列表已按设备媒体索引刷新。"
        case .unavailable:
            return "需要控制通道 ready 后读取 MEDIA_INDEX(event_only=1)；真实事件推送仍等待设备链路确认。"
        }
    }

    var canRefreshEvents: Bool {
        feedState != .refreshing
    }

    var refreshButtonTitle: String {
        feedState == .refreshing ? "刷新中" : "刷新事件"
    }

    var visibleCategories: [EventCategory] {
        let categories = Self.categories
        guard selectedFilter != .all else {
            return categories
        }
        return categories.filter { $0.id == selectedFilter }
    }

    var visibleEvents: [DeviceRecentEventItem] {
        switch selectedFilter {
        case .all:
            return recentEvents
        case .safety:
            return recentEvents.filter { ["impact", "motion", "emergency"].contains($0.eventType) }
        case .parking:
            return recentEvents.filter { $0.eventType == "parking" }
        case .manual:
            return recentEvents.filter { $0.eventType == "manual" }
        }
    }

    func refreshEvents() {
        guard canRefreshEvents else {
            return
        }

        if deviceSession?.state.canSendDeviceCommand == true {
            loadEventMediaIndex()
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        feedState = .refreshing

        DispatchQueue.main.asyncAfter(deadline: .now() + offlineRefreshDelay) { [weak self] in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            self.feedState = .unavailable(message: "事件列表需要控制通道 ready 后读取 MEDIA_INDEX(event_only=1)，离线占位不读取真实设备文件。")
        }
    }

    private func bindDeviceSession() {
        deviceSession?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard case .ready = state else {
                    if state.canSendDeviceCommand == false {
                        self?.recentEvents = []
                    }
                    return
                }
                self?.loadEventMediaIndex()
            }
            .store(in: &cancellables)
    }

    private func loadEventMediaIndex() {
        guard let deviceSession else {
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        feedState = .refreshing

        let query = DeviceMediaIndexQuery(
            mediaType: .video,
            groupBy: .date,
            eventOnly: true,
            pageNo: 1,
            pageSize: 20
        )
        deviceSession.fetchMediaIndex(query: query) { [weak self] result in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            switch result {
            case .success(let result):
                self.recentEvents = Self.events(from: result)
                self.feedState = .available
            case .failure(let error):
                self.recentEvents = []
                self.feedState = .unavailable(message: error.message)
            }
        }
    }

    private static func events(from result: DeviceMediaIndexResult) -> [DeviceRecentEventItem] {
        result.groups.flatMap(\.items).map { item in
            let eventType = item.eventType ?? "normal"
            return DeviceRecentEventItem(
                id: item.path,
                path: item.path,
                mediaType: item.mediaType,
                eventType: eventType,
                titleKey: item.titleKey,
                title: item.title ?? title(for: eventType),
                createTime: item.createTime,
                duration: item.duration,
                size: item.size,
                locked: item.locked,
                thumbReady: item.hasThumbnail
            )
        }
    }

    private static func title(for eventType: String) -> String {
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

    private static let categories = [
        EventCategory(
            id: .safety,
            iconName: "exclamationmark.octagon.fill",
            title: "碰撞与急刹",
            message: "控制通道同步后按事件媒体索引展示高优先级安全事件。",
            tone: .danger
        ),
        EventCategory(
            id: .parking,
            iconName: "parkingsign.circle.fill",
            title: "停车守护",
            message: "停车监控事件会按 MEDIA_INDEX(event_only=1) 时间线汇总。",
            tone: .accent
        ),
        EventCategory(
            id: .manual,
            iconName: "bookmark.fill",
            title: "手动保存",
            message: "手动标记片段通过事件媒体索引和设备文件链路确认。",
            tone: .neutral
        )
    ]
}
