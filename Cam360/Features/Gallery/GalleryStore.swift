import Combine
import Foundation

final class GalleryStore: ObservableObject {
    private static let thumbnailListBatchSize = 20

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
        guard deviceSession != nil else {
            return
        }

        let generation = nextLoadGeneration()
        isLoadingItems = true
        lastLoadError = nil

        loadMediaIndexes(
            mediaTypes: ArraySlice([DeviceFileType.video, .photo]),
            generation: generation,
            collectedFiles: []
        )
    }

    private func loadMediaIndexes(
        mediaTypes: ArraySlice<DeviceFileType>,
        generation: Int,
        collectedFiles: [DeviceMediaIndexItem]
    ) {
        guard let deviceSession else {
            return
        }

        guard let mediaType = mediaTypes.first else {
            applyLoadedDeviceFiles(collectedFiles, generation: generation)
            return
        }

        deviceSession.fetchMediaIndex(query: DeviceMediaIndexQuery(mediaType: mediaType, groupBy: .date, pageSize: 20)) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            switch result {
            case .success(let index):
                let files = index.groups.flatMap(\.items)
                self.loadMediaIndexes(
                    mediaTypes: mediaTypes.dropFirst(),
                    generation: generation,
                    collectedFiles: collectedFiles + files
                )
            case .failure(.staleSession):
                break
            case .failure(let error):
                if collectedFiles.isEmpty {
                    self.items = []
                    self.thumbnailsByPath = [:]
                    self.isLoadingItems = false
                    self.lastLoadError = error.message
                } else {
                    self.applyLoadedDeviceFiles(
                        collectedFiles,
                        generation: generation,
                        lastLoadError: error.message
                    )
                }
            }
        }
    }

    private func applyLoadedDeviceFiles(
        _ files: [DeviceMediaIndexItem],
        generation: Int,
        lastLoadError: String? = nil
    ) {
        let uniqueFiles = uniqueMediaIndexItems(files)
        items = uniqueFiles.map(Self.galleryItem(from:))
        isLoadingItems = false
        self.lastLoadError = lastLoadError
        loadThumbnails(for: uniqueFiles, generation: generation)
    }

    private func uniqueMediaIndexItems(_ files: [DeviceMediaIndexItem]) -> [DeviceMediaIndexItem] {
        var seenPaths: Set<String> = []
        return files.filter { file in
            seenPaths.insert(file.path).inserted
        }
    }

    private func loadThumbnails(for files: [DeviceMediaIndexItem], generation: Int) {
        let paths = files.filter(\.hasThumbnail).map(\.path)
        guard paths.isEmpty == false else {
            thumbnailsByPath = [:]
            return
        }

        thumbnailsByPath = [:]
        loadThumbnailBatches(ArraySlice(Self.thumbnailPathBatches(from: paths)), generation: generation)
    }

    private func loadThumbnailBatches(_ batches: ArraySlice<[String]>, generation: Int) {
        guard let paths = batches.first else {
            return
        }

        loadThumbnailBatch(paths, generation: generation) { [weak self] in
            self?.loadThumbnailBatches(batches.dropFirst(), generation: generation)
        }
    }

    private func loadThumbnailBatch(
        _ paths: [String],
        generation: Int,
        completion: @escaping () -> Void
    ) {
        guard let deviceSession else {
            completion()
            return
        }

        deviceSession.fetchThumbnails(paths: paths) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            switch result {
            case .success(let thumbnails):
                self.applyThumbnails(thumbnails)

                let loadedPaths = Set(thumbnails.map(\.path))
                let missingPaths = paths.filter { loadedPaths.contains($0) == false }
                missingPaths.forEach { path in
                    deviceSession.fetchThumbnail(path: path) { [weak self] result in
                        guard let self, self.isCurrentLoad(generation),
                              case .success(let thumbnail) = result else {
                            return
                        }

                        self.applyThumbnails([thumbnail])
                    }
                }
                completion()
            case .failure(let error):
                guard Self.shouldReduceThumbnailBatch(for: error, pathCount: paths.count) else {
                    completion()
                    return
                }

                self.loadReducedThumbnailBatch(paths, generation: generation, completion: completion)
            }
        }
    }

    private func loadReducedThumbnailBatch(
        _ paths: [String],
        generation: Int,
        completion: @escaping () -> Void
    ) {
        let splitIndex = max(1, paths.count / 2)
        let firstBatch = Array(paths.prefix(splitIndex))
        let secondBatch = Array(paths.dropFirst(splitIndex))

        loadThumbnailBatch(firstBatch, generation: generation) { [weak self] in
            self?.loadThumbnailBatch(secondBatch, generation: generation, completion: completion)
        }
    }

    private func applyThumbnails(_ thumbnails: [DeviceFileThumbnail]) {
        thumbnails.forEach { thumbnail in
            thumbnailsByPath[thumbnail.path] = thumbnail
        }
        items = items.map { item in
            guard let devicePath = item.devicePath,
                  let thumbnail = thumbnailsByPath[devicePath] else {
                return item
            }
            return item.withThumbnailImageBase64(thumbnail.imageBase64)
        }
    }

    private static func shouldReduceThumbnailBatch(for error: DeviceSessionReadOnlyError, pathCount: Int) -> Bool {
        guard pathCount > 1,
              case .protocolFailure(.deviceError(let errno, let topic, _)) = error else {
            return false
        }

        return errno == -7 && topic == "THUMB_LIST"
    }

    private static func thumbnailPathBatches(from paths: [String]) -> [[String]] {
        stride(from: 0, to: paths.count, by: thumbnailListBatchSize).map { startIndex in
            let endIndex = min(startIndex + thumbnailListBatchSize, paths.count)
            return Array(paths[startIndex..<endIndex])
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
            devicePath: file.path,
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

    nonisolated private static func galleryItem(from file: DeviceMediaIndexItem) -> GalleryItem {
        let kind = mediaKind(for: file)

        return GalleryItem(
            devicePath: file.path,
            title: file.title ?? file.name,
            subtitle: subtitle(for: file.createTime),
            detail: detail(for: file),
            duration: formattedDuration(file.duration),
            kind: kind,
            section: section(for: file.createTime),
            thumbnailSymbol: thumbnailSymbol(for: kind, recordType: file.eventType),
            thumbnailStyle: thumbnailStyle(for: kind, recordType: file.eventType)
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

    nonisolated private static func mediaKind(for file: DeviceMediaIndexItem) -> GalleryMediaKind {
        if file.mediaType == .photo {
            return .photo
        }

        if let eventType = file.eventType, eventType != "normal" {
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
        subtitle(for: file.createTime, fallback: file.path)
    }

    nonisolated private static func subtitle(for createTime: String?, fallback: String = "") -> String {
        guard let createTime,
              let date = makeDeviceCreateTimeFormatter().date(from: createTime) else {
            return fallback
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

    nonisolated private static func detail(for file: DeviceMediaIndexItem) -> String {
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
