import AVFoundation
import CoreBluetooth
import CoreLocation
import Photos
import SwiftUI
import UIKit
import UserNotifications

struct SystemPermissionsView: View {
    @ObservedObject var store: SettingsStore
    var dismiss: (() -> Void)? = nil

    @State private var notificationStatus: SystemPermissionStatus = .notDetermined
    @State private var locationStatus: SystemPermissionStatus = .notDetermined
    @State private var cameraStatus: SystemPermissionStatus = .notDetermined
    @State private var microphoneStatus: SystemPermissionStatus = .notDetermined
    @State private var photosStatus: SystemPermissionStatus = .notDetermined
    @State private var bluetoothStatus: SystemPermissionStatus = .notDetermined

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "System Permissions",
                leadingSystemImage: "arrow.left",
                leadingAction: dismissAction
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("Manage app permissions for your device.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.horizontal, AppSpacing.xxl)

                    SettingsGroupCard {
                        permissionRow(
                            title: "Notifications",
                            subtitle: "Receive alerts for important safety events.",
                            status: notificationStatus
                        )

                        permissionRow(
                            title: "Location",
                            subtitle: "Tag driving events with GPS coordinates.",
                            status: locationStatus
                        )

                        permissionRow(
                            title: "Camera",
                            subtitle: "Capture photos and videos from the app.",
                            status: cameraStatus
                        )

                        permissionRow(
                            title: "Microphone",
                            subtitle: "Record in-cabin audio with your video.",
                            status: microphoneStatus
                        )

                        permissionRow(
                            title: "Photos",
                            subtitle: "Save recordings to your device.",
                            status: photosStatus
                        )

                        permissionRow(
                            title: "Bluetooth",
                            subtitle: "Discover and connect to dashcams.",
                            status: bluetoothStatus,
                            showsDivider: false
                        )
                    }

                    Text("DriveCam requires these permissions to operate correctly in the background.\nAll data is encrypted and stored locally by default.")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(AppColor.textPrimary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.md)
                        .padding(.horizontal, AppSpacing.xxxl)
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-system-permissions")
        .onAppear(perform: refreshPermissionStatuses)
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        status: SystemPermissionStatus,
        showsDivider: Bool = true
    ) -> some View {
        SystemPermissionRow(
            title: title,
            subtitle: subtitle,
            isEnabled: status == .enabled,
            showsDivider: showsDivider,
            openSettings: openAppSettings
        )
    }

    private func refreshPermissionStatuses() {
        refreshNotificationStatus()
        locationStatus = Self.locationPermissionStatus()
        cameraStatus = Self.capturePermissionStatus(for: .video)
        microphoneStatus = Self.capturePermissionStatus(for: .audio)
        photosStatus = Self.photoPermissionStatus()
        bluetoothStatus = Self.bluetoothPermissionStatus()
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = Self.notificationPermissionStatus(from: settings.authorizationStatus)
            DispatchQueue.main.async {
                notificationStatus = status
            }
        }
    }

    private func dismissAction() {
        if let dismiss = dismiss {
            dismiss()
        } else {
            store.dismissRoute()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }

        UIApplication.shared.open(url)
    }

    private static func notificationPermissionStatus(
        from authorizationStatus: UNAuthorizationStatus
    ) -> SystemPermissionStatus {
        switch authorizationStatus {
        case .authorized, .provisional:
            return .enabled
        case .ephemeral:
            return .enabled
        case .denied:
            return .disabled
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unavailable
        }
    }

    private static func capturePermissionStatus(for mediaType: AVMediaType) -> SystemPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return .enabled
        case .denied:
            return .disabled
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }

    private static func photoPermissionStatus() -> SystemPermissionStatus {
        let status: PHAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        } else {
            status = PHPhotoLibrary.authorizationStatus()
        }

        switch status {
        case .authorized:
            return .enabled
        case .limited:
            return .limited
        case .denied:
            return .disabled
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }

    private static func locationPermissionStatus() -> SystemPermissionStatus {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .enabled
        case .denied:
            return .disabled
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }

    private static func bluetoothPermissionStatus() -> SystemPermissionStatus {
        guard #available(iOS 13.1, *) else {
            return .unavailable
        }

        switch CBManager.authorization {
        case .allowedAlways:
            return .enabled
        case .denied:
            return .disabled
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }
}

private struct SystemPermissionRow: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool
    var showsDivider: Bool = true
    let openSettings: () -> Void

    private let secondaryTextColor = AppColor.textPrimary
    private let enabledStatusColor = AppColor.textPrimary.opacity(0.4)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.xs) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingContent
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)

            if showsDivider {
                Rectangle()
                    .fill(AppColor.border.opacity(0.35))
                    .frame(height: AppLayout.hairline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingContent: some View {
        if isEnabled {
            HStack(spacing: AppSpacing.xs) {
                Text("ENABLED")
                    .font(.system(size: 10, weight: .semibold, design: .default))

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(enabledStatusColor)
        } else {
            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(AppColor.brand)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.accentSurface)
                    .cornerRadius(AppRadius.large)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

private enum SystemPermissionStatus: Equatable {
    case enabled
    case disabled
    case notDetermined
    case restricted
    case limited
    case unavailable
}
