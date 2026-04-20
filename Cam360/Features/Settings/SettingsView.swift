import SwiftUI

struct SettingsView: View {
    @State private var shareAnonymousLogs = true

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "更多", subtitle: "设置与支持")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "应用偏好")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: "bell.badge",
                            title: "通知"
                        )

                        SettingsNavigationRow(
                            iconName: "shield",
                            title: "系统权限",
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "支持")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: "questionmark.circle",
                            title: "帮助中心",
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "诊断与维护")
                    SettingsGroupCard {
                        SettingsToggleRow(
                            iconName: "square.and.arrow.up",
                            title: "共享匿名日志",
                            subtitle: "帮助我们改进 App 稳定性",
                            isOn: $shareAnonymousLogs,
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "关于")
                    SettingsGroupCard {
                        SettingsStatusRow(
                            iconName: "info.circle",
                            title: "App 版本",
                            statusText: appVersionText
                        )

                        SettingsNavigationRow(
                            iconName: "hand.raised",
                            title: "隐私政策",
                            trailingSystemImage: "arrow.up.right.square"
                        )

                        SettingsNavigationRow(
                            iconName: "doc.text",
                            title: "服务条款",
                            trailingSystemImage: "arrow.up.right.square",
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
        .accessibility(identifier: "screen-settings")
    }

    private var appVersionText: String {
        guard let rawVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              rawVersion.isEmpty == false,
              rawVersion.contains("$(") == false else {
            return "v1.0"
        }

        return "v\(rawVersion)"
    }
}
