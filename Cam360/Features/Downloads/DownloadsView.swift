import SwiftUI

struct DownloadsView: View {
    @ObservedObject var store: DownloadsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "下载",
                subtitle: "设备视频下载和本地保存状态"
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "队列状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            StatusTag(title: "占位", tone: .warning)

                            Text("下载队列、暂停/继续和完成列表仍等待真实下载链路接入。")
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }

                    SectionCard(title: "保存位置") {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "folder")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColor.brand)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("保存至：相册 / App 目录")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundColor(AppColor.textPrimary)

                                Text("真实保存路径会在下载服务确认后显示。")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                    }

                    EmptyStateView(
                        iconName: "arrow.down.circle",
                        title: store.title,
                        message: store.message
                    )
                }
                .padding(AppSpacing.lg)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-downloads")
    }
}
