import SwiftUI

struct PlaybackView: View {
    @ObservedObject var store: PlaybackStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "回放",
                subtitle: "设备录像资源读取状态",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "播放器") {
                        PlaybackPlaceholderCard(isResourceReady: store.playbackResource != nil)
                    }

                    playbackStateView
                }
                .padding(AppSpacing.lg)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-playback")
    }

    @ViewBuilder
    private var playbackStateView: some View {
        if store.isLoading {
            InlineLoadingView(
                title: "正在读取录像",
                message: "正在从设备文件列表获取可回放资源。"
            )
        } else if let lastLoadError = store.lastLoadError {
            ErrorStateView(
                title: "回放加载失败",
                message: lastLoadError,
                actionTitle: nil,
                action: nil
            )
        } else if let playbackResource = store.playbackResource {
            PlaybackResourceSummaryView(
                resource: playbackResource,
                fileInfo: store.selectedFileInfo
            )
        } else {
            EmptyStateView(
                iconName: "film",
                title: store.title,
                message: store.message
            )
        }
    }
}

private struct PlaybackPlaceholderCard: View {
    let isResourceReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.textPrimary.opacity(0.86))
                    .frame(height: 190)

                Image(systemName: isResourceReady ? "play.circle.fill" : "film")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "play.fill")
                AppProgressBar(progress: isResourceReady ? 0.08 : 0)
                Text("00:00")
                    .font(AppTypography.caption)
            }
            .foregroundColor(AppColor.textSecondary)
        }
    }
}

private struct PlaybackResourceSummaryView: View {
    let resource: DeviceFilePlaybackResource
    let fileInfo: DeviceFileInfo?

    var body: some View {
        SectionCard(title: "回放资源") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                StatusTag(title: "资源已读取", tone: .success)

                PlaybackInfoRow(title: "地址", value: resource.rtspURL)
                PlaybackInfoRow(title: "文件", value: fileInfo?.item.name ?? resource.path)

                if let duration = resource.duration {
                    PlaybackInfoRow(title: "时长", value: "\(duration) 秒")
                }

                if let resolution = fileInfo?.item.resolution {
                    PlaybackInfoRow(title: "分辨率", value: resolution)
                }

                if let transport = resource.transport {
                    PlaybackInfoRow(title: "传输", value: transport)
                }
            }
        }
    }
}

private struct PlaybackInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
