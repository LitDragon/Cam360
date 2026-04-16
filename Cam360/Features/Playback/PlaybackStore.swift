import Combine

final class PlaybackStore: ObservableObject {
    @Published private(set) var title = "没有可播放内容"
    @Published private(set) var message = "当前没有可显示的设备录像或本地媒体。"
}
