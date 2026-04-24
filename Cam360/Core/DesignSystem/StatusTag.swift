import SwiftUI

enum StatusTagTone: Equatable {
    case accent
    case success
    case warning
    case danger
    case neutral
}

struct StatusTag: View {
    let title: String
    let tone: StatusTagTone

    var body: some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(backgroundColor)
            .cornerRadius(AppRadius.small)
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return AppColor.brand
        case .success:
            return AppColor.success
        case .warning:
            return AppColor.warning
        case .danger:
            return AppColor.danger
        case .neutral:
            return AppColor.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .accent:
            return AppColor.accentSurface
        case .success:
            return AppColor.success.opacity(0.12)
        case .warning:
            return AppColor.warning.opacity(0.14)
        case .danger:
            return AppColor.dangerSurface
        case .neutral:
            return AppColor.surfaceMuted
        }
    }
}
