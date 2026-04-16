import Combine

final class DownloadsStore: ObservableObject {
    @Published private(set) var title = "下载任务中心搭建中"
    @Published private(set) var message = "下载状态机、文件落盘和导出流程会在 M4 接入。当前保留列表入口与加载态结构。"
}
