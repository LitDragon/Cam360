import SwiftUI

struct GalleryView: View {
    @State private var selectedFilter: GalleryFilter = .all
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<GalleryItem.ID> = []
    @State private var activeMenuItemID: GalleryItem.ID?
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    @State private var items: [GalleryItem] = GalleryItem.sampleData

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header

                if isSelectionMode == false {
                    filterBar
                }

                if isSearchExpanded && isSelectionMode == false {
                    searchBar
                }

                if visibleSections.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppSpacing.xl) {
                            ForEach(visibleSections) { section in
                                GallerySectionBlock(
                                    section: section,
                                    isSelectionMode: isSelectionMode,
                                    selectedIDs: selectedIDs,
                                    onTapItem: handleItemTap(_:),
                                    onLongPressItem: handleItemLongPress(_:),
                                    onMore: {
                                        activeMenuItemID = $0.id
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.xxl)
                        .padding(.top, AppSpacing.xl)
                        .padding(.bottom, isSelectionMode ? 132 : 28)
                    }
                }
            }

            if isSelectionMode {
                batchActionBar
            }

            if let menuItem = activeMenuItem {
                GalleryActionSheet(
                    item: menuItem,
                    onDismiss: {
                        activeMenuItemID = nil
                    },
                    onDownload: {
                        activeMenuItemID = nil
                    },
                    onShare: {
                        activeMenuItemID = nil
                    },
                    onDelete: {
                        deleteItems(withIDs: [menuItem.id])
                        activeMenuItemID = nil
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-gallery")
        .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
        .animation(.easeInOut(duration: 0.2), value: selectedIDs)
        .animation(.easeInOut(duration: 0.2), value: activeMenuItemID)
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
        .animation(.easeInOut(duration: 0.2), value: isSearchExpanded)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                if isSelectionMode {
                    Button(action: exitSelectionMode) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(selectionTitle)
                        .font(AppTypography.navigationTitle)
                        .foregroundColor(AppColor.textPrimary)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("相册")
                            .font(AppTypography.navigationTitle)
                            .foregroundColor(AppColor.textPrimary)

                        Text("本地录制、事件片段与抓拍照片")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                if isSelectionMode {
                    Button("取消", action: exitSelectionMode)
                        .buttonStyle(PlainButtonStyle())
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.brand)
                } else {
                    HStack(spacing: AppSpacing.sm) {
                        Button(action: toggleSearch) {
                            Image(systemName: isSearchExpanded ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(isSearchExpanded ? AppColor.textSecondary : AppColor.brand)
                                .frame(width: 36, height: 36)
                                .background(AppColor.surfaceMuted)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            isSearchExpanded = false
                            searchText = ""
                            isSelectionMode = true
                            selectedIDs.removeAll()
                        }) {
                            Text("选择")
                                .font(AppTypography.bodyStrong)
                                .foregroundColor(AppColor.brand)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.surface)
        .overlay(
            Rectangle()
                .fill(AppColor.border.opacity(0.8))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(GalleryFilter.allCases) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.title)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(selectedFilter == filter ? .white : AppColor.textSecondary)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(selectedFilter == filter ? AppColor.brand : AppColor.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.background)
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            TextField("搜索媒体", text: $searchText)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: 0)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38, weight: .regular))
                .foregroundColor(AppColor.textSecondary)

            VStack(spacing: AppSpacing.sm) {
                Text("暂无匹配内容")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text(emptyMessage)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xxl)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var batchActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            GalleryFooterButton(
                title: "下载到本机",
                systemImage: "arrow.down.circle",
                isDestructive: false,
                isEnabled: selectedIDs.isEmpty == false,
                action: {
                    exitSelectionMode()
                }
            )

            GalleryFooterButton(
                title: "删除",
                systemImage: "trash",
                isDestructive: true,
                isEnabled: selectedIDs.isEmpty == false,
                action: {
                    deleteItems(withIDs: Array(selectedIDs))
                    exitSelectionMode()
                }
            )
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(AppColor.border.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.lg)
    }

    private var selectionTitle: String {
        selectedIDs.isEmpty ? "选择项目" : "已选择 \(selectedIDs.count) 项"
    }

    private var activeMenuItem: GalleryItem? {
        guard let activeMenuItemID = activeMenuItemID else {
            return nil
        }

        return items.first(where: { $0.id == activeMenuItemID })
    }

    private var visibleSections: [GallerySectionModel] {
        GallerySectionKind.allCases.compactMap { kind in
            let sectionItems = filteredItems.filter { $0.section == kind }
            guard sectionItems.isEmpty == false else {
                return nil
            }

            return GallerySectionModel(kind: kind, items: sectionItems)
        }
    }

    private var filteredItems: [GalleryItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            selectedFilter.matches(item) &&
            (trimmedQuery.isEmpty || item.matches(trimmedQuery))
        }
    }

    private var emptyMessage: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "换个关键词再试试，或者切换上方筛选。"
        }

        return "当前筛选条件下没有可展示的媒体。"
    }

    private func toggleSearch() {
        isSearchExpanded.toggle()

        if isSearchExpanded == false {
            searchText = ""
        }
    }

    private func handleItemTap(_ item: GalleryItem) {
        guard isSelectionMode else {
            return
        }

        toggleSelection(for: item)
    }

    private func handleItemLongPress(_ item: GalleryItem) {
        guard isSelectionMode == false else {
            return
        }

        isSearchExpanded = false
        searchText = ""
        isSelectionMode = true
        toggleSelection(for: item)
    }

    private func toggleSelection(for item: GalleryItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedIDs.removeAll()
    }

    private func deleteItems(withIDs ids: [GalleryItem.ID]) {
        let idSet = Set(ids)
        items.removeAll(where: { idSet.contains($0.id) })
        selectedIDs.subtract(idSet)
    }
}

private enum GalleryFilter: CaseIterable, Identifiable, Equatable {
    case all
    case events
    case videos
    case photos

    var id: String { title }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .events:
            return "事件"
        case .videos:
            return "视频"
        case .photos:
            return "照片"
        }
    }

    func matches(_ item: GalleryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .events:
            return item.kind == .event
        case .videos:
            return item.kind == .video
        case .photos:
            return item.kind == .photo
        }
    }
}

private enum GallerySectionKind: CaseIterable, Hashable {
    case today
    case yesterday
    case earlier

    var title: String {
        switch self {
        case .today:
            return "今天"
        case .yesterday:
            return "昨天"
        case .earlier:
            return "更早"
        }
    }

    var trailingText: String {
        switch self {
        case .today:
            return "最近"
        case .yesterday:
            return "昨日"
        case .earlier:
            return "历史"
        }
    }
}

private enum GalleryMediaKind: Equatable {
    case event
    case video
    case photo
}

private struct GallerySectionModel: Identifiable {
    let kind: GallerySectionKind
    let items: [GalleryItem]

    var id: GallerySectionKind { kind }
}

private struct GalleryItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let detail: String
    let duration: String?
    let kind: GalleryMediaKind
    let section: GallerySectionKind
    let thumbnailSymbol: String
    let thumbnailColors: [Color]

    var badgeTitle: String? {
        kind == .event ? "紧急事件" : nil
    }

    var badgeTone: StatusTagTone {
        kind == .event ? .danger : .neutral
    }

    func matches(_ keyword: String) -> Bool {
        let normalizedKeyword = keyword.lowercased()
        return title.lowercased().contains(normalizedKeyword) ||
            subtitle.lowercased().contains(normalizedKeyword) ||
            detail.lowercased().contains(normalizedKeyword)
    }

    static let sampleData: [GalleryItem] = [
        GalleryItem(
            title: "紧急刹车",
            subtitle: "10:15",
            detail: "4K · 245 MB",
            duration: "00:45",
            kind: .event,
            section: .today,
            thumbnailSymbol: "car.fill",
            thumbnailColors: [
                Color(red: 0.09, green: 0.20, blue: 0.32),
                Color(red: 0.36, green: 0.52, blue: 0.72)
            ]
        ),
        GalleryItem(
            title: "日常录制",
            subtitle: "09:42",
            detail: "4K · 245 MB",
            duration: "03:00",
            kind: .video,
            section: .today,
            thumbnailSymbol: "road.lanes",
            thumbnailColors: [
                Color(red: 0.13, green: 0.32, blue: 0.29),
                Color(red: 0.47, green: 0.67, blue: 0.40)
            ]
        ),
        GalleryItem(
            title: "停车监控",
            subtitle: "08:12",
            detail: "4K · 245 MB",
            duration: "03:00",
            kind: .event,
            section: .today,
            thumbnailSymbol: "parkingsign.circle.fill",
            thumbnailColors: [
                Color(red: 0.34, green: 0.25, blue: 0.15),
                Color(red: 0.72, green: 0.57, blue: 0.34)
            ]
        ),
        GalleryItem(
            title: "高速抓拍",
            subtitle: "18:45",
            detail: "12 MP · 6.2 MB",
            duration: nil,
            kind: .photo,
            section: .yesterday,
            thumbnailSymbol: "camera.macro",
            thumbnailColors: [
                Color(red: 0.11, green: 0.25, blue: 0.20),
                Color(red: 0.45, green: 0.66, blue: 0.53)
            ]
        ),
        GalleryItem(
            title: "晚高峰录制",
            subtitle: "17:08",
            detail: "1080P · 182 MB",
            duration: "02:10",
            kind: .video,
            section: .yesterday,
            thumbnailSymbol: "tram.fill",
            thumbnailColors: [
                Color(red: 0.18, green: 0.16, blue: 0.33),
                Color(red: 0.51, green: 0.35, blue: 0.63)
            ]
        ),
        GalleryItem(
            title: "碰撞提醒",
            subtitle: "前天 22:12",
            detail: "4K · 301 MB",
            duration: "01:30",
            kind: .event,
            section: .earlier,
            thumbnailSymbol: "exclamationmark.triangle.fill",
            thumbnailColors: [
                Color(red: 0.35, green: 0.12, blue: 0.18),
                Color(red: 0.76, green: 0.33, blue: 0.28)
            ]
        )
    ]
}

private struct GallerySectionBlock: View {
    let section: GallerySectionModel
    let isSelectionMode: Bool
    let selectedIDs: Set<GalleryItem.ID>
    let onTapItem: (GalleryItem) -> Void
    let onLongPressItem: (GalleryItem) -> Void
    let onMore: (GalleryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(section.kind.title)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColor.textPrimary)

                Spacer(minLength: 0)

                Text("\(section.items.count) 项 · \(section.kind.trailingText)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            VStack(spacing: AppSpacing.md) {
                ForEach(section.items) { item in
                    GalleryMediaCard(
                        item: item,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedIDs.contains(item.id),
                        onTap: {
                            onTapItem(item)
                        },
                        onLongPress: {
                            onLongPressItem(item)
                        },
                        onMore: {
                            onMore(item)
                        }
                    )
                }
            }
        }
    }
}

private struct GalleryMediaCard: View {
    let item: GalleryItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if isSelectionMode {
                selectionIndicator
            }

            GalleryThumbnail(item: item)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(item.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)

                Text(item.detail)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer(minLength: 0)

            if isSelectionMode == false {
                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(perform: onLongPress)
    }

    private var selectionIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(isSelected ? AppColor.brand : AppColor.surfaceMuted)
                .frame(width: 24, height: 24)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var cardBackground: Color {
        isSelected ? AppColor.accentSurface : AppColor.surface
    }

    private var cardBorderColor: Color {
        isSelected ? AppColor.brand.opacity(0.28) : AppColor.border.opacity(0.7)
    }
}

private struct GalleryThumbnail: View {
    let item: GalleryItem

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: item.thumbnailColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 128, height: 78)

            Image(systemName: item.thumbnailSymbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))
                .frame(width: 128, height: 78)

            if let badgeTitle = item.badgeTitle {
                StatusTag(title: badgeTitle, tone: item.badgeTone)
                    .padding(AppSpacing.xs)
            }

            if item.kind != .photo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 128, height: 78)
            }

            VStack {
                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    if let duration = item.duration {
                        Text(duration)
                            .font(AppTypography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.black.opacity(0.32))
                            .cornerRadius(AppRadius.small)
                            .padding(AppSpacing.xs)
                    } else {
                        Text("照片")
                            .font(AppTypography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.black.opacity(0.32))
                            .cornerRadius(AppRadius.small)
                            .padding(AppSpacing.xs)
                    }
                }
            }
        }
    }
}

private struct GalleryActionSheet: View {
    let item: GalleryItem
    let onDismiss: () -> Void
    let onDownload: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.24)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture(perform: onDismiss)

            VStack(spacing: AppSpacing.lg) {
                Capsule()
                    .fill(AppColor.border)
                    .frame(width: 44, height: 5)
                    .padding(.top, AppSpacing.sm)

                HStack(spacing: AppSpacing.md) {
                    GalleryThumbnail(item: item)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(item.title)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.textPrimary)

                        Text(item.subtitle)
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)

                        Text(item.detail)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.lg)

                VStack(spacing: AppSpacing.xs) {
                    GallerySheetActionRow(
                        title: "下载到本机",
                        systemImage: "arrow.down.circle",
                        tint: AppColor.brand,
                        isDestructive: false,
                        action: onDownload
                    )

                    GallerySheetActionRow(
                        title: "分享",
                        systemImage: "square.and.arrow.up",
                        tint: AppColor.brand,
                        isDestructive: false,
                        action: onShare
                    )

                    GallerySheetActionRow(
                        title: "删除",
                        systemImage: "trash",
                        tint: AppColor.danger,
                        isDestructive: true,
                        action: onDelete
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.xLarge)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
    }
}

private struct GallerySheetActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(tint)
                }

                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(isDestructive ? AppColor.danger : AppColor.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.background)
            .cornerRadius(AppRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct GalleryFooterButton: View {
    let title: String
    let systemImage: String
    let isDestructive: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(AppTypography.bodyStrong)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .background(backgroundColor)
            .cornerRadius(AppRadius.large)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var foregroundColor: Color {
        isDestructive ? .white : AppColor.brand
    }

    private var backgroundColor: Color {
        isDestructive ? AppColor.danger : AppColor.accentSurface
    }
}
