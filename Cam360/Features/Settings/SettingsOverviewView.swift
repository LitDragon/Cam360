import SwiftUI

struct SettingsOverviewView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: store.devicePreferences.deviceName,
                subtitle: "Connected and ready to record"
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    connectionSummary

                    SettingsSectionHeader(title: "Camera Settings")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: "video.badge.waveform",
                            title: "Recording Settings",
                            subtitle: "Resolution, quality and overwrite behavior",
                            action: {
                                store.show(.recordingSettings)
                            }
                        )

                        SettingsNavigationRow(
                            iconName: "shield.lefthalf.filled",
                            title: "Safety Settings",
                            subtitle: "Impact detection and parking guard rules",
                            action: {
                                store.show(.safetySettings)
                            }
                        )

                        SettingsNavigationRow(
                            iconName: "sdcard",
                            title: "Storage Policy",
                            subtitle: "Card health, cleanup and retained event space",
                            action: {
                                store.show(.storagePolicy)
                            }
                        )

                        SettingsNavigationRow(
                            iconName: "character.textbox",
                            title: "Watermark Config",
                            subtitle: "Timestamp and license plate overlay",
                            showsDivider: false,
                            action: {
                                store.show(.watermarkConfiguration)
                            }
                        )
                    }

                    SettingsSectionHeader(title: "System Maintenance")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: "gearshape.2",
                            title: "Device Settings",
                            subtitle: "Identity, localization, audio and reset options",
                            action: {
                                store.show(.deviceSettings)
                            }
                        )

                        SettingsNavigationRow(
                            iconName: "slider.horizontal.3",
                            title: "System Preferences",
                            subtitle: "App permissions, notifications and support",
                            action: {
                                store.show(.systemPreferences)
                            }
                        )

                        SettingsStatusRow(
                            iconName: "arrow.down.circle",
                            title: "Firmware Version",
                            subtitle: "Current installed build",
                            statusText: store.devicePreferences.firmwareVersion
                        )

                        SettingsNavigationRow(
                            iconName: "pencil.line",
                            title: "Rename Device",
                            subtitle: "Update the display name shown in the app",
                            showsDivider: false,
                            action: {
                                store.show(.renameDevice)
                            }
                        )
                    }

                    SettingsFootnote(
                        text: "This M0 settings shell is backed by local placeholder state until DeviceSession and device capabilities are wired in."
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
    }

    private var connectionSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                StatusTag(title: "CONNECTED", tone: .success)

                Text(store.devicePreferences.connectionName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            SettingsNoticeCard(
                title: "Current Connection",
                message: "\(store.devicePreferences.connectionName)\nFirmware \(store.devicePreferences.firmwareVersion)",
                tone: .info,
                iconName: "wifi"
            )
        }
    }
}
