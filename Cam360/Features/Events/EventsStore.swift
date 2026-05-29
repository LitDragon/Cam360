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
            return "事件通道未接入"
        }
    }

    var statusMessage: String {
        switch feedState {
        case .empty:
            return "当前通过首页最近事件入口进入；真实事件流确认前只展示离线分类和空态。"
        case .refreshing:
            return "正在检查安全告警、停车守护和手动保存入口。"
        case .available:
            return "已读取设备最近事件摘要。"
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
            return "事件列表未接入"
        }
    }

    var emptyMessage: String {
        switch feedState {
        case .empty:
            return "离线阶段不展示模拟事件；真实事件列表会在设备事件通道确认后接入。"
        case .refreshing:
            return "正在等待离线检查结果。"
        case .available:
            return recentEvents.isEmpty ? "当前没有最近事件。" : "点击相册查看完整事件列表。"
        case .unavailable:
            return "真实事件推送和历史事件读取仍等待设备链路确认。"
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

    func refreshEvents() {
        guard canRefreshEvents else {
            return
        }

        if deviceSession?.state.canSendDeviceCommand == true {
            loadRecentEvents()
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        feedState = .refreshing

        DispatchQueue.main.asyncAfter(deadline: .now() + offlineRefreshDelay) { [weak self] in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            self.feedState = .unavailable(message: "事件推送和历史事件读取尚未接入，无法读取真实事件列表。")
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
                self?.loadRecentEvents()
            }
            .store(in: &cancellables)
    }

    private func loadRecentEvents() {
        guard let deviceSession else {
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        feedState = .refreshing

        deviceSession.fetchRecentEvents(query: DeviceRecentEventsQuery(limit: 20)) { [weak self] result in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            switch result {
            case .success(let page):
                self.recentEvents = page.items
                self.feedState = .available
            case .failure(let error):
                self.recentEvents = []
                self.feedState = .unavailable(message: error.message)
            }
        }
    }

    private static let categories = [
        EventCategory(
            id: .safety,
            iconName: "exclamationmark.octagon.fill",
            title: "碰撞与急刹",
            message: "等待真实事件流接入后展示高优先级安全事件。",
            tone: .danger
        ),
        EventCategory(
            id: .parking,
            iconName: "parkingsign.circle.fill",
            title: "停车守护",
            message: "停车监控事件恢复后会按时间线汇总。",
            tone: .accent
        ),
        EventCategory(
            id: .manual,
            iconName: "bookmark.fill",
            title: "手动保存",
            message: "手动标记片段仍通过相册和设备文件链路确认。",
            tone: .neutral
        )
    ]
}
