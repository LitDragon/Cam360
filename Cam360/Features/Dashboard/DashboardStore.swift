import Combine
import Foundation

enum DashboardDeviceStatus: Equatable {
    case connected
    case nearby
    case offline

    var title: String {
        switch self {
        case .connected:
            return "Connected"
        case .nearby:
            return "In Range"
        case .offline:
            return "Offline"
        }
    }

    var subtitle: String {
        switch self {
        case .connected:
            return "Ready to preview"
        case .nearby:
            return "Waiting to connect"
        case .offline:
            return "Last seen recently"
        }
    }
}

struct DashboardDeviceItem: Identifiable, Equatable {
    let id: String
    let name: String
    let status: DashboardDeviceStatus
    let hotspotSSID: String
}

struct DashboardRecentEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

final class DashboardStore: ObservableObject {
    @Published private(set) var devices: [DashboardDeviceItem]
    @Published private(set) var selectedDeviceID: DashboardDeviceItem.ID?
    @Published private(set) var shouldShowFeatureSheet: Bool

    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore

    init(
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore
    ) {
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        devices = []
        selectedDeviceID = nil
        shouldShowFeatureSheet = false
        refresh()
    }

    var hasDevices: Bool {
        devices.isEmpty == false
    }

    var selectedDevice: DashboardDeviceItem? {
        guard let selectedDeviceID = selectedDeviceID else {
            return nil
        }

        return devices.first(where: { $0.id == selectedDeviceID })
    }

    var recentEvents: [DashboardRecentEvent] {
        guard selectedDevice != nil else {
            return []
        }

        return Self.placeholderEvents
    }

    func refresh() {
        let items = knownDeviceRepository.fetchKnownDevices().enumerated().map { index, device in
            DashboardDeviceItem(
                id: device.id,
                name: device.name,
                status: status(for: index),
                hotspotSSID: device.hotspotSSID
            )
        }

        devices = items

        if let selectedDeviceID = selectedDeviceID,
           items.contains(where: { $0.id == selectedDeviceID }) {
            self.selectedDeviceID = selectedDeviceID
        } else {
            selectedDeviceID = items.first?.id
        }

        shouldShowFeatureSheet = appPreferenceStore.hasCompletedOnboarding == false
    }

    func selectDevice(id: DashboardDeviceItem.ID) {
        selectedDeviceID = id
    }

    func addMockDevicesIfNeeded() {
        guard knownDeviceRepository.fetchKnownDevices().isEmpty else {
            refresh()
            return
        }

        knownDeviceRepository.store(Self.placeholderDevices)
        refresh()
    }

    func dismissFeatureSheet() {
        appPreferenceStore.hasCompletedOnboarding = true
        shouldShowFeatureSheet = false
    }

    private func status(for index: Int) -> DashboardDeviceStatus {
        switch index {
        case 0:
            return .connected
        case 1, 3:
            return .nearby
        default:
            return .offline
        }
    }
}

private extension DashboardStore {
    static let placeholderDevices: [KnownDeviceSummary] = [
        KnownDeviceSummary(
            id: "dashboard-device-main",
            name: "Vigilant Lens DL-400",
            hotspotSSID: "Cam360_DL400",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_139_200)
        ),
        KnownDeviceSummary(
            id: "dashboard-device-rear",
            name: "Rear View Pro",
            hotspotSSID: "Cam360_Rear",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_128_400)
        ),
        KnownDeviceSummary(
            id: "dashboard-device-cabin",
            name: "Cabin Cam",
            hotspotSSID: "Cam360_Cabin",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_117_600)
        ),
        KnownDeviceSummary(
            id: "dashboard-device-side",
            name: "Side Cam",
            hotspotSSID: "Cam360_Side",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_106_800)
        )
    ]

    static let placeholderEvents: [DashboardRecentEvent] = [
        DashboardRecentEvent(
            id: "braking-detected",
            title: "Braking Detected",
            detail: "Today, 11:42 AM"
        ),
        DashboardRecentEvent(
            id: "parking-sentry",
            title: "Parking Sentry",
            detail: "Yesterday, 09:15 PM"
        )
    ]
}
