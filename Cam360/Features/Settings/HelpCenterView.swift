import SwiftUI

struct HelpCenterView: View {
    @ObservedObject var store: SettingsStore
    @State private var searchText = ""

    private let topicItems: [HelpCenterItem] = [
        HelpCenterItem(iconName: "slider.horizontal.3", title: "Connect Device"),
        HelpCenterItem(iconName: "eye", title: "Live Preview Issues"),
        HelpCenterItem(iconName: "sdcard", title: "SD Card & Storage"),
        HelpCenterItem(iconName: "video", title: "Recording & Events"),
        HelpCenterItem(iconName: "wifi", title: "Wi-Fi & Connection"),
        HelpCenterItem(iconName: "arrow.down.doc", title: "Firmware Update")
    ]

    private let quickActionItems: [HelpCenterItem] = [
        HelpCenterItem(iconName: "questionmark.square", title: "FAQ"),
        HelpCenterItem(iconName: "person.crop.circle.badge.questionmark", title: "Contact Support")
    ]

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Help Center",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("Find answers and troubleshooting help")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)

                    SettingsSearchBar(
                        text: $searchText,
                        placeholder: "Search help articles"
                    )

                    SettingsSectionHeader(title: "Help Topics")
                    helpCard(for: topicItems)

                    SettingsSectionHeader(title: "Quick Actions")
                    helpCard(for: quickActionItems)

                    HStack(spacing: 0) {
                        Text("Still need help? ")
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)

                        Text("Contact support")
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.brand)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-help-center")
    }

    private func helpCard(for items: [HelpCenterItem]) -> some View {
        SettingsGroupCard {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                SettingsNavigationRow(
                    iconName: item.iconName,
                    title: item.title,
                    showsDivider: index < items.count - 1
                )
            }
        }
    }
}

private struct HelpCenterItem {
    let iconName: String
    let title: String
}
