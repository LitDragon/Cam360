import SwiftUI

private enum DownloadsNavigationRoute: Hashable {
    case localVideos
}

struct DownloadsView: View {
    @ObservedObject var store: DownloadsStore
    @ObservedObject var localVideosStore: LocalVideosStore
    var onClose: (() -> Void)? = nil

    @State private var route: DownloadsNavigationRoute?

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

                            if case .transferring(let transfer) = store.queueState {
                                DownloadsProgressPanel(transfer: transfer)
                            }

                            PrimaryButton(
                                title: store.refreshButtonTitle,
                                isEnabled: store.canRefreshQueue,
                                leadingSystemImageName: "arrow.clockwise",
                                action: store.refreshQueue
                            )
                        }
                    }

                    SectionCard(title: "下载操作") {
                        VStack(spacing: AppSpacing.md) {
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

                            HStack(spacing: AppSpacing.md) {
                                DownloadsActionButton(
                                    title: "继续队列",
                                    iconName: "play.fill",
                                    isEnabled: false,
                                    action: {}
                                )

                                DownloadsActionButton(
                                    title: "取消任务",
                                    iconName: "xmark",
                                    isEnabled: false,
                                    action: {}
                                )
                            }
                        }
                    }

                    SectionCard(title: "保存位置") {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "folder")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColor.brand)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("保存位置：待下载服务确认")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundColor(AppColor.textPrimary)

                                Text("当前只展示设备传输进度，真实保存路径会在下载服务接入后显示。")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                    }

                    SectionCard(title: "本地视频") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(localVideosStore.message)
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)

                            PrimaryButton(
                                title: "查看本地视频",
                                isEnabled: true,
                                leadingSystemImageName: "film",
                                action: openLocalVideos
                            )
                        }
                    }

                    SectionCard(title: "下载完成") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            if store.completedTransfers.isEmpty {
                                Text("暂无已完成的设备传输记录。")
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColor.textSecondary)
                            } else {
                                ForEach(store.completedTransfers, id: \.taskID) { transfer in
                                    CompletedTransferRow(transfer: transfer)
                                }
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
        .background(navigationLinks)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-downloads")
    }

    private var routeBinding: Binding<DownloadsNavigationRoute?> {
        Binding(
            get: { route },
            set: { route = $0 }
        )
    }

    private var navigationLinks: some View {
        NavigationLink(
            destination: LocalVideosView(
                store: localVideosStore,
                onClose: dismissRoute
            )
            .navigationBarHidden(true),
            tag: DownloadsNavigationRoute.localVideos,
            selection: routeBinding
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func openLocalVideos() {
        route = .localVideos
    }

    private func dismissRoute() {
        route = nil
    }

    private var queueStatusTone: StatusTagTone {
        switch store.queueState {
        case .empty:
            return .neutral
        case .loading:
            return .accent
        case .transferring:
            return .accent
        case .unavailable:
            return .warning
        }
    }
}

private struct DownloadsProgressPanel: View {
    let transfer: DownloadsTransferProgress

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(fileName)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(transfer.progressText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.brand)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.surfaceMuted)

                    Capsule()
                        .fill(AppColor.brand)
                        .frame(width: max(geometry.size.width * CGFloat(transfer.progressFraction), 0))
                }
            }
            .frame(height: AppLayout.progressLineHeight)

            HStack(spacing: AppSpacing.sm) {
                StatusTag(title: statusText, tone: statusTone, size: .compact)

                Text(transfer.speedText ?? "等待速度")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)

                Spacer(minLength: 0)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.small)
    }

    private var fileName: String {
        guard let path = transfer.path, path.isEmpty == false else {
            return transfer.taskID
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private var statusText: String {
        switch transfer.status {
        case "completed":
            return "COMPLETED"
        case "failed":
            return "FAILED"
        default:
            return "TRANSFER"
        }
    }

    private var statusTone: StatusTagTone {
        switch transfer.status {
        case "completed":
            return .success
        case "failed":
            return .danger
        default:
            return .accent
        }
    }
}

private struct CompletedTransferRow: View {
    let transfer: DownloadsTransferProgress

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColor.success)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(fileName)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text("设备传输完成，本地保存路径待下载服务确认。")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.sm) {
                    DownloadsDisabledPill(title: "打开", iconName: "play.fill")
                    DownloadsDisabledPill(title: "删除", iconName: "trash")
                }
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.small)
    }

    private var fileName: String {
        guard let path = transfer.path, path.isEmpty == false else {
            return transfer.taskID
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }
}

private struct DownloadsDisabledPill: View {
    let title: String
    let iconName: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .semibold))

                Text(title)
                    .font(AppTypography.caption)
            }
            .foregroundColor(AppColor.textSecondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(true)
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
