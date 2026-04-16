import SwiftUI

private enum GalleryFilter: String, CaseIterable {
    case all = "全部"
    case event = "事件"
    case loop = "循环"
    case downloaded = "已下载"
}

private struct DemoMediaSection: Identifiable {
    let id: String
    let title: String
    let items: [DemoMediaItem]
}

private struct DemoMediaItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let duration: String
    let badgeTitle: String?
    let badgeTone: StatusTagTone
}

struct GalleryView: View {
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore

    @State private var selectedFilter: GalleryFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "相册", subtitle: "媒体列表与动作菜单骨架", trailingTitle: "选择")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    filterBar

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(section.title)
                                .font(AppTypography.sectionTitle)
                                .foregroundColor(AppColor.textPrimary)

                            ForEach(section.items) { item in
                                MediaListItem(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    duration: item.duration,
                                    badgeTitle: item.badgeTitle,
                                    badgeTone: item.badgeTone
                                )
                            }
                        }
                    }

                    QuickActionCard(
                        iconName: "arrow.down.circle",
                        title: downloadsStore.title,
                        message: downloadsStore.message,
                        tint: AppColor.brand
                    )

                    SectionCard(title: "后续接入点") {
                        Text(playbackStore.message)
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-gallery")
    }

    private var filterBar: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(GalleryFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    Text(filter.rawValue)
                        .font(AppTypography.caption)
                        .foregroundColor(selectedFilter == filter ? AppColor.brand : AppColor.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(selectedFilter == filter ? AppColor.accentSurface : AppColor.surface)
                        .cornerRadius(AppRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(
                                    selectedFilter == filter ? AppColor.brand.opacity(0.2) : AppColor.border.opacity(0.7),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var sections: [DemoMediaSection] {
        [
            DemoMediaSection(
                id: "today",
                title: "今天",
                items: [
                    DemoMediaItem(
                        id: "event-1",
                        title: "紧急事件",
                        subtitle: "10:15 AM • 停车场碰撞触发",
                        duration: "00:28",
                        badgeTitle: "事件",
                        badgeTone: .danger
                    ),
                    DemoMediaItem(
                        id: "loop-1",
                        title: "常规录制",
                        subtitle: "09:42 AM • 城市道路",
                        duration: "02:14",
                        badgeTitle: nil,
                        badgeTone: .neutral
                    )
                ]
            ),
            DemoMediaSection(
                id: "yesterday",
                title: "昨天",
                items: [
                    DemoMediaItem(
                        id: "event-2",
                        title: "停车守卫",
                        subtitle: "11:55 PM • 夜间移动侦测",
                        duration: "00:18",
                        badgeTitle: "停车",
                        badgeTone: .warning
                    )
                ]
            )
        ]
    }
}
