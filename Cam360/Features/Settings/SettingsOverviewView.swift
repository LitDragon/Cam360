import SwiftUI

struct SettingsOverviewView: View {
    @ObservedObject var store: SettingsStore
    let onClose: (() -> Void)?

    init(store: SettingsStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            DeviceSettingsTopBar(
                title: store.devicePreferences.deviceName,
                statusTitle: store.deviceConnectionStatusTitle,
                statusTone: store.deviceConnectionStatusTone,
                onBack: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xxxl) {
                    DeviceSettingsSection(title: "Camera Settings") {
                        DeviceSettingsNavigationRow(
                            title: "Recording Settings",
                            subtitle: "Resolution, Loop, Overwrite",
                            isEnabled: store.isSettingsHomeCategorySupported(.recording),
                            action: {
                                store.show(.recordingSettings)
                            }
                        )

                        DeviceSettingsNavigationRow(
                            title: "Safety Settings",
                            subtitle: "G-Sensor, Parking Mode",
                            isEnabled: store.isSettingsHomeCategorySupported(.safety),
                            action: {
                                store.show(.safetySettings)
                            }
                        )

                        DeviceSettingsNavigationRow(
                            title: "Storage Policy",
                            subtitle: "Retention, Auto-cleanup",
                            isEnabled: store.isSettingsHomeCategorySupported(.storage),
                            action: {
                                store.show(.storagePolicy)
                            }
                        )

                        DeviceSettingsNavigationRow(
                            title: "Watermark Config",
                            subtitle: "Timestamp, Plate No",
                            isEnabled: store.isSettingsHomeCategorySupported(.watermark),
                            showsDivider: false,
                            action: {
                                store.show(.watermarkConfiguration)
                            }
                        )
                    }

                    DeviceSettingsSection(title: "System & Maintenance") {
                        DeviceSettingsNavigationRow(
                            title: "System Preferences",
                            subtitle: "Volume, Sounds, Language",
                            isEnabled: store.isSettingsHomeCategorySupported(.systemPreferences),
                            action: {
                                store.show(.systemPreferences)
                            }
                        )

                        DeviceSettingsNavigationRow(
                            title: "Statistics",
                            subtitle: "Storage, files, usage",
                            action: {
                                store.show(.statistics)
                            }
                        )

                        DeviceSettingsFirmwareRow(
                            title: "Firmware Version",
                            version: store.devicePreferences.firmwareVersion,
                            action: {
                                store.show(.firmwareUpdate)
                            }
                        )

                        DeviceSettingsNavigationRow(
                            title: "Rename Device",
                            subtitle: store.devicePreferences.deviceNameEditable ? nil : "Not supported by device",
                            isEnabled: store.devicePreferences.deviceNameEditable,
                            showsDivider: false,
                            action: {
                                store.show(.renameDevice)
                            }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xxxl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
    }
}

private struct DeviceSettingsTopBar: View {
    let title: String
    let statusTitle: String
    let statusTone: StatusTagTone
    let onBack: (() -> Void)?

    var body: some View {
        ZStack {
            HStack {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.xxl)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusTitle.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundColor(statusColor)
                        .kerning(1.2)
                }
            }
        }
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColor.surface)
        .overlay(
            Rectangle()
                .fill(AppColor.border.opacity(0.55))
                .frame(height: AppLayout.hairline),
            alignment: .bottom
        )
    }

    private var statusColor: Color {
        switch statusTone {
        case .accent, .success:
            return AppColor.brand
        case .warning:
            return AppColor.warning
        case .danger:
            return AppColor.danger
        case .neutral:
            return AppColor.textSecondary
        }
    }
}

private struct DeviceSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AppSpacing.lg)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.border.opacity(0.55), lineWidth: AppLayout.hairline)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
        }
    }
}

private struct DeviceSettingsNavigationRow: View {
    let title: String
    var subtitle: String? = nil
    var isEnabled: Bool = true
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        DeviceSettingsRowContainer(showsDivider: showsDivider) {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isEnabled == false)
            .opacity(isEnabled ? 1 : 0.42)
        }
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.md) {
            DeviceSettingsRowText(title: title, subtitle: subtitle)

            Spacer(minLength: AppSpacing.md)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#B4B8C5"))
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DeviceSettingsFirmwareRow: View {
    let title: String
    let version: String
    let action: () -> Void

    var body: some View {
        DeviceSettingsRowContainer {
            HStack(spacing: AppSpacing.md) {
                DeviceSettingsRowText(title: title, subtitle: version)

                Spacer(minLength: AppSpacing.md)

                Button(action: action) {
                    HStack(spacing: 6) {
                        Image("Check")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 14, height: 14)

                        Text("Check")
                            .font(.system(size: 14, weight: .medium, design: .default))
                    }
                    .foregroundColor(AppColor.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color(hex: "#ECECF7"))
                    .cornerRadius(AppRadius.large)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private struct DeviceSettingsRowContainer<Content: View>: View {
    var showsDivider: Bool = true
    let content: Content

    init(showsDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.lg)
                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)

            if showsDivider {
                Rectangle()
                    .fill(AppColor.border.opacity(0.45))
                    .frame(height: AppLayout.hairline)
            }
        }
    }
}

private struct DeviceSettingsRowText: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(AppColor.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(Color(hex: "#525869"))
            }
        }
    }
}
