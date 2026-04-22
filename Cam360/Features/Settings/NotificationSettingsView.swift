import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Notification Settings",
                eyebrow: "Settings",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Safety Alerts")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: nil,
                            title: "Emergency Event Notifications",
                            subtitle: "Instant alerts for heavy braking or impact",
                            isOn: binding(for: \.emergencyEventNotifications)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Collision Alerts",
                            subtitle: "Real-time forward collision warnings",
                            isOn: binding(for: \.collisionAlerts)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Parking Incident Alerts",
                            subtitle: "Notify when motion is detected while parked",
                            isOn: binding(for: \.parkingIncidentAlerts),
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Notification Delivery")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: nil,
                            title: "Push Notifications",
                            subtitle: "Master switch for all mobile alerts",
                            isOn: binding(for: \.pushNotifications)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Sound for Notifications",
                            isOn: binding(for: \.soundForNotifications),
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Quiet Hours")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: nil,
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
                        text: "Critical safety alerts like Emergency Event Notifications and Collision Alerts bypass Quiet Hours to ensure your security is never compromised."
                    )
                    .padding(.horizontal, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
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
}
