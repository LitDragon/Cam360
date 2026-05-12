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
    @Published private(set) var isLoadingItems: Bool
    @Published private(set) var lastLoadError: String?
    @Published private(set) var thumbnailsByPath: [String: DeviceFileThumbnail]

    private let deviceSession: DeviceSession?
    private var lastLoadedDeviceID: String?
    private var loadGeneration = 0
    private var cancellables: Set<AnyCancellable> = []

    convenience init(mediaProvider: GalleryMediaProviding = GallerySampleMediaProvider()) {
        self.init(items: mediaProvider.fetchItems())
    }

    convenience init(deviceSession: DeviceSession) {
        self.init(items: [], deviceSession: deviceSession)
    }

    init(items: [GalleryItem], deviceSession: DeviceSession? = nil) {
        selectedFilter = .all
        isSelectionMode = false
        selectedIDs = []
        activeMenuItemID = nil
        isSearchExpanded = false
        searchText = ""
        self.items = items
        isLoadingItems = false
        lastLoadError = nil
        thumbnailsByPath = [:]
        self.deviceSession = deviceSession

        bindDeviceSession()
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

    private func bindDeviceSession() {
        deviceSession?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncDeviceSessionState(state)
            }
            .store(in: &cancellables)
    }

    private func syncDeviceSessionState(_ state: DeviceSessionState) {
        switch state {
        case .ready(let deviceInfo):
            guard lastLoadedDeviceID != deviceInfo.id else {
                return
            }
            lastLoadedDeviceID = deviceInfo.id
            loadDeviceFiles()
        case .idle, .apConnecting, .handshaking, .failed, .disconnected:
            invalidateDeviceFiles()
        case .busy, .recovering:
            break
        }
    }

    private func loadDeviceFiles() {
        guard let deviceSession else {
            return
        }

        let generation = nextLoadGeneration()
        isLoadingItems = true
        lastLoadError = nil

        deviceSession.fetchFileList(query: DeviceFileListQuery(type: .video, page: 1, pageSize: 20)) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            switch result {
            case .success(let page):
                let files = page.files
                self.items = files.map(Self.galleryItem(from:))
                self.isLoadingItems = false
                self.lastLoadError = nil
                self.loadThumbnails(for: files, generation: generation)
            case .failure(.staleSession):
                break
            case .failure(let error):
                self.items = []
                self.thumbnailsByPath = [:]
                self.isLoadingItems = false
                self.lastLoadError = error.message
            }
        }
    }

    private func loadThumbnails(for files: [DeviceFileItem], generation: Int) {
        guard let deviceSession else {
            return
        }

        let paths = Array(files.filter(\.hasThumbnail).map(\.path).prefix(20))
        guard paths.isEmpty == false else {
            thumbnailsByPath = [:]
            return
        }

        deviceSession.fetchThumbnails(paths: paths) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            if case .success(let thumbnails) = result {
                self.thumbnailsByPath = Dictionary(uniqueKeysWithValues: thumbnails.map { ($0.path, $0) })
            }
        }
    }

    private func invalidateDeviceFiles() {
        lastLoadedDeviceID = nil
        loadGeneration += 1
        isLoadingItems = false
        lastLoadError = nil
        thumbnailsByPath = [:]
        items = []
        selectedIDs.removeAll()
        activeMenuItemID = nil
    }

    private func nextLoadGeneration() -> Int {
        loadGeneration += 1
        return loadGeneration
    }

    private func isCurrentLoad(_ generation: Int) -> Bool {
        generation == loadGeneration
    }

    nonisolated private static func galleryItem(from file: DeviceFileItem) -> GalleryItem {
        let kind = mediaKind(for: file)

        return GalleryItem(
            title: file.name,
            subtitle: subtitle(for: file),
            detail: detail(for: file),
            duration: formattedDuration(file.duration),
            kind: kind,
            section: section(for: file.createTime),
            thumbnailSymbol: thumbnailSymbol(for: kind, recordType: file.recordType),
            thumbnailStyle: thumbnailStyle(for: kind, recordType: file.recordType)
        )
    }

    nonisolated private static func mediaKind(for file: DeviceFileItem) -> GalleryMediaKind {
        if file.recordType == "emergency" || file.recordType == "parking" {
            return .event
        }

        let lowercasedName = file.name.lowercased()
        if lowercasedName.hasSuffix(".jpg") ||
            lowercasedName.hasSuffix(".jpeg") ||
            lowercasedName.hasSuffix(".png") {
            return .photo
        }

        return .video
    }

    nonisolated private static func subtitle(for file: DeviceFileItem) -> String {
        guard let createTime = file.createTime,
              let date = makeDeviceCreateTimeFormatter().date(from: createTime) else {
            return file.path
        }

        return makeDisplayTimeFormatter().string(from: date)
    }

    nonisolated private static func detail(for file: DeviceFileItem) -> String {
        var parts: [String] = []
        if let resolution = file.resolution {
            parts.append(resolution)
        }
        if let size = file.size {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        if file.locked {
            parts.append("LOCKED")
        }
        return parts.isEmpty ? file.path : parts.joined(separator: " · ")
    }

    nonisolated private static func formattedDuration(_ duration: Int?) -> String? {
        guard let duration else {
            return nil
        }

        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    nonisolated private static func section(for createTime: String?) -> GallerySectionKind {
        guard let createTime,
              let date = makeDeviceCreateTimeFormatter().date(from: createTime) else {
            return .earlier
        }

        if Calendar.current.isDateInToday(date) {
            return .today
        }
        if Calendar.current.isDateInYesterday(date) {
            return .yesterday
        }
        return .earlier
    }

    nonisolated private static func thumbnailSymbol(for kind: GalleryMediaKind, recordType: String?) -> String {
        if recordType == "emergency" {
            return "exclamationmark.triangle.fill"
        }
        if recordType == "parking" {
            return "parkingsign.circle.fill"
        }

        switch kind {
        case .event:
            return "car.fill"
        case .video:
            return "road.lanes"
        case .photo:
            return "camera.fill"
        }
    }

    nonisolated private static func thumbnailStyle(for kind: GalleryMediaKind, recordType: String?) -> GalleryArtworkStyle {
        if recordType == "emergency" {
            return .collisionAlert
        }
        if recordType == "parking" {
            return .parkingMonitor
        }

        switch kind {
        case .event:
            return .emergencyBrake
        case .video:
            return .dailyRecording
        case .photo:
            return .snapshot
        }
    }

    nonisolated private static func makeDeviceCreateTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter
    }

    nonisolated private static func makeDisplayTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
