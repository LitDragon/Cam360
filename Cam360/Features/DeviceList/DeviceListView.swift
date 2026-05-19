import SwiftUI

// 未使用页面：当前没有导航入口，保留旧离线占位实现。
struct DeviceListView: View {
    @ObservedObject var store: DeviceListStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "设备",
                subtitle: "已知设备和发现入口状态",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "发现状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            StatusTag(title: "离线入口", tone: .warning)

                            Text("当前只展示本地已保存的设备。扫描、Wi-Fi 详情和连接结果仍由添加设备流程承载。")
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }

                    if store.devices.isEmpty {
                        EmptyStateView(
                            iconName: "externaldrive.badge.questionmark",
                            title: "还没有已知设备",
                            message: "完成添加设备流程后，这里会展示最近连接的设备和恢复入口。"
                        )
                    } else {
                        SectionCard(title: "已知设备") {
                            VStack(spacing: AppSpacing.md) {
                                ForEach(store.devices) { device in
                                    DeviceCell(device: device)
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-device")
        .onAppear(perform: store.reload)
    }
}
