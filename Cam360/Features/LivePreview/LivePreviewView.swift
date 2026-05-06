import SwiftUI

struct LivePreviewView: View {
    @ObservedObject var store: LivePreviewStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "实时预览",
                subtitle: "视频流接入前的离线占位"
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    LivePreviewPlaceholderCard()

                    SectionCard(title: "控制状态") {
                        HStack(spacing: AppSpacing.md) {
                            LivePreviewDisabledAction(iconName: "camera.fill", title: "截图")
                            LivePreviewDisabledAction(iconName: "record.circle", title: "录制")
                            LivePreviewDisabledAction(iconName: "arrow.up.left.and.arrow.down.right", title: "全屏")
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
}

private struct LivePreviewPlaceholderCard: View {
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
                        StatusTag(title: "未连接", tone: .warning, size: .compact, style: .filled)
                        StatusTag(title: "4K", tone: .neutral, size: .compact, style: .filled)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Image(systemName: "video.slash")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))

                        Text("等待真实视频流")
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

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
                .frame(width: 42, height: 42)
                .background(AppColor.surfaceMuted)
                .cornerRadius(AppRadius.small)

            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
