import Combine
import Foundation

enum LivePreviewState: Equatable {
    case unavailable(reason: String)
    case checking
}

final class LivePreviewStore: ObservableObject {
    @Published private(set) var previewState: LivePreviewState = .unavailable(reason: "当前没有可显示的视频流。")

    private let offlineRefreshDelay: TimeInterval = 0.2
    private var refreshGeneration = 0

    var title: String {
        switch previewState {
        case .unavailable:
            return "实时预览暂不可用"
        case .checking:
            return "正在检查预览状态"
        }
    }

    var message: String {
        switch previewState {
        case .unavailable(let reason):
            return reason
        case .checking:
            return "正在确认设备能力、控制通道和视频流入口。"
        }
    }

    var statusTitle: String {
        switch previewState {
        case .unavailable:
            return "未连接"
        case .checking:
            return "检查中"
        }
    }

    var placeholderTitle: String {
        switch previewState {
        case .unavailable:
            return "等待真实视频流"
        case .checking:
            return "正在检查预览入口"
        }
    }

    var canRefreshPreview: Bool {
        previewState != .checking
    }

    var canCaptureSnapshot: Bool {
        false
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

            self.previewState = .unavailable(reason: "真实视频流和播放器尚未接入，当前只能展示离线预览占位。")
        }
    }
}
