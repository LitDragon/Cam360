import SwiftUI

struct EventsView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "事件", subtitle: "告警列表与处置入口")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    HStack(spacing: AppSpacing.md) {
                        summaryCard(title: "高优先", value: "-", tone: .danger)
                        summaryCard(title: "待复核", value: "-", tone: .warning)
                    }

                    QuickActionCard(
                        iconName: "bolt.badge.clock",
                        title: "事件通知与推送待接入",
                        message: "当前先固定时间线、状态标签和后续跳转入口，不落地真实告警链路。",
                        tint: AppColor.warning
                    )

                    EmptyStateView(
                        iconName: "bell.slash",
                        title: "暂无事件记录",
                        message: "完成设备接入后，事件记录将在此展示。"
                    )
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

            Text(title)
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
}
