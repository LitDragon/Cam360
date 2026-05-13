import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var store: SettingsStore
    var dismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Notification Settings",
                eyebrow: "Settings",
                leadingSystemImage: "arrow.left",
                leadingAction: dismissAction
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    NotificationSettingsSection(title: "Safety Alerts") {
                        NotificationSettingsToggleRow(
                            title: "Emergency Event Notifications",
                            subtitle: "Instant alerts for heavy braking or impact",
                            isOn: binding(for: \.emergencyEventNotifications)
                        )

                        NotificationSettingsToggleRow(
                            title: "Collision Alerts",
                            subtitle: "Real-time forward collision warnings",
                            isOn: binding(for: \.collisionAlerts)
                        )

                        NotificationSettingsToggleRow(
                            title: "Parking Incident Alerts",
                            subtitle: "Notify when motion is detected while parked",
                            isOn: binding(for: \.parkingIncidentAlerts),
                            showsDivider: false
                        )
                    }

                    NotificationSettingsSection(title: "Notification Delivery") {
                        NotificationSettingsToggleRow(
                            title: "Push Notifications",
                            subtitle: "Master switch for all mobile alerts",
                            isOn: binding(for: \.pushNotifications)
                        )

                        NotificationSettingsToggleRow(
                            title: "Sound for Notifications",
                            isOn: binding(for: \.soundForNotifications),
                            showsDivider: false
                        )
                    }

                    NotificationSettingsSection(title: "Quiet Hours") {
                        NotificationSettingsToggleRow(
                            title: "Enable Quiet Hours",
                            subtitle: "Silence non-critical alerts during specific times",
                            isOn: binding(for: \.quietHoursEnabled),
                            showsDivider: false
                        )

                        HStack(spacing: AppSpacing.md) {
                            SettingsTimeField(
                                title: "Start Time",
                                value: store.notificationPreferences.quietHoursStart
                            )

                            SettingsTimeField(
                                title: "End Time",
                                value: store.notificationPreferences.quietHoursEnd
                            )
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)
                        .opacity(store.notificationPreferences.quietHoursEnabled ? 1 : 0.48)
                    }

                    SettingsFootnote(
                        text: "Critical safety alerts like Emergency Event Notifications and Collision Alerts bypass Quiet Hours to ensure your security is never compromised.",
                        iconAssetName: "Info"
                    )
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-notification-settings")
    }

    private func binding(for keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPreferences[keyPath: keyPath] },
            set: { store.setNotificationPreference(keyPath, to: $0) }
        )
    }

    private func dismissAction() {
        if let dismiss = dismiss {
            dismiss()
        } else {
            store.dismissRoute()
        }
    }
}

private struct NotificationSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(Color(hex: "#424655"))
                .frame(maxWidth: .infinity, alignment: .leading)

            SettingsGroupCard {
                content
            }
        }
    }
}

private struct NotificationSettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var showsDivider: Bool = true

    var body: some View {
        SettingsToggleRow(
            iconName: nil,
            title: title,
            subtitle: subtitle,
            isOn: $isOn,
            showsDivider: showsDivider,
            titleFont: .system(size: 14, weight: .semibold, design: .default),
            subtitleFont: .system(size: 12, weight: .medium, design: .default),
            subtitleColor: Color(hex: "#424655")
        )
    }
}
