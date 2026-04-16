import SwiftUI

struct PlaybackView: View {
    @ObservedObject var store: PlaybackStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionCard(title: "回放") {
                    Text("当前没有可展示的回放内容。")
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
