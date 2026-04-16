import SwiftUI

struct MediaListItem: View {
    let title: String
    let subtitle: String
    let duration: String
    var badgeTitle: String? = nil
    var badgeTone: StatusTagTone = .accent

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0),
                                Color(red: 30.0 / 255.0, green: 41.0 / 255.0, blue: 59.0 / 255.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 72)

                if let badgeTitle = badgeTitle {
                    StatusTag(title: badgeTitle, tone: badgeTone)
                        .padding(AppSpacing.xs)
                }

                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Text(duration)
                            .font(AppTypography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(AppRadius.small)
                            .padding(AppSpacing.xs)
                    }
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 104, height: 72)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
    }
}
