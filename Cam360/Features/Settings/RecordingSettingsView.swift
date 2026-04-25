import SwiftUI

struct RecordingSettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Recording Settings",
                subtitle: "Video quality and capture behavior",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Video Quality")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "Resolution",
                            options: RecordingResolutionOption.allCases,
                            selection: binding(for: \.resolution),
                            titleForOption: { $0.rawValue }
                        )

                        SettingsSegmentedRow(
                            title: "Recording Quality Priority",
                            subtitle: "Choose whether the device prioritizes image quality or storage efficiency.",
                            options: RecordingQualityPriorityOption.allCases,
                            selection: binding(for: \.qualityPriority),
                            titleForOption: { $0.rawValue },
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Recording Behavior")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "Loop Recording",
                            options: LoopRecordingDurationOption.allCases,
                            selection: binding(for: \.loopDuration),
                            titleForOption: { $0.rawValue }
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Auto Overwrite",
                            subtitle: "When storage is full, overwrite the oldest unlocked recordings first.",
                            isOn: binding(for: \.autoOverwrite)
                        )

                        SettingsSegmentedRow(
                            title: "Recording Start Behavior",
                            options: RecordingStartBehaviorOption.allCases,
                            selection: binding(for: \.startBehavior),
                            titleForOption: { $0.rawValue },
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Audio & Visibility")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: nil,
                            title: "Audio Recording",
                            isOn: binding(for: \.audioRecordingEnabled)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "HDR / Night Recording",
                            isOn: binding(for: \.hdrNightRecordingEnabled)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Recording Status Indicator",
                            isOn: binding(for: \.recordingStatusIndicatorEnabled)
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Recording Reminder",
                            isOn: binding(for: \.recordingReminderEnabled),
                            showsDivider: false
                        )
                    }

                    SettingsFootnote(
                        text: "Estimated storage per hour: ~4.2 GB at the current local preview configuration."
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
        .accessibility(identifier: "screen-settings-recording-settings")
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<RecordingSettingsState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.recordingSettings[keyPath: keyPath] },
            set: { store.updateRecordingSetting(keyPath, to: $0) }
        )
    }
}
