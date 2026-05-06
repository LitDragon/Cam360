import SwiftUI

enum EmptyStateStyle {
    case card
    case plain
}

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let message: String
    var style: EmptyStateStyle = .card
    var contentSpacing: CGFloat = AppSpacing.md
    var textSpacing: CGFloat = AppSpacing.md

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.xxl)
            .modifier(EmptyStateSurfaceModifier(style: style))
    }

    private var content: some View {
        VStack(spacing: contentSpacing) {
            Image(systemName: iconName)
                .font(.system(size: 38, weight: .regular))
                .foregroundColor(AppColor.textSecondary)

            VStack(spacing: textSpacing) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct EmptyStateSurfaceModifier: ViewModifier {
    let style: EmptyStateStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .card:
            content.appSurface(borderColor: nil)
        case .plain:
            content
        }
    }
}
