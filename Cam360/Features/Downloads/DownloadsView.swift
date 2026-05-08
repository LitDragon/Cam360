import SwiftUI

struct DownloadsView: View {
    @ObservedObject var store: DownloadsStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "下载",
                subtitle: "设备视频下载和本地保存状态",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "队列状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            StatusTag(title: store.statusTitle, tone: queueStatusTone)

                            Text(store.queueMessage)
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)

                            PrimaryButton(
                                title: store.refreshButtonTitle,
                                isEnabled: store.canRefreshQueue,
                                leadingSystemImageName: "arrow.clockwise",
                                action: store.refreshQueue
                            )
                        }
                    }

                    SectionCard(title: "下载操作") {
                        HStack(spacing: AppSpacing.md) {
                            DownloadsActionButton(
                                title: "选择文件",
                                iconName: "doc.badge.plus",
                                isEnabled: store.canStartDownload,
                                action: {}
                            )

                            DownloadsActionButton(
                                title: "暂停队列",
                                iconName: "pause.fill",
                                isEnabled: store.canPauseQueue,
                                action: {}
                            )
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

    private var queueStatusTone: StatusTagTone {
        switch store.queueState {
        case .empty:
            return .neutral
        case .loading:
            return .accent
        case .unavailable:
            return .warning
        }
    }
}

private struct DownloadsActionButton: View {
    let title: String
    let iconName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(isEnabled ? AppColor.accentSurface : AppColor.surfaceMuted)
                    .cornerRadius(AppRadius.small)

                Text(title)
                    .font(AppTypography.caption)
                    .lineLimit(1)
            }
            .foregroundColor(isEnabled ? AppColor.brand : AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEnabled == false)
    }
}
