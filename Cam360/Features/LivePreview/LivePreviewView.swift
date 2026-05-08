import SwiftUI

struct LivePreviewView: View {
    @ObservedObject var store: LivePreviewStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "实时预览",
                subtitle: "视频流接入前的离线占位",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    LivePreviewPlaceholderCard(
                        statusTitle: store.statusTitle,
                        placeholderTitle: store.placeholderTitle,
                        statusTone: previewStatusTone
                    )

                    SectionCard(title: "控制状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack(spacing: AppSpacing.md) {
                                LivePreviewDisabledAction(
                                    iconName: "camera.fill",
                                    title: "截图",
                                    isEnabled: store.canCaptureSnapshot
                                )
                                LivePreviewDisabledAction(
                                    iconName: "record.circle",
                                    title: "录制",
                                    isEnabled: store.canToggleRecording
                                )
                                LivePreviewDisabledAction(
                                    iconName: "arrow.up.left.and.arrow.down.right",
                                    title: "全屏",
                                    isEnabled: store.canEnterFullscreen
                                )
                            }

                            Text("截图、录制和全屏需要真实视频流、播放器和本地保存链路确认后启用。")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColor.textSecondary)

                            PrimaryButton(
                                title: store.refreshButtonTitle,
                                isEnabled: store.canRefreshPreview,
                                leadingSystemImageName: "arrow.clockwise",
                                action: store.refreshPreviewStatus
                            )
                        }
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
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-livePreview")
    }

    private var previewStatusTone: StatusTagTone {
        switch store.previewState {
        case .unavailable:
            return .warning
        case .checking:
            return .accent
        }
    }
}

private struct LivePreviewPlaceholderCard: View {
    let statusTitle: String
    let placeholderTitle: String
    let statusTone: StatusTagTone

    var body: some View {
        SectionCard(title: "预览画面") {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.textPrimary.opacity(0.9),
                                AppColor.textPrimary.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 210)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        StatusTag(title: statusTitle, tone: statusTone, size: .compact, style: .filled)
                        StatusTag(title: "4K", tone: .neutral, size: .compact, style: .filled)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Image(systemName: "video.slash")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))

                        Text(placeholderTitle)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
                .padding(AppSpacing.lg)
                .frame(height: 210)
            }
        }
    }
}

private struct LivePreviewDisabledAction: View {
    let iconName: String
    let title: String
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isEnabled ? AppColor.brand : AppColor.textSecondary)
                .frame(width: 42, height: 42)
                .background(isEnabled ? AppColor.accentSurface : AppColor.surfaceMuted)
                .cornerRadius(AppRadius.small)

            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(isEnabled ? AppColor.brand : AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
