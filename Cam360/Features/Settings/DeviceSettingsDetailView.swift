import SwiftUI

private enum DeviceSettingsDetailRoute: Hashable {
    case networkIdentity
    case firmwareUpdate
    case renameDevice
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
                            isEnabled: store.devicePreferences.deviceNameEditable,
                            action: {
                                store.setRenameDeviceDraft(store.devicePreferences.deviceName)
                                route = .renameDevice
                            }
                        )

                        SettingsValueRow(
                            iconName: nil,
                            title: "Connectivity",
                            subtitle: store.devicePreferences.connectionStatus.capitalized,
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
                        if store.devicePreferences.firmwareUpdateEntryEnabled {
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
                        } else {
                            SettingsValueRow(
                                iconName: nil,
                                title: "Firmware Version",
                                valueText: store.devicePreferences.firmwareVersion,
                                showsDivider: false
                            )
                        }
                    }

                    SettingsSectionHeader(title: "Localization")
                    SettingsGroupCard {
                        SettingsValueRow(
                            iconName: nil,
                            title: "Time Zone",
                            valueText: store.devicePreferences.timeZone
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Date & Time Auto-sync",
                            isOn: deviceBinding(for: \.dateTimeAutoSyncEnabled)
                        )

                        SettingsValueRow(
                            iconName: nil,
                            title: "Language",
                            valueText: store.devicePreferences.language,
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Audio Controls")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "Speaker Volume",
                            options: store.devicePreferences.speakerVolumeOptions,
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
                        message: store.devicePreferences.factoryResetSupported
                            ? "Resets local device-facing settings in this M0 shell. It does not touch onboarding or app-level preferences."
                            : "Factory reset is not declared by this device capability snapshot.",
                        tone: .danger,
                        iconName: "exclamationmark.triangle"
                    )

                    DestructiveButton(
                        title: "Factory Reset",
                        isEnabled: store.devicePreferences.factoryResetSupported
                    ) {
                        store.restoreDefaultDeviceConfiguration()
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

            NavigationLink(
                destination: RenameDeviceView(
                    store: store,
                    dismiss: {
                        route = nil
                    },
                    save: {
                        store.renameDevice(dismissRoute: false)
                        route = nil
                    }
                )
                .navigationBarHidden(true),
                tag: .renameDevice,
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
                            placeholder: store.networkNamePlaceholderText
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

                    if let validationMessage = store.networkIdentityValidationMessage {
                        SettingsNoticeCard(
                            title: "Check Network Details",
                            message: validationMessage,
                            tone: .danger,
                            iconName: "exclamationmark.circle"
                        )
                    }

                    PrimaryButton(title: "Save Changes", isEnabled: store.canCommitNetworkIdentityChanges) {
                        if store.commitNetworkIdentityChanges() {
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .onAppear(perform: store.prepareNetworkIdentity)
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
