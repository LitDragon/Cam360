import SwiftUI

struct DeviceOnboardingView: View {
    @ObservedObject var store: DeviceOnboardingStore

    var body: some View {
        PermissionPageView(
            iconName: "wifi",
            title: "连接你的行车记录仪",
            message: "M0 阶段先完成可运行框架。这里预留热点接入、权限说明和失败分流入口，真实 AP onboarding 在 M1 接入。",
            primaryTitle: "进入应用框架",
            primaryAction: store.enterScaffold,
            secondaryTitle: "清空占位数据",
            secondaryAction: store.clearPlaceholderData
        )
        .navigationBarTitle("设备接入", displayMode: .inline)
        .accessibility(identifier: "screen-onboarding")
    }
}
