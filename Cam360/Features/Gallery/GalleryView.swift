import SwiftUI

struct GalleryView: View {
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "相册", subtitle: "本地媒体与设备媒体")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    EmptyStateView(
                        iconName: "photo.on.rectangle.angled",
                        title: "还没有媒体",
                        message: "当前没有可展示的设备媒体或本地文件。"
                    )

                    QuickActionCard(
                        iconName: "arrow.down.circle",
                        title: downloadsStore.title,
                        message: downloadsStore.message,
                        tint: AppColor.brand
                    )

                    SectionCard(title: "回放") {
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
