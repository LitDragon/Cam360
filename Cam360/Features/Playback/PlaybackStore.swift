import Combine

final class PlaybackStore: ObservableObject {
    @Published private(set) var title = "等待设备录像目录"
    @Published private(set) var message = "时间轴、片段列表和播放器状态会在 M3 接进来，这里先保留入口和空态承载。"
}
