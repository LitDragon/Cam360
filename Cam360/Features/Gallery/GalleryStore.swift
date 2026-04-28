import Combine
import Foundation

final class GalleryStore: ObservableObject {
    @Published private(set) var selectedFilter: GalleryFilter
    @Published private(set) var isSelectionMode: Bool
    @Published private(set) var selectedIDs: Set<GalleryItem.ID>
    @Published private(set) var activeMenuItemID: GalleryItem.ID?
    @Published private(set) var isSearchExpanded: Bool
    @Published var searchText: String
    @Published private(set) var items: [GalleryItem]

    convenience init(mediaProvider: GalleryMediaProviding = GallerySampleMediaProvider()) {
        self.init(items: mediaProvider.fetchItems())
    }

    init(items: [GalleryItem]) {
        selectedFilter = .all
        isSelectionMode = false
        selectedIDs = []
        activeMenuItemID = nil
        isSearchExpanded = false
        searchText = ""
        self.items = items
    }

    var selectionTitle: String {
        selectedIDs.isEmpty ? "选择项目" : "已选择 \(selectedIDs.count) 项"
    }

    var activeMenuItem: GalleryItem? {
        guard let activeMenuItemID = activeMenuItemID else {
            return nil
        }

        return items.first(where: { $0.id == activeMenuItemID })
    }

    var visibleSections: [GallerySectionModel] {
        GallerySectionKind.allCases.compactMap { kind in
            let sectionItems = filteredItems.filter { $0.section == kind }
            guard sectionItems.isEmpty == false else {
                return nil
            }

            return GallerySectionModel(kind: kind, items: sectionItems)
        }
    }

    var emptyMessage: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "换个关键词再试试，或者切换上方筛选。"
        }

        return "当前筛选条件下没有可展示的媒体。"
    }

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

    func exitSelectionMode() {
        isSelectionMode = false
        selectedIDs.removeAll()
    }

    private var filteredItems: [GalleryItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            selectedFilter.matches(item) &&
            (trimmedQuery.isEmpty || item.matches(trimmedQuery))
        }
    }

    private func toggleSelection(for item: GalleryItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func deleteItems(withIDs ids: [GalleryItem.ID]) {
        let idSet = Set(ids)
        items.removeAll(where: { idSet.contains($0.id) })
        selectedIDs.subtract(idSet)
    }
}
