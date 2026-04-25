import SwiftUI

private enum DeviceSettingsDetailRoute: Hashable {
    case networkIdentity
    case firmwareUpdate
}

struct DeviceSettingsDetailView: View {
    @ObservedObject var store: SettingsStore
    @State private var route: DeviceSettingsDetailRoute?

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Device Settings",
                subtitle: "Identity, software and maintenance controls",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Device Identity")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: nil,
                            title: "Device Name",
                            subtitle: store.devicePreferences.deviceName,
                            action: {
                                store.show(.renameDevice)
                            }
                        )

                        SettingsValueRow(
                            iconName: nil,
                            title: "Connectivity",
                            subtitle: "Current Wi-Fi profile",
                            valueText: store.devicePreferences.connectionName,
                            trailingSystemImage: "chevron.right",
                            showsDivider: false,
                            action: {
                                route = .networkIdentity
                            }
                        )
                    }

                    SettingsSectionHeader(title: "Software")
                    SettingsGroupCard {
                        SettingsActionRow(
                            iconName: nil,
                            title: "Firmware Version",
                            subtitle: store.devicePreferences.firmwareVersion,
                            actionTitle: "Check for Updates",
                            showsDivider: false,
                            action: {
                                route = .firmwareUpdate
                            }
                        )
                    }

                    SettingsSectionHeader(title: "Localization")
                    SettingsGroupCard {
                        SettingsValueRow(
                            iconName: nil,
                            title: "Time Zone",
                            valueText: store.devicePreferences.timeZone
                        )

                        SettingsValueRow(
                            iconName: nil,
                            title: "Date & Time",
                            valueText: store.devicePreferences.dateTime,
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Audio Controls")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "Speaker Volume",
                            options: SpeakerVolumeOption.allCases,
                            selection: deviceBinding(for: \.speakerVolume),
                            titleForOption: { $0.rawValue }
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Status Sounds",
                            isOn: deviceBinding(for: \.statusSoundsEnabled),
                            showsDivider: false
                        )
                    }

                    SettingsNoticeCard(
                        title: "Factory Reset",
                        message: "Resets local device-facing settings in this M0 shell. It does not touch onboarding or app-level preferences.",
                        tone: .danger,
                        iconName: "exclamationmark.triangle"
                    )

                    DestructiveButton(title: "Factory Reset") {
                        store.restoreDefaultDeviceConfiguration()
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .background(navigationLinks)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-device-settings")
    }

    private var routeBinding: Binding<DeviceSettingsDetailRoute?> {
        Binding(
            get: { route },
            set: { route = $0 }
        )
    }

    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: NetworkIdentityView(
                    store: store,
                    dismiss: {
                        route = nil
                    }
                )
                .navigationBarHidden(true),
                tag: .networkIdentity,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: FirmwareUpdateView(
                    store: store,
                    dismiss: {
                        route = nil
                    }
                )
                .navigationBarHidden(true),
                tag: .firmwareUpdate,
                selection: routeBinding
            ) {
                EmptyView()
            }
        }
        .hidden()
    }

    private func deviceBinding<Value>(
        for keyPath: WritableKeyPath<DevicePreferencesState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.devicePreferences[keyPath: keyPath] },
            set: { store.updateDevicePreferences(keyPath, to: $0) }
        )
    }
}

private struct NetworkIdentityView: View {
    @ObservedObject var store: SettingsStore
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Network Identity",
                subtitle: "Update the Wi-Fi name and credentials used by this device.",
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Current Connection")
                    SettingsGroupCard {
                        SettingsInputRow(
                            title: "Network Name",
                            text: networkBinding(for: \.networkName),
                            placeholder: "Vigilant_Dash_4K"
                        )

                        SettingsInputRow(
                            title: "Password",
                            text: networkBinding(for: \.password),
                            placeholder: "Password",
                            fieldKind: .secure,
                            showsDivider: false
                        )
                    }

                    SettingsNoticeCard(
                        title: "Important Notice",
                        message: "The dashcam will reboot to apply these changes. Save only when you are ready to reconnect to the new network.",
                        tone: .warning,
                        iconName: "exclamationmark.triangle"
                    )

                    PrimaryButton(title: "Save Changes") {
                        store.commitNetworkIdentityChanges()
                        dismiss()
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-network-identity")
    }

    private func networkBinding<Value>(
        for keyPath: WritableKeyPath<NetworkIdentityState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.networkIdentity[keyPath: keyPath] },
            set: { store.updateNetworkIdentity(keyPath, to: $0) }
        )
    }
}

private struct FirmwareUpdateView: View {
    @ObservedObject var store: SettingsStore
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Device Update",
                subtitle: "Review and install the latest device firmware.",
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    stageCard

                    SettingsFootnote(
                        text: "Please keep the device powered on and connected to Wi-Fi during firmware operations."
                    )
                    .padding(.horizontal, AppSpacing.sm)

                    actionArea
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-firmware-update")
    }

    @ViewBuilder
    private var stageCard: some View {
        switch store.firmwareUpdateStage {
        case .available:
            updateStateCard(
                iconName: "arrow.down.circle.fill",
                title: "Update Available",
                message: "A newer firmware package is available for your device.\nCurrent version \(store.devicePreferences.firmwareVersion) • New version v2.4.5",
                tone: .accent
            )
        case let .downloading(progress, downloadedSize, remainingTime):
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                updateStateCard(
                    iconName: "arrow.down.circle.fill",
                    title: "Downloading Update",
                    message: "\(Int(progress * 100))% complete\n\(downloadedSize) downloaded • \(remainingTime)",
                    tone: .accent
                )

                UpdateProgressBar(progress: progress)
            }
            .padding(AppSpacing.lg)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
            )
        case .failed:
            updateStateCard(
                iconName: "exclamationmark.triangle.fill",
                title: "Update Failed",
                message: "An error occurred while installing the latest device update. Please check your connection and try again.",
                tone: .danger
            )
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        switch store.firmwareUpdateStage {
        case .available:
            PrimaryButton(title: "Start Update") {
                store.startFirmwareUpdate()
            }
        case .downloading:
            VStack(spacing: AppSpacing.md) {
                Button(action: {
                    store.markFirmwareUpdateFailed()
                }) {
                    Text("Simulate Failure")
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.brand)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    store.cancelFirmwareUpdate()
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        case .failed:
            VStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Retry") {
                    store.startFirmwareUpdate()
                }

                Button(action: {
                    store.cancelFirmwareUpdate()
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func updateStateCard(
        iconName: String,
        title: String,
        message: String,
        tone: StatusTagTone
    ) -> some View {
        VStack(alignment: .center, spacing: AppSpacing.lg) {
            Image(systemName: iconName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(tagColor(for: tone))

            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColor.textPrimary)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxxl)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
    }

    private func tagColor(for tone: StatusTagTone) -> Color {
        switch tone {
        case .accent:
            return AppColor.brand
        case .success:
            return AppColor.success
        case .warning:
            return AppColor.warning
        case .danger:
            return AppColor.danger
        case .neutral:
            return AppColor.textSecondary
        }
    }
}

private struct UpdateProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColor.surfaceMuted)
                    .frame(height: 12)

                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColor.brand)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 12)
            }
        }
        .frame(height: 12)
    }
}
