import SwiftUI

struct GalleryActionSheet: View {
    let item: GalleryItem
    let onDismiss: () -> Void
    let onDownload: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.24)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture(perform: onDismiss)

            VStack(spacing: AppSpacing.lg) {
                Capsule()
                    .fill(AppColor.border)
                    .frame(width: 44, height: 5)
                    .padding(.top, AppSpacing.sm)

                HStack(spacing: AppSpacing.md) {
                    GalleryThumbnail(item: item)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(item.title)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.textPrimary)

                        Text(item.subtitle)
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)

                        Text(item.detail)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.lg)

                VStack(spacing: AppSpacing.xs) {
                    GallerySheetActionRow(
                        title: "下载到本机",
                        systemImage: "arrow.down.circle",
                        tint: AppColor.brand,
                        isDestructive: false,
                        action: onDownload
                    )

                    GallerySheetActionRow(
                        title: "分享",
                        systemImage: "square.and.arrow.up",
                        tint: AppColor.brand,
                        isDestructive: false,
                        action: onShare
                    )

                    GallerySheetActionRow(
                        title: "删除",
                        systemImage: "trash",
                        tint: AppColor.danger,
                        isDestructive: true,
                        action: onDelete
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.xLarge)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
    }
}

struct GallerySheetActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(tint)
                }

                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(isDestructive ? AppColor.danger : AppColor.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.background)
            .cornerRadius(AppRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
