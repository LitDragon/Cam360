import Testing
import Foundation
@testable import Cam360

struct DeviceListStoreTests {
    @Test
    func initLoadsDevicesFromRepository() {
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)
        repository.store([.demo])

        let store = DeviceListStore(knownDeviceRepository: repository)

        #expect(store.devices == [.demo])
    }

    @Test
    func reloadRefreshesDeviceList() {
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)
        repository.store([.demo])

        let store = DeviceListStore(knownDeviceRepository: repository)

        repository.store([.demo, .demo])

        store.reload()

        #expect(store.devices.count == 1)
    }

    @Test
    func emptyRepositoryShowsNoDevices() {
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)

        let store = DeviceListStore(knownDeviceRepository: repository)

        #expect(store.devices.isEmpty)
    }
}
