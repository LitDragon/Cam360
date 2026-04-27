import SwiftUI

private enum SystemPreferencesRoute: Hashable {
    case notificationSettings
    case systemPermissions
    case helpCenter
}

struct SystemPreferencesView: View {
    @ObservedObject var store: SettingsStore
    @State private var route: SystemPreferencesRoute?

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
                                route = .notificationSettings
                            }
                        )
                        .accessibility(identifier: "settings-row-notifications")

                        SettingsNavigationRow(
                            iconName: "shield",
                            title: "System Permissions",
                            showsDivider: false,
                            action: {
                                route = .systemPermissions
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
                                route = .helpCenter
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
                            statusText: store.appVersionText
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
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .background(navigationLinks)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-system-preferences")
    }

    private var routeBinding: Binding<SystemPreferencesRoute?> {
        Binding(
            get: { route },
            set: { route = $0 }
        )
    }

    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: NotificationSettingsView(store: store, dismiss: dismissNestedRoute)
                    .navigationBarHidden(true),
                tag: .notificationSettings,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: SystemPermissionsView(store: store, dismiss: dismissNestedRoute)
                    .navigationBarHidden(true),
                tag: .systemPermissions,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: HelpCenterView(store: store, dismiss: dismissNestedRoute)
                    .navigationBarHidden(true),
                tag: .helpCenter,
                selection: routeBinding
            ) {
                EmptyView()
            }
        }
        .hidden()
    }

    private var shareAnonymousLogsBinding: Binding<Bool> {
        Binding(
            get: { store.shareAnonymousLogs },
            set: { store.setShareAnonymousLogs($0) }
        )
    }

    private func dismissNestedRoute() {
        route = nil
    }
}
