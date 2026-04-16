import SwiftUI

struct DownloadsView: View {
    @ObservedObject var store: DownloadsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionCard(title: "下载与导出") {
                    Text("Application Support、Caches 和导出路径已经在架构文档定型，M0 先保留 UI 容器和状态入口。")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                }

                InlineLoadingView(title: store.title, message: store.message)
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("下载", displayMode: .inline)
        .accessibility(identifier: "screen-downloads")
    }
}
