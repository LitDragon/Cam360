import SwiftUI

struct StatisticsView: View {
    @ObservedObject var store: StatisticsStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "数据统计",
                subtitle: "设备使用和存储统计",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "设备信息") {
                        VStack(spacing: AppSpacing.md) {
                            statisticRow(title: "Model", value: store.deviceInfo.model)
                            statisticRow(title: "Firmware", value: store.deviceInfo.firmwareVersion)
                            statisticRow(title: "Serial No.", value: store.deviceInfo.serialNumber)
                        }
                    }

                    SectionCard(title: "存储统计") {
                        VStack(spacing: AppSpacing.md) {
                            metricPair(
                                leadingTitle: "Total Files",
                                leadingValue: store.totalFilesText,
                                trailingTitle: "Total Size",
                                trailingValue: store.totalSizeText
                            )
                            metricPair(
                                leadingTitle: "Duration",
                                leadingValue: store.totalDurationText,
                                trailingTitle: "Usage Days",
                                trailingValue: store.usageDaysText
                            )
                        }
                    }

                    SectionCard(title: "文件统计") {
                        VStack(spacing: AppSpacing.md) {
                            metricPair(
                                leadingTitle: "Videos",
                                leadingValue: "\(store.statistics.videoCount)",
                                trailingTitle: "Photos",
                                trailingValue: "\(store.statistics.photoCount)"
                            )
                            metricPair(
                                leadingTitle: "Locked Videos",
                                leadingValue: "\(store.statistics.lockedVideoCount)",
                                trailingTitle: "Locked Photos",
                                trailingValue: "\(store.statistics.lockedPhotoCount)"
                            )
                        }
                    }

                    PrimaryButton(
                        title: refreshTitle,
                        isEnabled: store.canRefresh,
                        leadingSystemImageName: "arrow.clockwise",
                        action: store.refresh
                    )

                    if case .unavailable(let message) = store.loadState {
                        EmptyStateView(
                            iconName: "chart.bar.doc.horizontal",
                            title: "统计不可用",
                            message: message
                        )
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-statistics")
        .onAppear(perform: store.refresh)
    }

    private var refreshTitle: String {
        store.loadState == .loading ? "读取中" : "刷新统计"
    }

    private func statisticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)

            Spacer(minLength: AppSpacing.md)

            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metricPair(
        leadingTitle: String,
        leadingValue: String,
        trailingTitle: String,
        trailingValue: String
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            metric(title: leadingTitle, value: leadingValue)
            metric(title: trailingTitle, value: trailingValue)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
