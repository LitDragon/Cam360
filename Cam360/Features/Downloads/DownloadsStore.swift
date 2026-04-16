import Combine

final class DownloadsStore: ObservableObject {
    @Published private(set) var title = "没有下载任务"
    @Published private(set) var message = "当前没有进行中或已完成的下载。"
}
