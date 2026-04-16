import SwiftUI

struct InlineLoadingView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ActivityIndicatorView(style: .medium)

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
