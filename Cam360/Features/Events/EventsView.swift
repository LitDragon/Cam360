import SwiftUI

struct EventsView: View {
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "事件",
                subtitle: "安全告警、停车守护和手动保存记录",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "入口状态") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            StatusTag(title: "占位", tone: .warning)

                            Text("当前通过首页最近事件入口进入；真实事件流确认前只展示离线分类和空态。")
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }

                    SectionCard(title: "事件类型") {
                        VStack(spacing: AppSpacing.md) {
                            EventsStatusRow(
                                iconName: "exclamationmark.octagon.fill",
                                title: "碰撞与急刹",
                                message: "等待真实事件流接入后展示高优先级安全事件。",
                                tone: .danger
                            )

                            EventsStatusRow(
                                iconName: "parkingsign.circle.fill",
                                title: "停车守护",
                                message: "停车监控事件恢复后会按时间线汇总。",
                                tone: .accent
                            )

                            EventsStatusRow(
                                iconName: "bookmark.fill",
                                title: "手动保存",
                                message: "手动标记片段仍通过相册和设备文件链路确认。",
                                tone: .neutral
                            )
                        }
                    }

                    EmptyStateView(
                        iconName: "bell.slash",
                        title: "暂无事件数据",
                        message: "离线阶段不展示模拟事件；真实事件列表会在设备事件通道确认后接入。"
                    )
                }
                .padding(AppSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-events")
    }
}

private struct EventsStatusRow: View {
    let iconName: String
    let title: String
    let message: String
    let tone: StatusTagTone

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var iconColor: Color {
        switch tone {
        case .accent:
            return AppColor.brand
        case .success:
            return AppColor.success
        case .warning:
            return AppColor.warning
        case .danger:
            return AppColor.danger
        case .neutral:
            return AppColor.textSecondary
        }
    }
}
