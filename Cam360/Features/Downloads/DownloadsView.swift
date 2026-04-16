import SwiftUI

struct DownloadsView: View {
    @ObservedObject var store: DownloadsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionCard(title: "下载与导出") {
                    Text("当前未检测到下载或导出任务。")
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
