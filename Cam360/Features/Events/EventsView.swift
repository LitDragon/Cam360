import SwiftUI

struct EventsView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "事件", subtitle: "设备告警与事件记录")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    QuickActionCard(
                        iconName: "bolt.badge.clock",
                        title: "事件通知",
                        message: "当前未接入推送和告警服务。",
                        tint: AppColor.warning
                    )

                    EmptyStateView(
                        iconName: "bell.badge",
                        title: "还没有事件",
                        message: "当前没有可展示的事件记录。"
                    )
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-events")
    }

}
