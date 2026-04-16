import SwiftUI

struct DashboardView: View {
    @ObservedObject var deviceStore: DeviceListStore
    @ObservedObject var livePreviewStore: LivePreviewStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "概览", subtitle: "设备与本地状态")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    overviewCard

                    SectionCard(title: "已连接设备") {
                        if deviceStore.devices.isEmpty {
                            EmptyStateView(
                                iconName: "externaldrive.badge.questionmark",
                                title: "还没有已知设备",
                                message: "完成真实接入后，这里会展示最近连接的设备和恢复入口。"
                            )
                        } else {
                            VStack(spacing: AppSpacing.md) {
                                ForEach(deviceStore.devices) { device in
                                    DeviceCell(device: device)
                                }
                            }
                        }
                    }

                    QuickActionCard(
                        iconName: "video.fill",
                        title: livePreviewStore.title,
                        message: livePreviewStore.message,
                        tint: AppColor.brand
                    )

                    VStack(spacing: AppSpacing.md) {
                        QuickActionCard(
                            iconName: "photo.on.rectangle.angled",
                            title: "相册",
                            message: "当前没有可展示的媒体内容。",
                            tint: AppColor.brand
                        )

                        QuickActionCard(
                            iconName: "bell.badge.fill",
                            title: "事件",
                            message: "当前没有可展示的事件记录。",
                            tint: AppColor.warning
                        )
                    }
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-dashboard")
        .onAppear(perform: deviceStore.reload)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            StatusTag(title: "本地状态", tone: .accent)

            Text("当前应用仅展示本地导航与基础状态。")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColor.textPrimary)

            Text("未接入真实设备数据、媒体目录和事件流。")
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)

            HStack(spacing: AppSpacing.lg) {
                metricView(title: "已知设备", value: "\(deviceStore.devices.count)")
                metricView(title: "预览状态", value: "不可用")
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 10)
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)

            Text(value)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.small)
    }
}
