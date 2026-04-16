import SwiftUI

struct AppTopBar: View {
    let title: String
    var subtitle: String? = nil
    var trailingTitle: String? = nil
    var trailingSystemImage: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.navigationTitle)
                    .foregroundColor(AppColor.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer()

            if trailingTitle != nil || trailingSystemImage != nil {
                Button(action: trailingAction ?? {}) {
                    HStack(spacing: AppSpacing.xs) {
                        if let trailingTitle = trailingTitle {
                            Text(trailingTitle)
                                .font(AppTypography.bodyStrong)
                        }

                        if let trailingSystemImage = trailingSystemImage {
                            Image(systemName: trailingSystemImage)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(AppColor.brand)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColor.accentSurface)
                    .cornerRadius(AppRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .overlay(
            Rectangle()
                .fill(AppColor.border.opacity(0.8))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
