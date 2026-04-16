import SwiftUI

struct DashboardView: View {
    @ObservedObject var deviceStore: DeviceListStore
    @ObservedObject var livePreviewStore: LivePreviewStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "概览", subtitle: "Cam360 主导航骨架")

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
                            title: "相册入口已固定",
                            message: "媒体列表、筛选栏和底部动作菜单已预留到主壳层。",
                            tint: AppColor.brand
                        )

                        QuickActionCard(
                            iconName: "bell.badge.fill",
                            title: "事件中心已预留",
                            message: "事件列表、标签和后续处置链路会沿当前骨架继续接入。",
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
            StatusTag(title: "M0 Shell", tone: .accent)

            Text("主导航和通用 UI 组件已先对齐 Figma 的 4-tab 信息架构。")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColor.textPrimary)

            Text("设备、相册、事件、设置先固定入口和状态承载，真实会话、播放器和导出链路后续再接。")
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)

            HStack(spacing: AppSpacing.lg) {
                metricView(title: "已知设备", value: "\(deviceStore.devices.count)")
                metricView(title: "预览状态", value: "待接入")
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
