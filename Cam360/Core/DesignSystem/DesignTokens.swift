import SwiftUI

enum AppColor {
    static let brand = Color("Brand")
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let danger = Color("Danger")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let background = Color("AppBackground")
    static let surface = Color("Surface")
    static let surfaceMuted = Color("SurfaceMuted")
    static let border = Color("Border")
    static let tabInactive = Color("TabInactive")
    static let accentSurface = Color("AccentSurface")
    static let dangerSurface = Color("DangerSurface")
}

enum AppTypography {
    static let pageTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let navigationTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyStrong = Font.system(size: 16, weight: .semibold, design: .default)
    static let caption = Font.system(size: 13, weight: .medium, design: .default)
    static let button = Font.system(size: 16, weight: .semibold, design: .default)
    static let tabLabel = Font.system(size: 11, weight: .medium, design: .default)
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}
