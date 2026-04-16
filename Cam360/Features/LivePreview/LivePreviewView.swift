import SwiftUI

struct LivePreviewView: View {
    @ObservedObject var store: LivePreviewStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionCard(title: "媒体场景骨架") {
                    Text("当前只保留页面结构、状态占位和后续服务挂载点，不启动任何真实预览链路。")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                }

                ErrorStateView(
                    title: store.title,
                    message: store.message,
                    actionTitle: nil,
                    action: nil
                )
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("实时预览", displayMode: .inline)
        .accessibility(identifier: "screen-livePreview")
    }
}
