import SwiftUI

struct DeviceListView: View {
    @ObservedObject var store: DeviceListStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionCard(title: "项目状态") {
                    Text("设备列表已接入本地仓储占位实现。M1 会把 AP onboarding 和 DeviceSession 接进来。")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                }

                if store.devices.isEmpty {
                    EmptyStateView(
                        iconName: "externaldrive.badge.questionmark",
                        title: "还没有已知设备",
                        message: "完成真实接入后，这里会展示最近连接的设备和恢复入口。"
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
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("设备", displayMode: .large)
        .accessibility(identifier: "screen-device")
        .onAppear(perform: store.reload)
    }
}
