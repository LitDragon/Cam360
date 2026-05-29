import SwiftUI

struct EventsView: View {
    @ObservedObject var store: EventsStore
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
                            StatusTag(title: store.statusTitle, tone: feedStatusTone)

                            Text(store.statusMessage)
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)

                            PrimaryButton(
                                title: store.refreshButtonTitle,
                                isEnabled: store.canRefreshEvents,
                                leadingSystemImageName: "arrow.clockwise",
                                action: store.refreshEvents
                            )
                        }
                    }

                    SectionCard(title: "事件筛选") {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(EventsFilter.allCases, id: \.self) { filter in
                                EventsFilterButton(
                                    title: filter.rawValue,
                                    isSelected: store.selectedFilter == filter
                                ) {
                                    store.selectedFilter = filter
                                }
                            }
                        }
                    }

                    SectionCard(title: "事件类型") {
                        VStack(spacing: AppSpacing.md) {
                            ForEach(store.visibleCategories) { category in
                                EventsStatusRow(
                                    iconName: category.iconName,
                                    title: category.title,
                                    message: category.message,
                                    tone: category.tone
                                )
                            }
                        }
                    }

                    if store.recentEvents.isEmpty == false {
                        SectionCard(title: "最近事件") {
                            VStack(spacing: AppSpacing.md) {
                                ForEach(store.recentEvents) { event in
                                    EventsStatusRow(
                                        iconName: iconName(for: event.eventType),
                                        title: event.title,
                                        message: event.createTime ?? event.path ?? "Recent event",
                                        tone: tone(for: event.eventType)
                                    )
                                }
                            }
                        }
                    }

                    EmptyStateView(
                        iconName: "bell.slash",
                        title: store.emptyTitle,
                        message: store.emptyMessage
                    )
                }
                .padding(AppSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-events")
    }

    private var feedStatusTone: StatusTagTone {
        switch store.feedState {
        case .empty:
            return .neutral
        case .refreshing:
            return .accent
        case .available:
            return .success
        case .unavailable:
            return .warning
        }
    }

    private func iconName(for eventType: String) -> String {
        switch eventType {
        case "impact", "emergency":
            return "exclamationmark.octagon.fill"
        case "parking":
            return "parkingsign.circle.fill"
        case "manual":
            return "bookmark.fill"
        default:
            return "bell.fill"
        }
    }

    private func tone(for eventType: String) -> StatusTagTone {
        switch eventType {
        case "impact", "emergency":
            return .danger
        case "parking", "motion":
            return .accent
        default:
            return .neutral
        }
    }
}

private struct EventsFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(isSelected ? .white : AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? AppColor.brand : AppColor.surfaceMuted)
                .cornerRadius(AppRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
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
