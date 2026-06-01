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
        case .unavailable(let message):
            updateStateCard(
                iconName: "exclamationmark.triangle.fill",
                title: "Update Source Pending",
                message: message,
                tone: .warning
            )
        case .available:
            updateStateCard(
                iconName: "arrow.down.circle.fill",
                title: "Update Available",
                message: "A verified firmware candidate is available for \(store.devicePreferences.firmwareVersion).",
                tone: .accent
            )
        case let .inProgress(progress, stageTitle):
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                updateStateCard(
                    iconName: "arrow.down.circle.fill",
                    title: stageTitle,
                    message: "\(Int(progress * 100))% complete",
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
        case .completed:
            updateStateCard(
                iconName: "checkmark.circle.fill",
                title: "Update Complete",
                message: "The device firmware update has completed.",
                tone: .success
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
        case .unavailable:
            PrimaryButton(
                title: "Check for Updates",
                isEnabled: false,
                leadingSystemImageName: "arrow.clockwise",
                action: {}
            )
        case .available:
            PrimaryButton(title: "Start Update", isEnabled: false, action: {})
        case .inProgress:
            EmptyView()
        case .completed:
            PrimaryButton(title: "Done") {
                dismiss()
            }
        case .failed:
            PrimaryButton(title: "Done") {
                dismiss()
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
