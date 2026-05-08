import SwiftUI

struct GalleryView: View {
    @ObservedObject var store: GalleryStore
    var onOpenPlayback: () -> Void = {}
    var onOpenDownloads: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                GalleryHeaderView(
                    isSelectionMode: store.isSelectionMode,
                    isSearchExpanded: store.isSearchExpanded,
                    selectionTitle: store.selectionTitle,
                    onDismissSelection: store.exitSelectionMode,
                    onToggleSearch: store.toggleSearch,
                    onEnterSelectionMode: store.enterSelectionMode
                )

                if store.isSelectionMode == false {
                    GalleryFilterBar(
                        selectedFilter: store.selectedFilter,
                        onSelect: store.selectFilter(_:)
                    )
                }

                if store.isSearchExpanded && store.isSelectionMode == false {
                    GallerySearchBar(text: $store.searchText)
                }

                if store.visibleSections.isEmpty {
                    GalleryEmptyState(message: store.emptyMessage)
                } else {
                    GallerySectionsList(
                        sections: store.visibleSections,
                        isSelectionMode: store.isSelectionMode,
                        selectedIDs: store.selectedIDs,
                        bottomPadding: store.isSelectionMode ? 132 : 28,
                        onTapItem: handleItemTap(_:),
                        onLongPressItem: store.handleItemLongPress(_:),
                        onMore: store.showItemMenu(_:)
                    )
                }
            }

            if store.isSelectionMode {
                GalleryBatchActionBar(
                    hasSelection: store.selectedIDs.isEmpty == false,
                    onDownload: handleBatchDownload,
                    onDelete: store.handleBatchDelete
                )
            }

            if let menuItem = store.activeMenuItem {
                GalleryActionSheet(
                    item: menuItem,
                    onDismiss: store.dismissItemMenu,
                    onDownload: handleMenuDownload,
                    onShare: store.handleMenuShare,
                    onDelete: store.handleMenuDelete
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-gallery")
        .animation(.easeInOut(duration: 0.2), value: store.isSelectionMode)
        .animation(.easeInOut(duration: 0.2), value: store.selectedIDs)
        .animation(.easeInOut(duration: 0.2), value: store.activeMenuItemID)
        .animation(.easeInOut(duration: 0.2), value: store.selectedFilter)
        .animation(.easeInOut(duration: 0.2), value: store.isSearchExpanded)
    }

    private func handleItemTap(_ item: GalleryItem) {
        store.handleItemTap(item)

        if store.isSelectionMode == false {
            onOpenPlayback()
        }
    }

    private func handleMenuDownload() {
        store.handleMenuDownload()
        onOpenDownloads()
    }

    private func handleBatchDownload() {
        store.handleBatchDownload()
        onOpenDownloads()
    }
}
