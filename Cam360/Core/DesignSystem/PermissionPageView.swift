import SwiftUI

struct PermissionPageView: View {
    let iconName: String
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxl) {
            Spacer(minLength: AppSpacing.xxl)

            Image(systemName: iconName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(AppColor.brand)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(title)
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.md) {
                PrimaryButton(title: primaryTitle, action: primaryAction)

                if let secondaryTitle = secondaryTitle, let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(AppTypography.button)
                            .foregroundColor(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                    }
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
    }
}
