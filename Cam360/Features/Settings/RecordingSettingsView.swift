import SwiftUI

struct RecordingSettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Recording Settings",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    RecordingSettingsSection(title: "Video Quality") {
                        RecordingSettingsCard {
                            VStack(alignment: .leading, spacing: 26) {
                                RecordingSegmentedRow(
                                    title: "Resolution",
                                    options: RecordingResolutionOption.allCases,
                                    selection: binding(for: \.resolution),
                                    titleForOption: { $0.rawValue }
                                )

                                RecordingSegmentedRow(
                                    title: "Recording Quality Priority",
                                    options: RecordingQualityPriorityOption.allCases,
                                    selection: binding(for: \.qualityPriority),
                                    titleForOption: { $0.rawValue }
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                        }
                    }

                    RecordingSettingsSection(title: "Recording Behavior") {
                        RecordingSettingsCard {
                            VStack(alignment: .leading, spacing: 26) {
                                RecordingSegmentedRow(
                                    title: "Loop Recording",
                                    options: LoopRecordingDurationOption.allCases,
                                    selection: binding(for: \.loopDuration),
                                    titleForOption: { $0.rawValue }
                                )

                                RecordingToggleRow(
                                    title: "Auto Overwrite",
                                    subtitle: "Delete oldest files when storage is full",
                                    isOn: binding(for: \.autoOverwrite)
                                )

                                RecordingSegmentedRow(
                                    title: "Recording Start Behavior",
                                    options: RecordingStartBehaviorOption.allCases,
                                    selection: binding(for: \.startBehavior),
                                    titleForOption: { $0.rawValue }
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                        }
                    }

                    RecordingSettingsSection(title: "Audio & Visibility") {
                        RecordingSettingsCard {
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
                    }

                    RecordingStorageEstimateView(text: "Estimated storage per hour: ~4.2 GB")
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, 40)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
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

private struct RecordingSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.xs)

            content
        }
    }
}

private struct RecordingSettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.border.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 6)
    }
}

private struct RecordingSegmentedRow<Option: Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let titleForOption: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundColor(AppColor.textPrimary)

            RecordingSegmentedControl(
                options: options,
                selection: $selection,
                titleForOption: titleForOption
            )
        }
    }
}

private struct RecordingSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let titleForOption: (Option) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    selection = option
                }) {
                    ZStack {
                        if selection == option {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AppColor.brand)
                        }

                        Text(titleForOption(option))
                            .font(.system(size: 14, weight: selection == option ? .semibold : .medium, design: .default))
                            .foregroundColor(selection == option ? .white : AppColor.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 37)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, minHeight: 37)
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .frame(height: 45)
        .background(Color(hex: "#E8E8F4"))
        .cornerRadius(7)
    }
}

private struct RecordingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "#8B8E9C"))
            }

            Spacer(minLength: AppSpacing.md)

            Group {
                if #available(iOS 14.0, *) {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: AppColor.brand))
                } else {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                }
            }
        }
    }
}

private struct RecordingStorageEstimateView: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(AppColor.brand)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(Color(hex: "#0053B8"))
                .lineLimit(1)
        }
        .padding(.leading, 20)
        .padding(.trailing, AppSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 51, alignment: .leading)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(Color(hex: "#E1E8FF"))

                Rectangle()
                    .fill(AppColor.brand)
                    .frame(width: 4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
    }
}
