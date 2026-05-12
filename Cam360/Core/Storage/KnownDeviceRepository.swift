import Foundation

struct KnownDeviceSummary: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let hotspotSSID: String
    let lastConnectedAt: Date
}

protocol KnownDeviceRepository {
    func fetchKnownDevices() -> [KnownDeviceSummary]
    func store(_ devices: [KnownDeviceSummary])
    func clear()
}

final class UserDefaultsKnownDeviceRepository: KnownDeviceRepository {
    private enum Key {
        static let knownDevices = "storage.knownDevices"
    }

    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encodeDevices: ([KnownDeviceSummary]) throws -> Data

    init(
        userDefaults: UserDefaults,
        encodeDevices: (([KnownDeviceSummary]) throws -> Data)? = nil
    ) {
        self.userDefaults = userDefaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encodeDevices = encodeDevices ?? { devices in
            try encoder.encode(devices)
        }
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetchKnownDevices() -> [KnownDeviceSummary] {
        guard let data = userDefaults.data(forKey: Key.knownDevices) else {
            return []
        }

        return (try? decoder.decode([KnownDeviceSummary].self, from: data)) ?? []
    }

    func store(_ devices: [KnownDeviceSummary]) {
        do {
            userDefaults.set(try encodeDevices(devices), forKey: Key.knownDevices)
        } catch {
            assertionFailure("Failed to encode known devices: \(error)")
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: Key.knownDevices)
    }
}
