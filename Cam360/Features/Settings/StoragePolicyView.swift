import SwiftUI

struct StoragePolicyView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Storage Policy",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    StoragePolicySectionHeader(title: "Maintenance")
                    SettingsGroupCard {
                        SettingsSegmentedRow(
                            title: "Storage State",
                            subtitle: "Local M0 preview for no-card, ready and error states.",
                            options: StorageCardStatus.allCases,
                            selection: binding(for: \.cardStatus),
                            titleForOption: { $0.rawValue },
                            showsDivider: false
                        )
                    }

                    statusContent

                    if showsPolicySections {
                        StoragePolicySectionHeader(title: "General Policy", isEnabled: canEditPolicies)
                        StoragePolicyGeneralCard(
                            autoOverwriteEnabled: binding(for: \.autoOverwriteEnabled),
                            lockedEventRetention: store.storagePolicy.lockedEventRetention.rawValue,
                            isEnabled: canEditPolicies
                        )

                        StoragePolicySectionHeader(title: "Storage Allocation", isEnabled: canEditPolicies)
                        StoragePolicyAllocationCard(
                            reservedEventSpacePercent: store.storagePolicy.reservedEventSpacePercent,
                            isEnabled: canEditPolicies
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-storage-policy")
    }

    private var canEditPolicies: Bool {
        store.storagePolicy.canEditPolicies
    }

    private var showsPolicySections: Bool {
        store.storagePolicy.cardStatus != .noCard
    }

    @ViewBuilder
    private var statusContent: some View {
        switch store.storagePolicy.cardStatus {
        case .ready:
            StorageMaintenanceCard(
                mode: .ready,
                usageProgress: store.storagePolicy.usageProgress,
                usedSpaceText: store.storagePolicy.usedSpaceText,
                totalSpaceText: formattedCapacity(store.storagePolicy.totalSpaceGB),
                estimatedHoursRemaining: store.storagePolicy.estimatedHoursRemaining,
                errorDescription: store.storagePolicy.cardErrorDescription,
                autoCleanupRetentionDays: store.storagePolicy.autoCleanupRetentionDays,
                autoCleanupEnabled: binding(for: \.autoCleanupEnabled),
                formatStage: store.storagePolicy.formatStage,
                canFormat: store.storagePolicy.canFormat,
                canEditPolicies: store.storagePolicy.canEditPolicies,
                formatAction: store.formatStorageCard
            )
        case .noCard:
            StorageNoCardCard {
                store.retryStorageCardCheck()
            }
        case .error:
            StorageMaintenanceCard(
                mode: .error,
                usageProgress: store.storagePolicy.usageProgress,
                usedSpaceText: store.storagePolicy.usedSpaceText,
                totalSpaceText: formattedCapacity(store.storagePolicy.totalSpaceGB),
                estimatedHoursRemaining: store.storagePolicy.estimatedHoursRemaining,
                errorDescription: store.storagePolicy.cardErrorDescription,
                autoCleanupRetentionDays: store.storagePolicy.autoCleanupRetentionDays,
                autoCleanupEnabled: binding(for: \.autoCleanupEnabled),
                formatStage: store.storagePolicy.formatStage,
                canFormat: store.storagePolicy.canFormat,
                canEditPolicies: store.storagePolicy.canEditPolicies,
                formatAction: store.formatStorageCard
            )
        }
    }

    private func formattedCapacity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f GB", value)
        }

        return String(format: "%.1f GB", value)
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<StoragePolicyState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.storagePolicy[keyPath: keyPath] },
            set: { store.updateStoragePolicy(keyPath, to: $0) }
        )
    }
}

private struct StoragePolicySectionHeader: View {
    let title: String
    var isEnabled: Bool = true

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .regular, design: .default))
            .foregroundColor(isEnabled ? .black : AppColor.textPrimary.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum StorageMaintenanceMode {
    case ready
    case error
}

private struct StorageMaintenanceCard: View {
    let mode: StorageMaintenanceMode
    let usageProgress: Double
    let usedSpaceText: String
    let totalSpaceText: String
    let estimatedHoursRemaining: String
    let errorDescription: String
    let autoCleanupRetentionDays: Int
    @Binding var autoCleanupEnabled: Bool
    let formatStage: StorageFormatStage
    let canFormat: Bool
    let canEditPolicies: Bool
    let formatAction: () -> Void

    private var isReady: Bool {
        mode == .ready
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                topContent

                StorageFormatButton(stage: formatStage, isEnabled: canFormat, action: formatAction)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.xl)
            .background(StoragePolicyStyle.panelBackground)
            .cornerRadius(AppRadius.small)

            StoragePolicyTogglePanel(
                title: "Auto Cleanup",
                subtitle: "Delete events older than \(autoCleanupRetentionDays) days",
                isOn: $autoCleanupEnabled,
                isEnabled: isReady && canEditPolicies
            )
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppColor.surface)
        .cornerRadius(10)
    }

    @ViewBuilder
    private var topContent: some View {
        switch mode {
        case .ready:
            readyContent
        case .error:
            errorContent
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxl) {
            Text("SD Card Storage")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(AppColor.textPrimary)

            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                StorageStatusRing(
                    mode: .ready,
                    progress: usageProgress,
                    title: "\(Int((usageProgress * 100).rounded()))%",
                    subtitle: "USED"
                )

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    StorageDetailRow(title: "Used Space", value: usedSpaceText)
                    StorageDetailRow(title: "Total Capacity", value: totalSpaceText)

                    Rectangle()
                        .fill(AppColor.border.opacity(0.55))
                        .frame(height: AppLayout.hairline)

                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColor.brand)
                            .padding(.top, 2)

                        Text(estimatedHoursRemaining)
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxl) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.danger)

                Text("SD card error")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.danger)
            }

            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                StorageStatusRing(
                    mode: .error,
                    progress: 0,
                    title: "Error",
                    subtitle: "Status"
                )

                Text(errorDescription)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(AppColor.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StorageDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(AppColor.textPrimary)

            Spacer(minLength: AppSpacing.md)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(AppColor.textPrimary)
        }
    }
}

private struct StorageStatusRing: View {
    let mode: StorageMaintenanceMode
    let progress: Double
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                ringSegment(index: index, color: StoragePolicyStyle.ringTrack)
            }

            if mode == .ready {
                ForEach(activeSegments, id: \.index) { segment in
                    ringSegment(index: segment.index, end: segment.end, color: AppColor.brand)
                }
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(AppColor.textPrimary)
            }
        }
        .frame(width: 96, height: 96)
    }

    private var activeSegments: [RingSegment] {
        let segmentLength: CGFloat = 0.16
        let normalizedProgress = CGFloat(min(max(progress, 0), 1))
        var remaining = normalizedProgress

        return (0..<4).compactMap { index in
            guard remaining > 0 else {
                return nil
            }

            let fill = min(segmentLength, remaining)
            remaining -= fill
            return RingSegment(index: index, end: fill / segmentLength)
        }
    }

    private func ringSegment(index: Int, end: CGFloat = 1, color: Color) -> some View {
        let segmentLength: CGFloat = 0.16
        let segmentGap: CGFloat = 0.09
        let start = CGFloat(index) * (segmentLength + segmentGap)
        let finish = start + segmentLength * end

        return Circle()
            .trim(from: start, to: finish)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}

private struct RingSegment: Hashable {
    let index: Int
    let end: CGFloat
}

private struct StorageFormatButton: View {
    let stage: StorageFormatStage
    let isEnabled: Bool
    let action: () -> Void

    private var title: String {
        switch stage {
        case .idle:
            return "Format Card"
        case .inProgress(let progress):
            return "Formatting \(Int((progress * 100).rounded()))%"
        case .completed:
            return "Format Complete"
        case .failed:
            return "Retry Format"
        }
    }

    private var isFormatting: Bool {
        if case .inProgress = stage {
            return true
        }
        return false
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.danger)
                .cornerRadius(AppRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isFormatting || isEnabled == false)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

private struct StoragePolicyGeneralCard: View {
    @Binding var autoOverwriteEnabled: Bool
    let lockedEventRetention: String
    let isEnabled: Bool

    var body: some View {
        StoragePolicyPanelCard {
            StoragePolicyTogglePanel(
                title: "Auto Overwrite",
                subtitle: "Automatically overwrite the oldest non-locked\nrecording when storage is full",
                isOn: $autoOverwriteEnabled,
                isEnabled: isEnabled
            )

            StoragePolicyValuePanel(
                title: "Locked Event Retention",
                value: lockedEventRetention,
                isEnabled: isEnabled
            )
        }
    }
}

private struct StoragePolicyAllocationCard: View {
    let reservedEventSpacePercent: Int
    let isEnabled: Bool

    var body: some View {
        StoragePolicyPanelCard {
            StoragePolicyValuePanel(
                title: "Reserved Space for Events",
                value: "\(reservedEventSpacePercent)%",
                isEnabled: isEnabled
            )
        }
    }
}

private struct StoragePolicyPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            content
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppColor.surface)
        .cornerRadius(10)
    }
}

private struct StoragePolicyTogglePanel: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.black)

                Spacer(minLength: AppSpacing.md)

                Group {
                    if #available(iOS 14.0, *) {
                        Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: AppColor.brand))
                            .disabled(isEnabled == false)
                    } else {
                        Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle())
                            .disabled(isEnabled == false)
                    }
                }
            }

            Text(subtitle)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(AppColor.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(StoragePolicyStyle.panelBackground)
        .cornerRadius(AppRadius.small)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

private struct StoragePolicyValuePanel: View {
    let title: String
    let value: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(title)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppSpacing.md)

            HStack(spacing: AppSpacing.xs) {
                Text(value)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(AppColor.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(StoragePolicyStyle.panelBackground)
        .cornerRadius(AppRadius.small)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

private enum StoragePolicyStyle {
    static let panelBackground = Color(hex: "#F2F3FC")
    static let ringTrack = Color(hex: "#C7CBDC")
}

private struct StorageNoCardCard: View {
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.lg) {
                Image("NoSDCard")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 64, height: 64)

                VStack(spacing: AppSpacing.sm) {
                    Text("No SD Card detected")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(AppColor.textPrimary)

                    Text("Please insert a compatible microSD card\nto start recording.")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xxxl)
            .padding(.horizontal, AppSpacing.lg)
            .background(Color(hex: "#F2F3FC"))
            .cornerRadius(AppRadius.small)

            PrimaryButton(
                title: "Retry",
                verticalPadding: 14,
                cornerRadius: 10,
                shadowColor: .clear,
                action: retryAction
            )
            .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: AppSpacing.lg) {
                Text("Supported card types")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(AppColor.brand)

                Text("Insert a card, then return to Live to start recording")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(AppColor.surface)
        .cornerRadius(10)
    }
}
