import Testing
import Foundation
@testable import Cam360

struct DeviceListStoreTests {
    @Test
    func initLoadsDevicesFromRepository() {
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)
        let device = makeKnownDevice()
        repository.store([device])

        let store = DeviceListStore(knownDeviceRepository: repository)

        #expect(store.devices == [device])
    }

    @Test
    func reloadRefreshesDeviceList() {
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)
        let first = makeKnownDevice(id: "cam-1")
        let second = makeKnownDevice(id: "cam-2")
        repository.store([first])

        let store = DeviceListStore(knownDeviceRepository: repository)

        repository.store([first, second])

        store.reload()

        #expect(store.devices == [first, second])
    }

    @Test
    func emptyRepositoryShowsNoDevices() {
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)

        let store = DeviceListStore(knownDeviceRepository: repository)

        #expect(store.devices.isEmpty)
    }
}
