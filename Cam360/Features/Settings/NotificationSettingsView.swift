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
                            NotificationSettingsTimePickerField(
                                title: "Start Time",
                                value: store.notificationPreferences.quietHoursStart,
                                selection: timeBinding(for: \.quietHoursStart),
                                isEnabled: store.notificationPreferences.quietHoursEnabled
                            )
                            .frame(maxWidth: .infinity)

                            NotificationSettingsTimePickerField(
                                title: "End Time",
                                value: store.notificationPreferences.quietHoursEnd,
                                selection: timeBinding(for: \.quietHoursEnd),
                                isEnabled: store.notificationPreferences.quietHoursEnabled
                            )
                            .frame(maxWidth: .infinity)
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

    private func timeBinding(for keyPath: WritableKeyPath<NotificationPreferences, String>) -> Binding<Date> {
        Binding(
            get: {
                QuietHoursTimeFormatter.date(from: store.notificationPreferences[keyPath: keyPath]) ?? Date()
            },
            set: {
                store.setNotificationPreference(keyPath, to: QuietHoursTimeFormatter.string(from: $0))
            }
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

private enum QuietHoursTimeFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func date(from value: String) -> Date? {
        formatter.date(from: value)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

private struct NotificationSettingsTimePickerField: View {
    let title: String
    let value: String
    @Binding var selection: Date
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)

            ZStack {
                timeFieldBody
                    .allowsHitTesting(false)

                if #available(iOS 14.0, *) {
                    DatePicker(
                        title,
                        selection: $selection,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.02)
                }
            }
            .disabled(isEnabled == false)
        }
    }

    private var timeFieldBody: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundColor(AppColor.textPrimary)

            Spacer(minLength: 0)

            Image(systemName: "clock")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.small)
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
                .foregroundColor(AppColor.textPrimary)
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
            subtitleColor: AppColor.textPrimary
        )
    }
}
