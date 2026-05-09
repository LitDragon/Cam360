import Testing
import Foundation
@testable import Cam360

@MainActor
struct FeatureSmokeTests {
    @Test
    func deviceListStoreStartsWithRepositoryDevices() {
        let testDefaults = makeSmokeUserDefaults()
        defer { clearSmoke(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam-front", name: "Front Camera"),
            makeKnownDevice(id: "cam-rear", name: "Rear Camera")
        ])

        let store = DeviceListStore(knownDeviceRepository: repository)

        #expect(store.devices.count == 2)
        #expect(store.devices.first?.name == "Front Camera")
    }

    @Test
    func deviceListStoreReloadFetchesLatestFromRepository() {
        let testDefaults = makeSmokeUserDefaults()
        defer { clearSmoke(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let store = DeviceListStore(knownDeviceRepository: repository)

        #expect(store.devices.isEmpty)

        repository.store([makeKnownDevice(id: "cam-new", name: "New Camera")])
        store.reload()

        #expect(store.devices.count == 1)
        #expect(store.devices.first?.name == "New Camera")
    }

    @Test
    func playbackStoreStartsWithEmptyState() {
        let store = PlaybackStore()

        #expect(store.title == "没有可播放内容")
        #expect(store.message == "当前没有可显示的设备录像或本地媒体。")
        #expect(store.isLoading == false)
        #expect(store.selectedFileInfo == nil)
        #expect(store.playbackResource == nil)
        #expect(store.lastLoadError == nil)
    }

    @Test
    func galleryStoreStartsWithSampleItems() {
        let store = GalleryStore()

        #expect(store.items.isEmpty == false)
        #expect(store.selectedIDs.isEmpty)
        #expect(store.isSelectionMode == false)
        #expect(store.searchText.isEmpty)
    }

    @Test
    func galleryStoreSearchTextIsMutable() {
        let store = GalleryStore()

        store.searchText = "test-search"

        #expect(store.searchText == "test-search")
    }

    @Test
    func galleryStoreFilterDefaultsToAll() {
        let store = GalleryStore()

        #expect(store.selectedFilter == .all)
    }
}

private struct SmokeTestDefaults {
    let suiteName: String
    let userDefaults: UserDefaults
}

@MainActor
private func makeSmokeUserDefaults() -> SmokeTestDefaults {
    let suiteName = "FeatureSmokeTests.\(UUID().uuidString)"
    return SmokeTestDefaults(
        suiteName: suiteName,
        userDefaults: UserDefaults(suiteName: suiteName)!
    )
}

@MainActor
private func clearSmoke(_ testDefaults: SmokeTestDefaults) {
    testDefaults.userDefaults.removePersistentDomain(forName: testDefaults.suiteName)
}
