import SwiftUI

private enum SystemPreferencesRoute: Hashable {
    case notificationSettings
    case systemPermissions
    case helpCenter
    case privacyPolicy
    case termsOfService
}

struct SystemPreferencesView: View {
    @ObservedObject var store: SettingsStore
    let title: String
    let subtitle: String
    let dismiss: (() -> Void)?

    @State private var route: SystemPreferencesRoute?

    init(
        store: SettingsStore,
        title: String = "System Preferences",
        subtitle: String = "App permissions, support and diagnostics",
        dismiss: (() -> Void)? = nil
    ) {
        self.store = store
        self.title = title
        self.subtitle = subtitle
        self.dismiss = dismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: title,
                subtitle: subtitle,
                leadingSystemImage: dismiss == nil ? nil : "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    settingsSection(title: "App Preferences") {
                        SettingsNavigationRow(
                            iconName: nil,
                            iconAssetName: "Notification",
                            title: "Notifications",
                            action: {
                                route = .notificationSettings
                            }
                        )
                        .accessibility(identifier: "settings-row-notifications")

                        SettingsNavigationRow(
                            iconName: nil,
                            iconAssetName: "SystemPermissions",
                            title: "System Permissions",
                            showsDivider: false,
                            action: {
                                route = .systemPermissions
                            }
                        )
                        .accessibility(identifier: "settings-row-system-permissions")
                    }

                    settingsSection(title: "Support") {
                        SettingsNavigationRow(
                            iconName: nil,
                            iconAssetName: "helpCenter",
                            title: "Help Center",
                            showsDivider: false,
                            action: {
                                route = .helpCenter
                            }
                        )
                        .accessibility(identifier: "settings-row-help-center")
                    }

                    settingsSection(title: "Diagnostics & Maintenance") {
                        SettingsToggleRow(
                            iconName: nil,
                            iconAssetName: "ShareLogs",
                            title: "Share Anonymous Logs",
                            subtitle: "Helps us improve app stability",
                            isOn: shareAnonymousLogsBinding,
                            showsDivider: false
                        )
                    }

                    settingsSection(title: "About") {
                        SettingsStatusRow(
                            iconName: nil,
                            iconAssetName: "AppVersion",
                            title: "App Version",
                            statusText: store.appVersionText
                        )

                        SettingsNavigationRow(
                            iconName: nil,
                            iconAssetName: "PrivacyPolicy",
                            title: "Privacy Policy",
                            trailingIconAssetName: "MoreArrow",
                            action: {
                                route = .privacyPolicy
                            }
                        )

                        SettingsNavigationRow(
                            iconName: nil,
                            iconAssetName: "Terms",
                            title: "Terms of Service",
                            trailingIconAssetName: "MoreArrow",
                            showsDivider: false
                        ) {
                            route = .termsOfService
                        }
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

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SettingsSectionHeader(title: title)
            SettingsGroupCard {
                content()
            }
        }
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

            NavigationLink(
                destination: LegalPlaceholderView(
                    title: "Privacy Policy",
                    subtitle: "隐私政策",
                    summaryTitle: "隐私正文待提供",
                    summaryMessage: "业务文档仅明确当前产品不收集用户隐私信息；正式隐私政策正文尚未提供。",
                    dismiss: dismissNestedRoute
                )
                .navigationBarHidden(true),
                tag: .privacyPolicy,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: LegalPlaceholderView(
                    title: "Terms of Service",
                    subtitle: "服务条款",
                    summaryTitle: "服务条款待提供",
                    summaryMessage: "业务文档尚未提供正式服务条款正文。本页只保留入口形态，不补写法律条款。",
                    dismiss: dismissNestedRoute
                )
                .navigationBarHidden(true),
                tag: .termsOfService,
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

private struct LegalPlaceholderView: View {
    let title: String
    let subtitle: String
    let summaryTitle: String
    let summaryMessage: String
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: title,
                subtitle: subtitle,
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Document Status")
                    SettingsGroupCard {
                        SettingsStatusRow(
                            iconName: "doc.text",
                            title: "Content Source",
                            subtitle: "Awaiting business copy",
                            statusText: "Pending",
                            showsDivider: false
                        )
                    }

                    SettingsNoticeCard(
                        title: summaryTitle,
                        message: summaryMessage,
                        tone: .info,
                        iconName: "info.circle"
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-legal-placeholder")
    }
}
