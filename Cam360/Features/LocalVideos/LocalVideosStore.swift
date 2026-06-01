import Combine
import Foundation

struct LocalVideoItem: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let fileSizeBytes: Int
    let durationSeconds: Int
    let localPath: String
}

struct LocalScreenshotItem: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let fileSizeBytes: Int
    let localPath: String
}

protocol LocalVideoCatalog {
    func loadItems() -> [LocalVideoItem]
    func loadScreenshots() -> [LocalScreenshotItem]
    func store(_ item: LocalVideoItem)
    func storeScreenshot(_ item: LocalScreenshotItem)
    func deleteItem(id: String)
    func deleteScreenshot(id: String)
    func clear()
}

struct StaticLocalVideoCatalog: LocalVideoCatalog {
    let items: [LocalVideoItem]
    var screenshots: [LocalScreenshotItem] = []

    func loadItems() -> [LocalVideoItem] {
        items
    }

    func loadScreenshots() -> [LocalScreenshotItem] {
        screenshots
    }

    func store(_ item: LocalVideoItem) {}

    func storeScreenshot(_ item: LocalScreenshotItem) {}

    func deleteItem(id: String) {}

    func deleteScreenshot(id: String) {}

    func clear() {}
}

final class UserDefaultsLocalVideoCatalog: LocalVideoCatalog {
    private enum Key {
        static let localVideos = "storage.localVideos"
        static let localScreenshots = "storage.localScreenshots"
    }

    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encodeItems: ([LocalVideoItem]) throws -> Data
    private let encodeScreenshots: ([LocalScreenshotItem]) throws -> Data

    init(
        userDefaults: UserDefaults,
        encodeItems: (([LocalVideoItem]) throws -> Data)? = nil,
        encodeScreenshots: (([LocalScreenshotItem]) throws -> Data)? = nil
    ) {
        self.userDefaults = userDefaults
        let encoder = JSONEncoder()
        self.encodeItems = encodeItems ?? { items in
            try encoder.encode(items)
        }
        self.encodeScreenshots = encodeScreenshots ?? { items in
            try encoder.encode(items)
        }
    }

    func loadItems() -> [LocalVideoItem] {
        guard let data = userDefaults.data(forKey: Key.localVideos) else {
            return []
        }

        return (try? decoder.decode([LocalVideoItem].self, from: data)) ?? []
    }

    func loadScreenshots() -> [LocalScreenshotItem] {
        guard let data = userDefaults.data(forKey: Key.localScreenshots) else {
            return []
        }

        return (try? decoder.decode([LocalScreenshotItem].self, from: data)) ?? []
    }

    func store(_ item: LocalVideoItem) {
        var items = loadItems()
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        save(items)
    }

    func storeScreenshot(_ item: LocalScreenshotItem) {
        var items = loadScreenshots()
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        saveScreenshots(items)
    }

    func deleteItem(id: String) {
        var items = loadItems()
        items.removeAll { $0.id == id }
        save(items)
    }

    func deleteScreenshot(id: String) {
        var items = loadScreenshots()
        items.removeAll { $0.id == id }
        saveScreenshots(items)
    }

    func clear() {
        userDefaults.removeObject(forKey: Key.localVideos)
        userDefaults.removeObject(forKey: Key.localScreenshots)
    }

    private func save(_ items: [LocalVideoItem]) {
        do {
            userDefaults.set(try encodeItems(items), forKey: Key.localVideos)
        } catch {
            return
        }
    }

    private func saveScreenshots(_ items: [LocalScreenshotItem]) {
        do {
            userDefaults.set(try encodeScreenshots(items), forKey: Key.localScreenshots)
        } catch {
            return
        }
    }
}

final class LocalVideosStore: ObservableObject {
    @Published private(set) var items: [LocalVideoItem] = []
    @Published private(set) var screenshots: [LocalScreenshotItem] = []
    @Published private(set) var pendingDeletion: LocalVideoItem?
    @Published private(set) var pendingScreenshotDeletion: LocalScreenshotItem?
    @Published private(set) var pendingShare: LocalVideoItem?

    private let catalog: LocalVideoCatalog

    init(catalog: LocalVideoCatalog = StaticLocalVideoCatalog(items: [])) {
        self.catalog = catalog
    }

    var title: String {
        if items.isEmpty && screenshots.isEmpty {
            return "暂无本地资源"
        }
        return items.isEmpty || screenshots.isEmpty == false ? "本地资源" : "本地视频"
    }

    var message: String {
        if items.isEmpty && screenshots.isEmpty {
            return "本地保存路径接入前，不展示伪造的视频或截图记录。"
        }
        return items.isEmpty || screenshots.isEmpty == false
            ? "本地视频和截图来自已确认的 App 保存记录。"
            : "本地视频来自已确认的 App 保存记录。"
    }

    var usedStorageBytes: Int {
        items.reduce(0) { $0 + $1.fileSizeBytes } + screenshots.reduce(0) { $0 + $1.fileSizeBytes }
    }

    var usedStorageText: String {
        guard usedStorageBytes > 0 else {
            return "0 MB"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(usedStorageBytes))
    }

    var canOpenItem: Bool {
        items.isEmpty == false
    }

    var canShareItem: Bool {
        items.isEmpty == false
    }

    var pendingShareURL: URL? {
        guard let pendingShare else {
            return nil
        }

        return URL(fileURLWithPath: pendingShare.localPath)
    }

    var canDeleteItem: Bool {
        items.isEmpty == false
    }

    var canDeleteScreenshot: Bool {
        screenshots.isEmpty == false
    }

    var deleteConfirmationTitle: String {
        "删除本地视频？"
    }

    var deleteConfirmationMessage: String {
        guard let pendingDeletion else {
            return "请选择要删除的本地视频。"
        }

        return "将从 App 本地视频索引移除 \(pendingDeletion.title)。"
    }

    var deleteScreenshotConfirmationTitle: String {
        "删除本地截图？"
    }

    var deleteScreenshotConfirmationMessage: String {
        guard let pendingScreenshotDeletion else {
            return "请选择要删除的本地截图。"
        }

        return "将从 App 本地截图索引移除 \(pendingScreenshotDeletion.title)。"
    }

    func reload() {
        items = catalog.loadItems()
        screenshots = catalog.loadScreenshots()
    }

    func requestDelete(itemID: String) {
        pendingDeletion = items.first { $0.id == itemID }
    }

    func requestShare(itemID: String) {
        pendingShare = items.first { $0.id == itemID }
    }

    func requestDeleteScreenshot(itemID: String) {
        pendingScreenshotDeletion = screenshots.first { $0.id == itemID }
    }

    func cancelPendingShare() {
        pendingShare = nil
    }

    func cancelPendingDeletion() {
        pendingDeletion = nil
    }

    func cancelPendingScreenshotDeletion() {
        pendingScreenshotDeletion = nil
    }

    func confirmPendingDeletion() {
        guard let pendingDeletion else {
            return
        }

        catalog.deleteItem(id: pendingDeletion.id)
        self.pendingDeletion = nil
        reload()
    }

    func confirmPendingScreenshotDeletion() {
        guard let pendingScreenshotDeletion else {
            return
        }

        catalog.deleteScreenshot(id: pendingScreenshotDeletion.id)
        self.pendingScreenshotDeletion = nil
        reload()
    }
}
