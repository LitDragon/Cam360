import SwiftUI

struct WatermarkConfigurationView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Watermark Configuration",
                subtitle: "Customize the telemetry and identification overlay shown on recordings.",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    previewCard

                    SettingsSectionHeader(title: "Overlay Settings")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: "clock",
                            title: "Timestamp",
                            isOn: binding(for: \.timestampEnabled)
                        )

                        SettingsToggleRow(
                            iconName: "car.rear",
                            title: "License Plate",
                            isOn: binding(for: \.licensePlateEnabled),
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Plate")
                    SettingsGroupCard {
                        SettingsInputRow(
                            title: "Vehicle Plate",
                            text: binding(for: \.licensePlate),
                            placeholder: "AB-123-CD",
                            isEnabled: store.watermarkConfiguration.licensePlateEnabled,
                            showsDivider: false
                        )
                    }

                    PrimaryButton(title: "Save Configuration") {
                        store.saveWatermarkConfiguration()
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-watermark-configuration")
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Preview")
                .font(AppTypography.bodyStrong)
                .foregroundColor(AppColor.textPrimary)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppColor.brand.opacity(0.32), AppColor.surfaceMuted]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 220)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if store.watermarkConfiguration.timestampEnabled {
                        Text("04/24/2026 10:30")
                            .font(AppTypography.caption)
                            .foregroundColor(.white)
                    }

                    if store.watermarkConfiguration.licensePlateEnabled {
                        Text(store.watermarkConfiguration.licensePlate)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(.white)
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<WatermarkConfigurationState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.watermarkConfiguration[keyPath: keyPath] },
            set: { store.updateWatermarkConfiguration(keyPath, to: $0) }
        )
    }
}
