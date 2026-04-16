import Foundation

struct KnownDeviceSummary: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let hotspotSSID: String
    let lastConnectedAt: Date

    static let demo = KnownDeviceSummary(
        id: "cam360-demo-device",
        name: "Cam360 Demo",
        hotspotSSID: "Cam360_AP",
        lastConnectedAt: Date(timeIntervalSince1970: 1_713_139_200)
    )
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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetchKnownDevices() -> [KnownDeviceSummary] {
        guard let data = userDefaults.data(forKey: Key.knownDevices) else {
            return []
        }

        return (try? decoder.decode([KnownDeviceSummary].self, from: data)) ?? []
    }

    func store(_ devices: [KnownDeviceSummary]) {
        let data = try? encoder.encode(devices)
        userDefaults.set(data, forKey: Key.knownDevices)
    }

    func clear() {
        userDefaults.removeObject(forKey: Key.knownDevices)
    }
}
