import SwiftUI

enum AppColor {
    static let main = Color("Main")
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
    static let dashboardPreviewPill: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

enum AppLayout {
    static let hairline: CGFloat = 1
    static let mainTabReservedBottomInset: CGFloat = 108
    static let scrollBottomContentInset: CGFloat = 140
    static let iconButton: CGFloat = 36
    static let compactIconButton: CGFloat = 32
    static let dashboardPreviewHeight: CGFloat = 214
    static let dashboardPreviewPillDotSize: CGFloat = 6
    static let dashboardPreviewPillVerticalPadding: CGFloat = 7
    static let dashboardPreviewLaneDash: [CGFloat] = [14, 18]
    static let dashboardPreviewRoadEdgeWidth: CGFloat = 4
    static let dashboardPreviewLaneDividerWidth: CGFloat = 4
    static let dashboardPreviewLaneHighlightWidth: CGFloat = 2
    static let dashboardPreviewLaneMarkerWidth: CGFloat = 3
    static let dashboardDrawerWidth: CGFloat = 300
    static let galleryThumbnailSize = CGSize(width: 128, height: 78)
    static let mediaThumbnailSize = CGSize(width: 104, height: 72)
    static let progressLineHeight: CGFloat = 6
    static let settingsProgressHeight: CGFloat = 12
}

enum AppShadow {
    static let dashboardPreview = ShadowStyle(
        color: Color.black.opacity(0.16),
        radius: 20,
        x: 0,
        y: 12
    )
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppArtworkPalette {
    static let dashboardPreviewBackground = [
        Color(red: 0.15, green: 0.56, blue: 0.9),
        Color(red: 0.14, green: 0.43, blue: 0.82),
        Color(red: 0.1, green: 0.23, blue: 0.44)
    ]
    static let dashboardPreviewLeftTerrain = [
        Color(red: 0.77, green: 0.62, blue: 0.35),
        Color(red: 0.45, green: 0.33, blue: 0.2)
    ]
    static let dashboardPreviewRightTerrain = [
        Color(red: 0.07, green: 0.48, blue: 0.76),
        Color(red: 0.03, green: 0.28, blue: 0.52)
    ]
    static let dashboardPreviewRoad = [
        Color(red: 0.42, green: 0.43, blue: 0.45),
        Color(red: 0.2, green: 0.21, blue: 0.23)
    ]
    static let dashboardPreviewRoadEdge = Color(red: 0.24, green: 0.23, blue: 0.19)
    static let dashboardPreviewLaneMarker = Color(red: 0.93, green: 0.8, blue: 0.16)
    static let dashboardPreviewOverlayStroke = Color.white.opacity(0.08)
    static let dashboardPreviewTimestamp = Color.white.opacity(0.84)
    static let dashboardPreviewLaneDivider = Color.white.opacity(0.92)
    static let dashboardPreviewLaneHighlight = Color.white.opacity(0.86)
    static let dashboardPreviewPillBackground = Color.black.opacity(0.42)
    static let dashboardEventVehicle = [
        Color(red: 0.72, green: 0.63, blue: 0.59),
        Color(red: 0.37, green: 0.34, blue: 0.36)
    ]
    static let dashboardEventLandscape = [
        Color(red: 0.42, green: 0.75, blue: 0.82),
        Color(red: 0.23, green: 0.45, blue: 0.28)
    ]
    static let dashboardEventNightDrive = [
        Color(red: 0.24, green: 0.39, blue: 0.57),
        Color(red: 0.08, green: 0.11, blue: 0.2)
    ]
    static let dashboardEventParking = [
        Color(red: 0.53, green: 0.75, blue: 0.48),
        Color(red: 0.21, green: 0.43, blue: 0.24)
    ]
    static let dashboardDeviceBody = [
        Color(red: 0.54, green: 0.58, blue: 0.66),
        Color(red: 0.34, green: 0.37, blue: 0.45)
    ]
    static let dashboardFeatureBackground = [
        Color(red: 0.97, green: 0.98, blue: 1.0),
        Color(red: 0.93, green: 0.95, blue: 1.0)
    ]
    static let dashboardFeatureCameraBody = [
        Color(red: 0.2, green: 0.23, blue: 0.28),
        Color(red: 0.08, green: 0.09, blue: 0.13)
    ]
    static let dashboardFeatureCameraScreen = [
        Color(red: 0.34, green: 0.47, blue: 0.58),
        Color(red: 0.15, green: 0.17, blue: 0.21)
    ]
    static let dashboardFeaturePhoneBody = Color(red: 0.97, green: 0.97, blue: 1.0)
    static let galleryEmergencyBrake = [
        Color(red: 0.09, green: 0.20, blue: 0.32),
        Color(red: 0.36, green: 0.52, blue: 0.72)
    ]
    static let galleryDailyRecording = [
        Color(red: 0.13, green: 0.32, blue: 0.29),
        Color(red: 0.47, green: 0.67, blue: 0.40)
    ]
    static let galleryParkingMonitor = [
        Color(red: 0.34, green: 0.25, blue: 0.15),
        Color(red: 0.72, green: 0.57, blue: 0.34)
    ]
    static let gallerySnapshot = [
        Color(red: 0.11, green: 0.25, blue: 0.20),
        Color(red: 0.45, green: 0.66, blue: 0.53)
    ]
    static let galleryRushHour = [
        Color(red: 0.18, green: 0.16, blue: 0.33),
        Color(red: 0.51, green: 0.35, blue: 0.63)
    ]
    static let galleryCollisionAlert = [
        Color(red: 0.35, green: 0.12, blue: 0.18),
        Color(red: 0.76, green: 0.33, blue: 0.28)
    ]
    static let mediaPlaceholder = [
        Color(red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0),
        Color(red: 30.0 / 255.0, green: 41.0 / 255.0, blue: 59.0 / 255.0)
    ]
}
