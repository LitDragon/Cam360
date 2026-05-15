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
                    SafetySettingsSection(title: "Collision Detection") {
                        SettingsGroupCard {
                            SettingsSegmentedRow(
                                title: "G-Sensor Sensitivity",
                                options: SafetySensitivityOption.allCases,
                                selection: binding(for: \.gSensorSensitivity),
                                titleForOption: { $0.rawValue },
                                showsDivider: false
                            )

                            SettingsToggleRow(
                                iconName: nil,
                                title: "Emergency Video Lock",
                                subtitle: "Protect impact recordings from overwrite.",
                                isOn: binding(for: \.emergencyVideoLockEnabled),
                                showsDivider: false
                            )
                        }
                    }

                    SafetySettingsSection(title: "Parking Surveillance") {
                        SettingsGroupCard {
                            SettingsToggleRow(
                                iconName: nil,
                                title: "Parking Mode",
                                subtitle: "Monitor vehicle while parked.",
                                isOn: binding(for: \.parkingModeEnabled),
                                showsDivider: false
                            )

                            SettingsToggleRow(
                                iconName: nil,
                                title: "Motion Detection",
                                subtitle: "Record movement around car.",
                                isOn: binding(for: \.motionDetectionEnabled),
                                showsDivider: false
                            )

                            SettingsToggleRow(
                                iconName: nil,
                                title: "Impact Detection",
                                subtitle: "Wake and record on bump.",
                                isOn: binding(for: \.impactDetectionEnabled),
                                showsDivider: false
                            )
                        }
                    }

                    SafetySettingsSection(title: "Event Recording") {
                        SettingsGroupCard {
                            SettingsSegmentedRow(
                                title: "Clip Duration",
                                options: EventClipDurationOption.allCases,
                                selection: binding(for: \.eventClipDuration),
                                titleForOption: { $0.rawValue },
                                showsDivider: false
                            )
                        }
                    }

                    SafetySettingsSection(title: "Notifications") {
                        SettingsGroupCard {
                            SettingsToggleRow(
                                iconName: nil,
                                title: "Event Notifications",
                                subtitle: "Receive alerts for safety events.",
                                isOn: binding(for: \.eventNotificationsEnabled),
                                showsDivider: false
                            )
                        }
                    }

                    SafetyResetButton(title: "Reset Safety Defaults") {
                        store.restoreSafetyDefaults()
                    }
                    .padding(.top, AppSpacing.md)

                    SafetyResetFootnote(
                        text: "This will revert all collision sensitivity, parking surveillance, and notification settings to factory defaults."
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxxl)
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

private struct SafetySettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SettingsSectionHeader(title: title)
            content
        }
    }
}

private struct SafetyResetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
            }
            .foregroundColor(AppColor.danger)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppColor.dangerSurface)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SafetyResetFootnote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColor.danger)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(Color(hex: "#737687"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.sm)
    }
}
