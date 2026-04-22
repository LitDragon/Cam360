import SwiftUI
import UIKit

struct SystemPermissionsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "System Permissions",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("Manage app permissions for your device.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.horizontal, AppSpacing.xxl)

                    SettingsGroupCard {
                        SettingsStatusRow(
                            iconName: nil,
                            title: "Notifications",
                            subtitle: "Receive alerts for important safety events.",
                            statusText: "ENABLED",
                            trailingSystemImage: "checkmark",
                            statusColor: AppColor.textSecondary
                        )

                        SettingsActionRow(
                            iconName: nil,
                            title: "Location",
                            subtitle: "Tag driving events with GPS coordinates.",
                            actionTitle: "Allow Access",
                            action: openAppSettings
                        )

                        SettingsStatusRow(
                            iconName: nil,
                            title: "Camera",
                            subtitle: "Capture photos and videos from the app.",
                            statusText: "ENABLED",
                            trailingSystemImage: "checkmark",
                            statusColor: AppColor.textSecondary
                        )

                        SettingsStatusRow(
                            iconName: nil,
                            title: "Microphone",
                            subtitle: "Record in-cabin audio with your video.",
                            statusText: "ENABLED",
                            trailingSystemImage: "checkmark",
                            statusColor: AppColor.textSecondary
                        )

                        SettingsStatusRow(
                            iconName: nil,
                            title: "Photos",
                            subtitle: "Save recordings to your device.",
                            statusText: "ENABLED",
                            trailingSystemImage: "checkmark",
                            statusColor: AppColor.textSecondary
                        )

                        SettingsActionRow(
                            iconName: nil,
                            title: "Bluetooth",
                            subtitle: "Discover and connect to dashcams.",
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
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-system-permissions")
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
