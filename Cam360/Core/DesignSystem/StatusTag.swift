import SwiftUI

enum StatusTagTone: Equatable {
    case accent
    case success
    case warning
    case danger
    case neutral
}

enum StatusTagSize {
    case regular
    case compact
}

enum StatusTagStyle {
    case subtle
    case filled
}

struct StatusTag: View {
    let title: String
    let tone: StatusTagTone
    var size: StatusTagSize = .regular
    var style: StatusTagStyle = .subtle

    var body: some View {
        Text(title)
            .font(font)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
    }

    private var font: Font {
        switch size {
        case .regular:
            return AppTypography.caption
        case .compact:
            return .system(size: 9, weight: .bold)
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular:
            return AppSpacing.md
        case .compact:
            return 7
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular:
            return AppSpacing.xs
        case .compact:
            return AppSpacing.xs
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .regular:
            return AppRadius.small
        case .compact:
            return 6
        }
    }

    private var foregroundColor: Color {
        guard style == .subtle else {
            return .white
        }

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
        guard style == .subtle else {
            return filledBackgroundColor
        }

        switch tone {
        case .accent:
            return AppColor.accentSurface
        case .success:
            return AppColor.success.opacity(size == .compact ? 0.16 : 0.12)
        case .warning:
            return AppColor.warning.opacity(size == .compact ? 0.18 : 0.14)
        case .danger:
            return AppColor.dangerSurface
        case .neutral:
            return AppColor.surfaceMuted
        }
    }

    private var filledBackgroundColor: Color {
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
}
