import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "设置", subtitle: "本地状态与系统能力")

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "本地状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("已知设备数：\(store.knownDeviceCount)")
                            Text("已完成 onboarding：\(store.hasCompletedOnboarding ? "是" : "否")")
                            Text("iOS 17+ 现代增强：\(ModernFeatureAvailability.supportsModernEnhancements ? "可用" : "不可用")")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                    }

                    QuickActionCard(
                        iconName: "lock.shield",
                        title: "权限与系统能力",
                        message: "当前仅展示系统能力状态，不执行额外诊断逻辑。",
                        tint: AppColor.brand
                    )

                    SectionCard(title: "说明") {
                        Text("当前设置页仅包含本地状态展示和重置入口。")
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)
                    }

                    PrimaryButton(title: "重置到接入引导", action: store.resetShell)
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings")
        .onAppear(perform: store.refresh)
    }
}
