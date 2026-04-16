import Combine

final class LivePreviewStore: ObservableObject {
    @Published private(set) var title = "实时预览暂不可用"
    @Published private(set) var message = "当前没有可显示的视频流。"
}
