import SwiftUI

private struct DemoEvent: Identifiable {
    let id: String
    let title: String
    let summary: String
    let duration: String
    let badgeTitle: String
    let badgeTone: StatusTagTone
}

struct EventsView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "事件", subtitle: "告警列表与处置入口骨架")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    HStack(spacing: AppSpacing.md) {
                        summaryCard(title: "高优先", value: "2", tone: .danger)
                        summaryCard(title: "待复核", value: "3", tone: .warning)
                    }

                    QuickActionCard(
                        iconName: "bolt.badge.clock",
                        title: "事件通知与推送待接入",
                        message: "当前先固定时间线、状态标签和后续跳转入口，不落地真实告警链路。",
                        tint: AppColor.warning
                    )

                    SectionCard(title: "最近事件") {
                        VStack(spacing: AppSpacing.md) {
                            ForEach(events) { event in
                                MediaListItem(
                                    title: event.title,
                                    subtitle: event.summary,
                                    duration: event.duration,
                                    badgeTitle: event.badgeTitle,
                                    badgeTone: event.badgeTone
                                )
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-events")
    }

    private func summaryCard(title: String, value: String, tone: StatusTagTone) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            StatusTag(title: title, tone: tone)

            Text(value)
                .font(AppTypography.pageTitle)
                .foregroundColor(AppColor.textPrimary)

            Text("事件骨架")
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
    }

    private var events: [DemoEvent] {
        [
            DemoEvent(
                id: "event-1",
                title: "碰撞告警",
                summary: "今天 10:15 AM • 地下停车场",
                duration: "00:28",
                badgeTitle: "紧急",
                badgeTone: .danger
            ),
            DemoEvent(
                id: "event-2",
                title: "停车监控",
                summary: "今天 08:42 AM • 车辆周边活动",
                duration: "00:14",
                badgeTitle: "停车",
                badgeTone: .warning
            ),
            DemoEvent(
                id: "event-3",
                title: "异常震动",
                summary: "昨天 11:55 PM • 高架桥下",
                duration: "00:21",
                badgeTitle: "复核",
                badgeTone: .accent
            )
        ]
    }
}
