import SwiftUI

struct AppTopBar: View {
    let title: String
    var eyebrow: String? = nil
    var subtitle: String? = nil
    var leadingSystemImage: String? = nil
    var leadingAction: (() -> Void)? = nil
    var trailingTitle: String? = nil
    var trailingSystemImage: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            if leadingSystemImage != nil {
                if let leadingAction = leadingAction {
                    Button(action: leadingAction) {
                        leadingContent
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    leadingContent
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let eyebrow = eyebrow {
                    Text(eyebrow.uppercased())
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .kerning(0.8)
                }

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
                if let trailingAction = trailingAction {
                    Button(action: trailingAction) {
                        trailingContent
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    trailingContent
                }
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

    private var leadingContent: some View {
        Image(systemName: leadingSystemImage ?? "")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(AppColor.brand)
            .frame(width: 32, height: 32)
    }

    private var trailingContent: some View {
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
}
