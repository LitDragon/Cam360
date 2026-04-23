import SwiftUI

struct GalleryView: View {
    @State private var selectedFilter: GalleryFilter = .all
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<GalleryItem.ID> = []
    @State private var activeMenuItemID: GalleryItem.ID?
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    @State private var items: [GalleryItem] = GalleryItem.sampleData

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

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                GalleryHeaderView(
                    isSelectionMode: isSelectionMode,
                    isSearchExpanded: isSearchExpanded,
                    selectionTitle: selectionTitle,
                    onDismissSelection: exitSelectionMode,
                    onToggleSearch: toggleSearch,
                    onEnterSelectionMode: enterSelectionMode
                )

                if isSelectionMode == false {
                    GalleryFilterBar(
                        selectedFilter: selectedFilter,
                        onSelect: selectFilter(_:)
                    )
                }

                if isSearchExpanded && isSelectionMode == false {
                    GallerySearchBar(text: $searchText)
                }

                if visibleSections.isEmpty {
                    GalleryEmptyState(message: emptyMessage)
                } else {
                    GallerySectionsList(
                        sections: visibleSections,
                        isSelectionMode: isSelectionMode,
                        selectedIDs: selectedIDs,
                        bottomPadding: isSelectionMode ? 132 : 28,
                        onTapItem: handleItemTap(_:),
                        onLongPressItem: handleItemLongPress(_:),
                        onMore: showItemMenu(_:)
                    )
                }
            }

            if isSelectionMode {
                GalleryBatchActionBar(
                    hasSelection: selectedIDs.isEmpty == false,
                    onDownload: handleBatchDownload,
                    onDelete: handleBatchDelete
                )
            }

            if let menuItem = activeMenuItem {
                GalleryActionSheet(
                    item: menuItem,
                    onDismiss: dismissItemMenu,
                    onDownload: handleMenuDownload,
                    onShare: handleMenuShare,
                    onDelete: handleMenuDelete
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
}

private extension GalleryView {
    func selectFilter(_ filter: GalleryFilter) {
        selectedFilter = filter
    }

    func toggleSearch() {
        isSearchExpanded.toggle()

        if isSearchExpanded == false {
            searchText = ""
        }
    }

    func enterSelectionMode() {
        isSearchExpanded = false
        searchText = ""
        isSelectionMode = true
        selectedIDs.removeAll()
    }

    func handleItemTap(_ item: GalleryItem) {
        guard isSelectionMode else {
            return
        }

        toggleSelection(for: item)
    }

    func handleItemLongPress(_ item: GalleryItem) {
        guard isSelectionMode == false else {
            return
        }

        isSearchExpanded = false
        searchText = ""
        isSelectionMode = true
        selectedIDs = Set([item.id])
    }

    func showItemMenu(_ item: GalleryItem) {
        activeMenuItemID = item.id
    }

    func dismissItemMenu() {
        activeMenuItemID = nil
    }

    func handleMenuDownload() {
        dismissItemMenu()
    }

    func handleMenuShare() {
        dismissItemMenu()
    }

    func handleMenuDelete() {
        guard let menuItem = activeMenuItem else {
            return
        }

        deleteItems(withIDs: [menuItem.id])
        dismissItemMenu()
    }

    func handleBatchDownload() {
        exitSelectionMode()
    }

    func handleBatchDelete() {
        deleteItems(withIDs: Array(selectedIDs))
        exitSelectionMode()
    }

    func toggleSelection(for item: GalleryItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedIDs.removeAll()
    }

    func deleteItems(withIDs ids: [GalleryItem.ID]) {
        let idSet = Set(ids)
        items.removeAll(where: { idSet.contains($0.id) })
        selectedIDs.subtract(idSet)
    }
}
