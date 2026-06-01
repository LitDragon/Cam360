import Foundation
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

                    if store.visibleEvents.isEmpty == false {
                        SectionCard(title: "事件列表") {
                            VStack(spacing: AppSpacing.md) {
                                ForEach(Array(store.visibleEvents.enumerated()), id: \.element.id) { index, event in
                                    EventTimelineRow(
                                        event: event,
                                        isActive: index == 0,
                                        iconName: iconName(for: event.eventType),
                                        tone: tone(for: event.eventType)
                                    )
                                }
                            }
                        }
                    }

                    if store.visibleEvents.isEmpty {
                        EmptyStateView(
                            iconName: "bell.slash",
                            title: store.emptyTitle,
                            message: store.emptyMessage
                        )
                    }
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

private struct EventTimelineRow: View {
    let event: DeviceRecentEventItem
    let isActive: Bool
    let iconName: String
    let tone: StatusTagTone

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            EventThumbnailView(
                iconName: iconName,
                tone: tone,
                isActive: isActive,
                isLocked: event.locked,
                thumbReady: event.thumbReady
            )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Text(event.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)

                    if isActive {
                        StatusTag(title: "ACTIVE", tone: .accent, size: .compact)
                    }
                }

                Text(event.createTime ?? event.path ?? "Event media")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.sm) {
                    if let duration = event.duration {
                        Text(Self.durationText(duration))
                    }

                    if let size = event.size {
                        Text(Self.sizeText(size))
                    }

                    if event.locked {
                        Text("Locked")
                    }
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppColor.surface)
                    .cornerRadius(AppRadius.small)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(true)
        }
        .padding(AppSpacing.md)
        .background(isActive ? AppColor.accentSurface : AppColor.surfaceMuted)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(isActive ? AppColor.brand.opacity(0.28) : Color.clear, lineWidth: 1)
        )
    }

    private static func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private static func sizeText(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct EventThumbnailView: View {
    let iconName: String
    let tone: StatusTagTone
    let isActive: Bool
    let isLocked: Bool
    let thumbReady: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                gradient: Gradient(colors: backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            VStack {
                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    Text(thumbReady ? "THUMB" : "INDEX")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.42))
                        .cornerRadius(3)
                        .padding(4)
                }
            }

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
            }
        }
        .frame(width: 78, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .stroke(isActive ? Color.white.opacity(0.7) : Color.clear, lineWidth: 1)
        )
    }

    private var backgroundColors: [Color] {
        switch tone {
        case .danger:
            return [
                Color(red: 0.76, green: 0.2, blue: 0.18),
                Color(red: 0.36, green: 0.08, blue: 0.12)
            ]
        case .accent:
            return [
                Color(red: 0.12, green: 0.48, blue: 0.78),
                Color(red: 0.08, green: 0.22, blue: 0.42)
            ]
        case .success:
            return [
                Color(red: 0.22, green: 0.58, blue: 0.34),
                Color(red: 0.1, green: 0.28, blue: 0.18)
            ]
        case .warning:
            return [
                Color(red: 0.82, green: 0.55, blue: 0.2),
                Color(red: 0.42, green: 0.24, blue: 0.1)
            ]
        case .neutral:
            return [
                Color(red: 0.45, green: 0.48, blue: 0.56),
                Color(red: 0.18, green: 0.2, blue: 0.26)
            ]
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
