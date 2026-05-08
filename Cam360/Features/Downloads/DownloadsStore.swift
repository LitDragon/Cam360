import Combine
import Foundation

enum DownloadsQueueState: Equatable {
    case empty
    case loading
    case unavailable(message: String)
}

final class DownloadsStore: ObservableObject {
    @Published private(set) var queueState: DownloadsQueueState = .empty

    private let offlineRefreshDelay: TimeInterval = 0.2
    private var refreshGeneration = 0

    var title: String {
        switch queueState {
        case .empty:
            return "没有下载任务"
        case .loading:
            return "正在读取下载队列"
        case .unavailable:
            return "下载链路未接入"
        }
    }

    var message: String {
        switch queueState {
        case .empty:
            return "当前没有进行中或已完成的下载。"
        case .loading:
            return "正在检查设备文件选择和本地保存状态。"
        case .unavailable:
            return "请先从设备文件选择下载项；真实下载任务会在设备和本地保存链路恢复后接入。"
        }
    }

    var statusTitle: String {
        switch queueState {
        case .empty:
            return "空队列"
        case .loading:
            return "读取中"
        case .unavailable:
            return "离线占位"
        }
    }

    var queueMessage: String {
        switch queueState {
        case .empty:
            return "还没有来自设备文件列表的下载项。"
        case .loading:
            return "正在读取下载队列状态。"
        case .unavailable(let message):
            return message
        }
    }

    var canRefreshQueue: Bool {
        queueState != .loading
    }

    var canStartDownload: Bool {
        false
    }

    var canPauseQueue: Bool {
        false
    }

    var refreshButtonTitle: String {
        queueState == .loading ? "读取中" : "刷新队列"
    }

    func refreshQueue() {
        guard canRefreshQueue else {
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        queueState = .loading

        DispatchQueue.main.asyncAfter(deadline: .now() + offlineRefreshDelay) { [weak self] in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            self.queueState = .unavailable(message: "下载服务尚未接入，无法读取真实下载队列。")
        }
    }
}
