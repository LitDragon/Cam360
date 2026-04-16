import Combine

final class DeviceListStore: ObservableObject {
    @Published private(set) var devices: [KnownDeviceSummary]

    private let knownDeviceRepository: KnownDeviceRepository

    init(knownDeviceRepository: KnownDeviceRepository) {
        self.knownDeviceRepository = knownDeviceRepository
        devices = knownDeviceRepository.fetchKnownDevices()
    }

    func reload() {
        devices = knownDeviceRepository.fetchKnownDevices()
    }
}
