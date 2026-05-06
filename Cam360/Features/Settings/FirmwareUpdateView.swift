import SwiftUI

struct FirmwareUpdateView: View {
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
                .padding(.bottom, AppLayout.scrollBottomContentInset)
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

                AppProgressBar(
                    progress: CGFloat(progress),
                    height: AppLayout.settingsProgressHeight,
                    trackColor: AppColor.surfaceMuted,
                    cornerRadius: AppRadius.small
                )
            }
            .padding(AppSpacing.lg)
            .appSurface()
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
        .appSurface()
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
