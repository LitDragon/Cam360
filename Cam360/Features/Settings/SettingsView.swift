import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "设置", subtitle: "本地占位配置与壳状态")

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
                        message: "系统权限页、帮助页和后续诊断入口会继续沿这套卡片骨架扩展。",
                        tint: AppColor.brand
                    )

                    SectionCard(title: "项目说明") {
                        Text("M0 只提供最小设计系统、路由和依赖注入。设备设置读写、诊断和本地偏好细化会在后续里程碑继续补齐。")
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
