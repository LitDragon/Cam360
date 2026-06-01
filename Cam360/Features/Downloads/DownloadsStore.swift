import Combine
import Foundation

enum DownloadsQueueState: Equatable {
    case empty
    case loading
    case transferring(DownloadsTransferProgress)
    case unavailable(message: String)
}

struct DownloadsTransferProgress: Equatable {
    let taskID: String
    let path: String?
    let progress: Int?
    let status: String?
    let speed: Int?

    var progressFraction: Double {
        guard let progress else {
            return 0
        }

        return Double(min(max(progress, 0), 100)) / 100
    }

    var progressText: String {
        guard let progress else {
            return "等待进度"
        }

        return "\(min(max(progress, 0), 100))%"
    }

    var speedText: String? {
        Self.speedText(for: speed)
    }

    private static func speedText(for speed: Int?) -> String? {
        guard let speed, speed > 0 else {
            return nil
        }

        let kilobytes = Double(speed) / 1_024
        let megabytes = kilobytes / 1_024
        if megabytes >= 1 {
            return String(format: "%.1f MB/s", megabytes)
        }
        if kilobytes >= 1 {
            return "\(Int(kilobytes.rounded())) KB/s"
        }
        return "\(speed) B/s"
    }
}

final class DownloadsStore: ObservableObject {
    @Published private(set) var queueState: DownloadsQueueState = .empty
    @Published private(set) var completedTransfers: [DownloadsTransferProgress] = []

    private let offlineRefreshDelay: TimeInterval = 0.2
    private var refreshGeneration = 0
    private var cancellables = Set<AnyCancellable>()

    init(deviceSession: DeviceSession? = nil) {
        deviceSession?.$deviceStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.applyDeviceSessionStatus(status)
            }
            .store(in: &cancellables)
    }

    var title: String {
        switch queueState {
        case .empty:
            return "没有下载任务"
        case .loading:
            return "正在读取下载队列"
        case .transferring(let progress):
            switch progress.status {
            case "completed":
                return "下载完成"
            case "failed":
                return "下载失败"
            default:
                return "正在下载"
            }
        case .unavailable:
            return "下载队列不可用"
        }
    }

    var message: String {
        switch queueState {
        case .empty:
            return "当前没有进行中或已完成的下载。"
        case .loading:
            return "正在检查设备侧传输进度和本地保存状态。"
        case .transferring(let progress):
            switch progress.status {
            case "completed":
                return "设备传输完成，本地保存仍等待下载服务接入。"
            case "failed":
                return "设备传输失败，开始、继续和取消仍待下载服务接入。"
            default:
                return "设备正在传输文件；本地保存仍等待下载服务接入。"
            }
        case .unavailable:
            return "当前只接收设备侧 DOWNLOAD_PROGRESS；开始、暂停和保存位置仍待下载服务接入。"
        }
    }

    var statusTitle: String {
        switch queueState {
        case .empty:
            return "空队列"
        case .loading:
            return "读取中"
        case .transferring(let progress):
            return Self.statusTitle(for: progress)
        case .unavailable:
            return "等待任务"
        }
    }

    var queueMessage: String {
        switch queueState {
        case .empty:
            return "还没有来自设备侧 DOWNLOAD_PROGRESS 的传输任务。"
        case .loading:
            return "正在读取下载队列状态。"
        case .transferring(let progress):
            return Self.queueMessage(for: progress)
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

            self.queueState = .unavailable(message: "需要设备侧 DOWNLOAD_PROGRESS 或下载任务服务后才能读取队列。")
        }
    }

    private func applyDeviceSessionStatus(_ status: DeviceSessionStatus) {
        if let latestProgressEvent = status.latestProgressEvent,
           latestProgressEvent.topic == "DOWNLOAD_PROGRESS" {
            applyDownloadProgressEvent(latestProgressEvent)
            return
        }

        let downloadProgressEvents = status.progressEvents.values
            .filter { $0.topic == "DOWNLOAD_PROGRESS" }
            .sorted { $0.taskID < $1.taskID }

        guard let event = downloadProgressEvents.last else {
            return
        }

        applyDownloadProgressEvent(event)
    }

    private func applyDownloadProgressEvent(_ event: DeviceProgressEvent) {
        refreshGeneration += 1
        let transfer = DownloadsTransferProgress(
            taskID: event.taskID,
            path: event.path,
            progress: event.progress,
            status: event.status,
            speed: event.speed
        )
        queueState = .transferring(transfer)

        guard event.status == "completed" else {
            return
        }

        completedTransfers.removeAll { $0.taskID == transfer.taskID }
        completedTransfers.insert(transfer, at: 0)
    }

    private static func statusTitle(for progress: DownloadsTransferProgress) -> String {
        switch progress.status {
        case "completed":
            return "完成"
        case "failed":
            return "失败"
        default:
            if let percent = progress.progress {
                return "\(percent)%"
            }
            return "传输中"
        }
    }

    private static func queueMessage(for progress: DownloadsTransferProgress) -> String {
        let path = progress.path ?? progress.taskID

        switch progress.status {
        case "completed":
            return "\(path) 传输完成。"
        case "failed":
            return "\(path) 传输失败。"
        default:
            if let percent = progress.progress {
                let speed = progress.speedText.map { "，速度 \($0)" } ?? ""
                return "\(path) 正在传输，进度 \(percent)%\(speed)。"
            }
            if let speed = progress.speedText {
                return "\(path) 正在传输，速度 \(speed)。"
            }
            return "\(path) 正在传输。"
        }
    }
}
