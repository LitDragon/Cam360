import SwiftUI

struct SafetySettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Safety",
                subtitle: "Collision sensitivity and protected event rules",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Collision Detection")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "G-Sensor Sensitivity",
                            options: SafetySensitivityOption.allCases,
                            selection: binding(for: \.gSensorSensitivity),
                            titleForOption: { $0.rawValue }
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Emergency Video Lock",
                            subtitle: "Protect impact recordings from overwrite.",
                            isOn: binding(for: \.emergencyVideoLockEnabled),
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Motion Surveillance")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: nil,
                            title: "Parking Mode",
                            subtitle: "Monitor the vehicle when ignition is off.",
                            isOn: binding(for: \.parkingModeEnabled)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Motion Detection",
                            isOn: binding(for: \.motionDetectionEnabled)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Impact Detection",
                            isOn: binding(for: \.impactDetectionEnabled),
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Event Recording")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "Clip Duration",
                            options: EventClipDurationOption.allCases,
                            selection: binding(for: \.eventClipDuration),
                            titleForOption: { $0.rawValue }
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Event Notifications",
                            isOn: binding(for: \.eventNotificationsEnabled),
                            showsDivider: false
                        )
                    }

                    SettingsNoticeCard(
                        title: "Reset Safety Defaults",
                        message: "Restores sensitivity, event clip duration and surveillance toggles to the local baseline.",
                        tone: .danger,
                        iconName: "exclamationmark.triangle"
                    )

                    DestructiveButton(title: "Reset Safety Defaults") {
                        store.restoreSafetyDefaults()
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-safety")
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<SafetySettingsState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.safetySettings[keyPath: keyPath] },
            set: { store.updateSafetySetting(keyPath, to: $0) }
        )
    }
}
