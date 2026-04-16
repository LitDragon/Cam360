import SwiftUI

struct PlaybackView: View {
    @ObservedObject var store: PlaybackStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionCard(title: "回放路线") {
                    Text("后续会在这里接时间轴、片段列表和播放器服务。M0 先固定导航、容器和状态展示。")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                }

                EmptyStateView(
                    iconName: "film",
                    title: store.title,
                    message: store.message
                )
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("回放", displayMode: .inline)
        .accessibility(identifier: "screen-playback")
    }
}
