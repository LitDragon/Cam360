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
                            status: bluetoothStatus
                        )

                        SettingsActionRow(
                            iconName: nil,
                            title: "iOS Settings",
                            subtitle: "Change denied, limited or not requested permissions in Settings.",
                            actionTitle: "Open Settings",
                            showsDivider: false,
                            action: openAppSettings
                        )
                    }

                    Text("DriveCam requires these permissions to operate correctly in the background.\nAll data is encrypted and stored locally by default.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
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
        status: SystemPermissionStatus
    ) -> some View {
        SettingsStatusRow(
            iconName: nil,
            title: title,
            subtitle: subtitle,
            statusText: status.title,
            trailingSystemImage: status.symbolName,
            statusColor: status.color
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
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
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

private enum SystemPermissionStatus: Equatable {
    case enabled
    case disabled
    case notDetermined
    case restricted
    case limited
    case unavailable

    var title: String {
        switch self {
        case .enabled:
            return "ENABLED"
        case .disabled:
            return "DISABLED"
        case .notDetermined:
            return "NOT SET"
        case .restricted:
            return "RESTRICTED"
        case .limited:
            return "LIMITED"
        case .unavailable:
            return "UNKNOWN"
        }
    }

    var symbolName: String {
        switch self {
        case .enabled:
            return "checkmark"
        case .limited, .notDetermined:
            return "exclamationmark"
        case .disabled, .restricted, .unavailable:
            return "xmark"
        }
    }

    var color: Color {
        switch self {
        case .enabled:
            return AppColor.success
        case .limited, .notDetermined:
            return AppColor.warning
        case .disabled, .restricted, .unavailable:
            return AppColor.danger
        }
    }
}
