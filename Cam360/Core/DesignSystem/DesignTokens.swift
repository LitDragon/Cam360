import SwiftUI

enum AppColor {
    static let brand = Color(red: 37.0 / 255.0, green: 99.0 / 255.0, blue: 235.0 / 255.0)
    static let success = Color(red: 22.0 / 255.0, green: 163.0 / 255.0, blue: 74.0 / 255.0)
    static let warning = Color(red: 245.0 / 255.0, green: 158.0 / 255.0, blue: 11.0 / 255.0)
    static let danger = Color(red: 220.0 / 255.0, green: 38.0 / 255.0, blue: 38.0 / 255.0)
    static let textPrimary = Color(red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0)
    static let textSecondary = Color(red: 100.0 / 255.0, green: 116.0 / 255.0, blue: 139.0 / 255.0)
    static let background = Color(red: 248.0 / 255.0, green: 250.0 / 255.0, blue: 252.0 / 255.0)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 249.0 / 255.0)
    static let border = Color(red: 226.0 / 255.0, green: 232.0 / 255.0, blue: 240.0 / 255.0)
    static let tabInactive = Color(red: 148.0 / 255.0, green: 163.0 / 255.0, blue: 184.0 / 255.0)
    static let accentSurface = Color(red: 239.0 / 255.0, green: 246.0 / 255.0, blue: 255.0 / 255.0)
    static let dangerSurface = Color(red: 254.0 / 255.0, green: 226.0 / 255.0, blue: 226.0 / 255.0)
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
