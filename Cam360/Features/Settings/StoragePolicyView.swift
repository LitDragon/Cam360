import SwiftUI

struct StoragePolicyView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Storage Policy",
                subtitle: "Retention, cleanup and SD card behavior",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Maintenance")
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

                    SettingsSectionHeader(title: "General Policy")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: nil,
                            title: "Auto Cleanup",
                            subtitle: "Delete events older than 30 days.",
                            isOn: binding(for: \.autoCleanupEnabled),
                            isEnabled: isStorageReady
                        )

                        SettingsToggleRow(
                            iconName: nil,
                            title: "Auto Overwrite",
                            subtitle: "Automatically overwrite the oldest non-locked recordings when storage is full.",
                            isOn: binding(for: \.autoOverwriteEnabled),
                            isEnabled: isStorageReady
                        )

                        SettingsValueRow(
                            iconName: nil,
                            title: "Locked Event Retention",
                            valueText: store.storagePolicy.lockedEventRetention.rawValue,
                            valueColor: isStorageReady ? AppColor.textSecondary : AppColor.textSecondary.opacity(0.48),
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Storage Allocation")
                    SettingsGroupCard {
                        SettingsValueRow(
                            iconName: nil,
                            title: "Reserved Space for Events",
                            subtitle: "Protected storage reserved for impact and parking events.",
                            valueText: "\(store.storagePolicy.reservedEventSpacePercent)%",
                            showsDivider: false
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-storage-policy")
    }

    private var isStorageReady: Bool {
        store.storagePolicy.cardStatus == .ready
    }

    @ViewBuilder
    private var statusContent: some View {
        switch store.storagePolicy.cardStatus {
        case .ready:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsMetricCard(
                    title: "SD Card Storage",
                    progress: store.storagePolicy.usageProgress,
                    progressLabel: "\(Int(store.storagePolicy.usageProgress * 100))%",
                    progressCaption: "Used",
                    details: [
                        SettingsMetricDetail(iconName: "externaldrive", title: "Used Space", value: store.storagePolicy.usedSpaceText),
                        SettingsMetricDetail(iconName: "internaldrive", title: "Free Space", value: store.storagePolicy.freeSpaceText)
                    ],
                    footnote: store.storagePolicy.estimatedHoursRemaining
                )

                DestructiveButton(title: "Format Card") {
                    store.formatStorageCard()
                }
            }
        case .noCard:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsNoticeCard(
                    title: "No SD Card Detected",
                    message: "Please insert a compatible microSD card to enable storage policies and loop recording.",
                    tone: .info,
                    iconName: "sdcard"
                )

                PrimaryButton(title: "Retry") {
                    store.retryStorageCardCheck()
                }

                SettingsFootnote(
                    text: "Supported card types: Insert a card, then return to Live to start recording."
                )
            }
        case .error:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsNoticeCard(
                    title: "SD Card Error",
                    message: "The detected card is unavailable or requires formatting before use.",
                    tone: .danger,
                    iconName: "exclamationmark.octagon"
                )

                DestructiveButton(title: "Format Card") {
                    store.formatStorageCard()
                }
            }
        }
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
