import SwiftUI

struct SystemPreferencesView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "System Preferences",
                subtitle: "App permissions, support and diagnostics",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "App Preferences")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: "bell.badge",
                            title: "Notifications",
                            action: {
                                store.show(.notificationSettings)
                            }
                        )
                        .accessibility(identifier: "settings-row-notifications")

                        SettingsNavigationRow(
                            iconName: "shield",
                            title: "System Permissions",
                            showsDivider: false,
                            action: {
                                store.show(.systemPermissions)
                            }
                        )
                        .accessibility(identifier: "settings-row-system-permissions")
                    }

                    SettingsSectionHeader(title: "Support")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: "questionmark.circle",
                            title: "Help Center",
                            showsDivider: false,
                            action: {
                                store.show(.helpCenter)
                            }
                        )
                        .accessibility(identifier: "settings-row-help-center")
                    }

                    SettingsSectionHeader(title: "Diagnostics & Maintenance")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: "square.and.arrow.up",
                            title: "Share Anonymous Logs",
                            subtitle: "Helps us improve app stability",
                            isOn: shareAnonymousLogsBinding,
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "About")
                    SettingsGroupCard {
                        SettingsStatusRow(
                            iconName: "info.circle",
                            title: "App Version",
                            statusText: appVersionText
                        )

                        SettingsNavigationRow(
                            iconName: "hand.raised",
                            title: "Privacy Policy",
                            trailingSystemImage: "arrow.up.right.square"
                        )

                        SettingsNavigationRow(
                            iconName: "doc.text",
                            title: "Terms of Service",
                            trailingSystemImage: "arrow.up.right.square",
                            showsDivider: false
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-system-preferences")
    }

    private var shareAnonymousLogsBinding: Binding<Bool> {
        Binding(
            get: { store.shareAnonymousLogs },
            set: { store.setShareAnonymousLogs($0) }
        )
    }

    private var appVersionText: String {
        guard let rawVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              rawVersion.isEmpty == false,
              rawVersion.contains("$(") == false else {
            return "v1.0"
        }

        return "v\(rawVersion)"
    }
}
