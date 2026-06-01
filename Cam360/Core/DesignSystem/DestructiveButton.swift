import SwiftUI

struct DestructiveButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(isEnabled ? AppColor.danger : AppColor.danger.opacity(0.35))
                .cornerRadius(AppRadius.medium)
        }
        .disabled(isEnabled == false)
        .shadow(color: AppColor.danger.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}
