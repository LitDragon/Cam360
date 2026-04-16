import Combine

final class LivePreviewStore: ObservableObject {
    @Published private(set) var title = "预览能力待接入"
    @Published private(set) var message = "实时流建立、断流恢复和超时处理会在 M2 接入，这一页先固定媒体场景导航与错误态结构。"
}
