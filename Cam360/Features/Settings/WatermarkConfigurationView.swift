import SwiftUI

struct WatermarkConfigurationView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Watermark Configuration",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    previewCard

                    watermarkOptionsCard

                    PrimaryButton(
                        title: "Save Configuration",
                        trailingSystemImageName: "checkmark.circle",
                        verticalPadding: 18,
                        cornerRadius: 28
                    ) {
                        store.saveWatermarkConfiguration()
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xxl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-watermark-configuration")
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxxl) {
                Text("Customize the telemetry and identification\noverlays displayed on your recorded\ndashcam footage.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(AppColor.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                WatermarkPreview(
                    timestampEnabled: store.watermarkConfiguration.timestampEnabled,
                    licensePlateEnabled: store.watermarkConfiguration.licensePlateEnabled,
                    licensePlate: store.watermarkConfiguration.licensePlate,
                    position: store.watermarkConfiguration.position
                )
            }

            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(AppColor.brand)
                    .frame(width: 8, height: 8)

                Text("Live Preview Mode")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(AppColor.textSecondary)

                Spacer(minLength: 0)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))

                    Text("Expand")
                        .font(.system(size: 13, weight: .bold, design: .default))
                }
                .foregroundColor(AppColor.brand)
            }
            .padding(.horizontal, AppSpacing.sm)
        }
    }

    private var watermarkOptionsCard: some View {
        VStack(spacing: 0) {
            WatermarkToggleRow(
                iconName: "clock",
                title: "Timestamp",
                subtitle: "Date and time overlay",
                isOn: binding(for: \.timestampEnabled)
            )

            WatermarkToggleRow(
                iconName: "keyboard",
                title: "License Plate",
                subtitle: "Vehicle identity tag",
                isOn: binding(for: \.licensePlateEnabled)
            )

            WatermarkPlateInput(
                text: binding(for: \.licensePlate),
                isEnabled: store.watermarkConfiguration.licensePlateEnabled
            )

            SettingsSegmentedRow(
                title: "Position",
                subtitle: "Overlay anchor on recorded footage",
                options: WatermarkPositionOption.allCases,
                selection: binding(for: \.position),
                titleForOption: { $0.controlTitle },
                showsDivider: false
            )
        }
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#E7E9F8"), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#24407A").opacity(0.08), radius: 16, x: 0, y: 8)
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

private struct WatermarkPreview: View {
    let timestampEnabled: Bool
    let licensePlateEnabled: Bool
    let licensePlate: String
    let position: WatermarkPositionOption

    var body: some View {
        ZStack {
            Image("temp")
                .resizable()
                .scaledToFill()

            WatermarkPlaybackControls()

            if timestampEnabled || licensePlateEnabled {
                VStack(alignment: position.horizontalAlignment, spacing: 4) {
                    if timestampEnabled {
                        Text("2024-05-24 14:32:15")
                            .font(.system(size: 6, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.34))
                            .cornerRadius(4)
                    }

                    if licensePlateEnabled {
                        Text("LPN: \(licensePlate)")
                            .font(.system(size: 6, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(AppColor.brand)
                            .cornerRadius(4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.previewAlignment)
                .padding(AppSpacing.sm)
            }
        }
        .aspectRatio(342.0 / 193.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 8)
    }
}

private extension WatermarkPositionOption {
    var controlTitle: String {
        switch self {
        case .topLeft:
            return "Top L"
        case .topRight:
            return "Top R"
        case .bottomLeft:
            return "Bottom L"
        case .bottomRight:
            return "Bottom R"
        }
    }

    var previewAlignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .topLeft, .bottomLeft:
            return .leading
        case .topRight, .bottomRight:
            return .trailing
        }
    }
}

private struct WatermarkPlaybackControls: View {
    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "backward.end.fill")
            Image(systemName: "play.fill")
            Image(systemName: "forward.end.fill")
        }
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.white)
        .frame(width: 184, height: 52)
        .background(Color(hex: "#808080").opacity(0.88))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .offset(y: 34)
    }
}

private struct WatermarkToggleRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#ECECF8"))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#5E6272"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer(minLength: AppSpacing.md)

            Group {
                if #available(iOS 14.0, *) {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: AppColor.brand))
                } else {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }
}

private struct WatermarkPlateInput: View {
    @Binding var text: String
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PLATE NUMBER")
                .font(.system(size: 11, weight: .bold, design: .default))
                .foregroundColor(AppColor.textPrimary.opacity(0.78))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("AB1234CD")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(AppColor.textSecondary)
                }

                TextField("", text: $text)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.textPrimary)
                    .disabled(isEnabled == false)
            }
            .padding(.horizontal, AppSpacing.lg)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#E4E4F1"))
            .cornerRadius(10)
            .opacity(isEnabled ? 1 : 0.42)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }
}
