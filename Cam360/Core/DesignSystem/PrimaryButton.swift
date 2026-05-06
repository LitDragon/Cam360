import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var leadingSystemImageName: String? = nil
    var trailingSystemImageName: String? = nil
    var verticalPadding: CGFloat = AppSpacing.lg
    var cornerRadius: CGFloat = AppRadius.medium
    var shadowColor: Color = Color.black.opacity(0.08)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let leadingSystemImageName = leadingSystemImageName {
                    Image(systemName: leadingSystemImageName)
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(title)
                    .font(AppTypography.button)

                if let trailingSystemImageName = trailingSystemImageName {
                    Image(systemName: trailingSystemImageName)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(isEnabled ? AppColor.brand : AppColor.brand.opacity(0.35))
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEnabled == false)
        .shadow(color: shadowColor, radius: 16, x: 0, y: 8)
    }
}
