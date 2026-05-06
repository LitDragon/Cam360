import SwiftUI

struct AppProgressBar: View {
    let progress: CGFloat
    var height: CGFloat = AppLayout.progressLineHeight
    var minimumFillWidth: CGFloat = 0
    var trackColor: Color = AppColor.border.opacity(0.5)
    var fillColor: Color = AppColor.brand
    var cornerRadius: CGFloat? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(trackColor)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(fillColor)
                    .frame(
                        width: max(geometry.size.width * clampedProgress, minimumFillWidth),
                        height: height
                    )
            }
        }
        .frame(height: height)
    }

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var resolvedCornerRadius: CGFloat {
        cornerRadius ?? height / 2
    }
}
