import Combine
import Foundation

enum LivePreviewState: Equatable {
    case unavailable(reason: String)
    case checking
    case mockAssetReady(url: String)
}

enum LivePreviewSnapshotState: Equatable {
    case idle
    case capturing
    case captured(snapshotID: String, detail: String)
    case failed(message: String)
}

final class LivePreviewStore: ObservableObject {
    @Published private(set) var previewState: LivePreviewState = .unavailable(reason: "当前没有可显示的视频流。")
    @Published private(set) var snapshotState: LivePreviewSnapshotState = .idle
    @Published private(set) var snapshotImageBase64: String?

    private let deviceSession: DeviceSession?
    private let mockPreviewAsset: MockPreviewAsset?
    private let offlineRefreshDelay: TimeInterval = 0.2
    private var refreshGeneration = 0
    private var snapshotGeneration = 0
    private var isDeviceSessionReady = false
    private var didPreparePreview = false
    private var cancellables = Set<AnyCancellable>()

    init(deviceSession: DeviceSession? = nil, mockPreviewAsset: MockPreviewAsset? = nil) {
        self.deviceSession = deviceSession
        self.mockPreviewAsset = mockPreviewAsset
        bindDeviceSession()
    }

    var title: String {
        switch previewState {
        case .unavailable:
            return "实时预览暂不可用"
        case .checking:
            return "正在检查预览状态"
        case .mockAssetReady:
            return "Mock 预览资源可用"
        }
    }

    var message: String {
        switch previewState {
        case .unavailable(let reason):
            return reason
        case .checking:
            return "正在确认设备能力、控制通道和视频流入口。"
        case .mockAssetReady:
            return "已读取本地模拟器 Mock 预览资源，仅用于占位联调；真实预览流协议仍未定义。"
        }
    }

    var statusTitle: String {
        switch previewState {
        case .unavailable:
            return "未连接"
        case .checking:
            return "检查中"
        case .mockAssetReady:
            return "Mock 可用"
        }
    }

    var placeholderTitle: String {
        switch previewState {
        case .unavailable:
            return "等待真实视频流"
        case .checking:
            return "正在检查预览入口"
        case .mockAssetReady:
            return "Mock 预览占位"
        }
    }

    var canRefreshPreview: Bool {
        previewState != .checking
    }

    var canCaptureSnapshot: Bool {
        isDeviceSessionReady && snapshotState != .capturing
    }

    var canToggleRecording: Bool {
        false
    }

    var canEnterFullscreen: Bool {
        false
    }

    var refreshButtonTitle: String {
        previewState == .checking ? "检查中" : "重新检查"
    }

    var snapshotStatusTitle: String {
        switch snapshotState {
        case .idle:
            return isDeviceSessionReady ? "截图可用" : "截图未就绪"
        case .capturing:
            return "截图中"
        case .captured:
            return "截图已获取"
        case .failed:
            return "截图失败"
        }
    }

    var snapshotStatusMessage: String {
        switch snapshotState {
        case .idle:
            if isDeviceSessionReady {
                return "可通过 SNAPSHOT_CTRL/SNAPSHOT_DATA 获取截图数据；本地保存仍未接入。"
            }
            return "等待控制通道 ready 后启用截图命令。"
        case .capturing:
            return "正在发送 SNAPSHOT_CTRL 并读取 SNAPSHOT_DATA。"
        case .captured:
            return "已通过控制通道获取截图数据，可在本页预览；尚未保存到本地相册。"
        case .failed(let message):
            return message
        }
    }

    func preparePreviewIfNeeded() {
        guard didPreparePreview == false else {
            return
        }

        didPreparePreview = true
        refreshPreviewStatus()
    }

    func refreshPreviewStatus() {
        guard canRefreshPreview else {
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        previewState = .checking

        DispatchQueue.main.asyncAfter(deadline: .now() + offlineRefreshDelay) { [weak self] in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            if let mockPreviewURL = self.mockPreviewAsset?.preferredURL {
                self.previewState = .mockAssetReady(url: mockPreviewURL)
                return
            }

            self.previewState = .unavailable(reason: "真实视频流和播放器尚未接入；截图数据仅在控制通道 ready 后可获取。")
        }
    }

    func captureSnapshot() {
        guard canCaptureSnapshot, let deviceSession else {
            return
        }

        snapshotGeneration += 1
        let generation = snapshotGeneration
        snapshotState = .capturing
        snapshotImageBase64 = nil

        DispatchQueue.main.async { [weak self, weak deviceSession] in
            guard let self, let deviceSession, self.snapshotGeneration == generation else {
                return
            }

            deviceSession.captureSnapshot { [weak self] result in
                DispatchQueue.main.async {
                    guard let self, self.snapshotGeneration == generation else {
                        return
                    }

                    switch result {
                    case .success(let resource):
                        self.snapshotImageBase64 = resource.imageBase64
                        self.snapshotState = .captured(
                            snapshotID: resource.snapshotID,
                            detail: Self.snapshotDetail(for: resource)
                        )
                    case .failure(let error):
                        self.snapshotImageBase64 = nil
                        self.snapshotState = .failed(message: error.message)
                    }
                }
            }
        }
    }

    private func bindDeviceSession() {
        deviceSession?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncDeviceSessionState(state)
            }
            .store(in: &cancellables)
    }

    private func syncDeviceSessionState(_ state: DeviceSessionState) {
        isDeviceSessionReady = state.canSendDeviceCommand

        if isDeviceSessionReady == false && snapshotState == .capturing {
            snapshotGeneration += 1
            snapshotImageBase64 = nil
            snapshotState = .failed(message: "设备会话未就绪")
        }
    }

    private static func snapshotDetail(for resource: DeviceSnapshotResource) -> String {
        let resolution: String
        if let width = resource.width, let height = resource.height {
            resolution = "\(width)x\(height)"
        } else {
            resolution = "未知分辨率"
        }

        if let format = resource.format, format.isEmpty == false {
            return "\(resolution) \(format)"
        }
        return resolution
    }
}
