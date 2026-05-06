import SwiftUI

extension View {
    func appSurface(
        backgroundColor: Color = AppColor.surface,
        cornerRadius: CGFloat = AppRadius.medium,
        borderColor: Color? = AppColor.border.opacity(0.7),
        borderWidth: CGFloat = AppLayout.hairline,
        shadow: ShadowStyle? = nil
    ) -> some View {
        modifier(
            AppSurfaceModifier(
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                borderWidth: borderWidth,
                shadow: shadow
            )
        )
    }
}

private struct AppSurfaceModifier: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let borderColor: Color?
    let borderWidth: CGFloat
    let shadow: ShadowStyle?

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                Group {
                    if let borderColor = borderColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: borderWidth)
                    }
                }
            )
            .shadow(
                color: shadow?.color ?? .clear,
                radius: shadow?.radius ?? 0,
                x: shadow?.x ?? 0,
                y: shadow?.y ?? 0
            )
    }
}
