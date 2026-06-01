import SwiftUI
import UIKit

struct LivePreviewView: View {
    @ObservedObject var store: LivePreviewStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "实时预览",
                subtitle: "截图控制已接入，视频流待联调",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    LivePreviewPlaceholderCard(
                        statusTitle: store.statusTitle,
                        placeholderTitle: store.placeholderTitle,
                        statusTone: previewStatusTone,
                        snapshotImageBase64: store.snapshotImageBase64
                    )

                    SectionCard(title: "控制状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack(spacing: AppSpacing.md) {
                                LivePreviewDisabledAction(
                                    iconName: "camera.fill",
                                    title: "截图",
                                    isEnabled: store.canCaptureSnapshot,
                                    action: store.captureSnapshot
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

                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                StatusTag(
                                    title: store.snapshotStatusTitle,
                                    tone: snapshotStatusTone,
                                    size: .compact
                                )

                                Text(store.snapshotStatusMessage)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColor.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Text("截图命令只读取设备返回的数据；保存到本地相册、录制和全屏仍待真实预览与本地资源链路确认。")
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
        .onAppear {
            store.preparePreviewIfNeeded()
        }
    }

    private var previewStatusTone: StatusTagTone {
        switch store.previewState {
        case .unavailable:
            return .warning
        case .checking:
            return .accent
        case .mockAssetReady:
            return .success
        }
    }

    private var snapshotStatusTone: StatusTagTone {
        switch store.snapshotState {
        case .idle:
            return store.canCaptureSnapshot ? .accent : .neutral
        case .capturing:
            return .accent
        case .captured:
            return .success
        case .failed:
            return .warning
        }
    }
}

private struct LivePreviewPlaceholderCard: View {
    let statusTitle: String
    let placeholderTitle: String
    let statusTone: StatusTagTone
    let snapshotImageBase64: String?

    var body: some View {
        SectionCard(title: "预览画面") {
            ZStack(alignment: .topLeading) {
                if let snapshotImage {
                    Image(uiImage: snapshotImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 210)
                        .clipped()

                    Color.black.opacity(0.18)
                } else {
                    LinearGradient(
                        colors: [
                            AppColor.textPrimary.opacity(0.9),
                            AppColor.textPrimary.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

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
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
    }

    private var snapshotImage: UIImage? {
        guard let snapshotImageBase64,
              let data = Data(base64Encoded: snapshotImageBase64) else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct LivePreviewDisabledAction: View {
    let iconName: String
    let title: String
    let isEnabled: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isEnabled == false)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var content: some View {
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
    }
}
