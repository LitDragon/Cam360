import SwiftUI

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 38, weight: .regular))
                .foregroundColor(AppColor.textSecondary)

            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColor.textPrimary)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxl)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
    }
}
