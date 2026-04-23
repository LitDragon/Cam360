import SwiftUI

struct DeviceOnboardingView: View {
    @ObservedObject var store: DeviceOnboardingStore

    var body: some View {
        PermissionPageView(
            iconName: "wifi",
            title: "连接你的行车记录仪",
            message: "当前未接入真实设备发现与连接能力。",
            primaryTitle: "进入应用",
            primaryAction: store.enterScaffold,
            secondaryTitle: "清空本地状态",
            secondaryAction: store.clearPlaceholderData
        )
        .navigationBarTitle("设备接入", displayMode: .inline)
        .accessibility(identifier: "screen-onboarding")
    }
}
