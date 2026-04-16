import SwiftUI

struct MainTabBar: View {
    let selectedTab: MainTab
    let onSelect: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button(action: {
                    onSelect(tab)
                }) {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: tab.systemImageName)
                            .font(.system(size: 18, weight: .semibold))

                        Text(tab.title)
                            .font(AppTypography.tabLabel)
                    }
                    .foregroundColor(color(for: tab))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibility(identifier: tab.accessibilityIdentifier)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColor.surface.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColor.border.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 6)
        )
    }

    private func color(for tab: MainTab) -> Color {
        selectedTab == tab ? AppColor.brand : AppColor.tabInactive
    }
}
