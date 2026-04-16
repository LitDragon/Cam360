import SwiftUI

struct GalleryView: View {
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "相册", subtitle: "媒体列表与动作菜单", trailingTitle: "选择")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    EmptyStateView(
                        iconName: "photo.on.rectangle.angled",
                        title: "暂无媒体文件",
                        message: "完成设备接入后，相册内容将在此展示。"
                    )

                    QuickActionCard(
                        iconName: "arrow.down.circle",
                        title: downloadsStore.title,
                        message: downloadsStore.message,
                        tint: AppColor.brand
                    )

                    SectionCard(title: "后续接入点") {
                        Text(playbackStore.message)
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-gallery")
    }
}
