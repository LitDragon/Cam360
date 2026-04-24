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

struct DashboardStorageSummary: Equatable {
    let usedCapacityText: String
    let totalCapacityText: String
    let usageFraction: Double

    var usageText: String {
        "\(Int((usageFraction * 100).rounded()))% USED"
    }
}

enum DashboardStorageState: Equatable {
    case available(DashboardStorageSummary)
    case unavailable(title: String, message: String)
}

enum DashboardEventArtwork: Equatable {
    case vehicle
    case landscape
    case nightDrive
    case parking
}

struct DashboardRecentEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let badgeTitle: String
    let badgeTone: StatusTagTone
    let artwork: DashboardEventArtwork
}

final class DashboardStore: ObservableObject {
    @Published private(set) var devices: [DashboardDeviceItem]
    @Published private(set) var selectedDeviceID: DashboardDeviceItem.ID?
    @Published private(set) var shouldShowFeatureSheet: Bool
    @Published private(set) var recordingStatesByDeviceID: [DashboardDeviceItem.ID: Bool]

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
        recordingStatesByDeviceID = [:]
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
        selectedScenario?.events ?? []
    }

    var storageState: DashboardStorageState {
        selectedScenario?.storageState ?? .available(Self.defaultStorageSummary)
    }

    var isRecording: Bool {
        guard let selectedDeviceID = selectedDeviceID else {
            return false
        }

        return recordingStatesByDeviceID[selectedDeviceID] ?? false
    }

    func refresh() {
        let currentRecordingStates = recordingStatesByDeviceID
        let items = knownDeviceRepository.fetchKnownDevices().enumerated().map { index, device in
            DashboardDeviceItem(
                id: device.id,
                name: device.name,
                status: status(for: index),
                hotspotSSID: device.hotspotSSID
            )
        }

        devices = items
        recordingStatesByDeviceID = items.enumerated().reduce(into: [:]) { partialResult, item in
            let defaultValue = scenario(forIndex: item.offset).startsRecording
            partialResult[item.element.id] = currentRecordingStates[item.element.id] ?? defaultValue
        }

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

    func toggleRecording() {
        guard let selectedDeviceID = selectedDeviceID else {
            return
        }

        recordingStatesByDeviceID[selectedDeviceID] = isRecording == false
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

    private var selectedScenario: DashboardDeviceScenario? {
        guard let selectedDeviceID = selectedDeviceID,
              let selectedIndex = devices.firstIndex(where: { $0.id == selectedDeviceID }) else {
            return nil
        }

        return scenario(forIndex: selectedIndex)
    }
}

private extension DashboardStore {
    struct DashboardDeviceScenario {
        let startsRecording: Bool
        let storageState: DashboardStorageState
        let events: [DashboardRecentEvent]
    }

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

    static let defaultStorageSummary = DashboardStorageSummary(
        usedCapacityText: "74.2 GB",
        totalCapacityText: "128 GB",
        usageFraction: 0.58
    )

    static let placeholderScenarios: [DashboardDeviceScenario] = [
        DashboardDeviceScenario(
            startsRecording: false,
            storageState: .available(defaultStorageSummary),
            events: [
                DashboardRecentEvent(
                    id: "collision-detected",
                    title: "Collision Detected",
                    detail: "Today, 10:42 AM",
                    badgeTitle: "IMPACT",
                    badgeTone: .danger,
                    artwork: .vehicle
                ),
                DashboardRecentEvent(
                    id: "motion-detected",
                    title: "Motion Detected",
                    detail: "Today, 9:15 AM",
                    badgeTitle: "MOTION",
                    badgeTone: .neutral,
                    artwork: .landscape
                ),
                DashboardRecentEvent(
                    id: "manual-save",
                    title: "Manual Save",
                    detail: "Yesterday, 8:15 PM",
                    badgeTitle: "MANUAL",
                    badgeTone: .neutral,
                    artwork: .nightDrive
                ),
                DashboardRecentEvent(
                    id: "parking-incident",
                    title: "Parking Incident",
                    detail: "Mon, 2:30 PM",
                    badgeTitle: "IMPACT",
                    badgeTone: .danger,
                    artwork: .parking
                )
            ]
        ),
        DashboardDeviceScenario(
            startsRecording: true,
            storageState: .available(defaultStorageSummary),
            events: [
                DashboardRecentEvent(
                    id: "collision-detected-secondary",
                    title: "Collision Detected",
                    detail: "Today, 10:42 AM",
                    badgeTitle: "IMPACT",
                    badgeTone: .danger,
                    artwork: .vehicle
                ),
                DashboardRecentEvent(
                    id: "motion-detected-secondary",
                    title: "Motion Detected",
                    detail: "Today, 9:15 AM",
                    badgeTitle: "MOTION",
                    badgeTone: .neutral,
                    artwork: .nightDrive
                ),
                DashboardRecentEvent(
                    id: "manual-save-secondary",
                    title: "Manual Save",
                    detail: "Yesterday, 8:15 PM",
                    badgeTitle: "MANUAL",
                    badgeTone: .neutral,
                    artwork: .landscape
                )
            ]
        ),
        DashboardDeviceScenario(
            startsRecording: true,
            storageState: .available(defaultStorageSummary),
            events: []
        ),
        DashboardDeviceScenario(
            startsRecording: true,
            storageState: .unavailable(
                title: "No SD card detected",
                message: "Insert an SD card to store clips, or switch to cloud storage to browse history."
            ),
            events: []
        )
    ]

    func scenario(forIndex index: Int) -> DashboardDeviceScenario {
        let normalizedIndex = index % Self.placeholderScenarios.count
        return Self.placeholderScenarios[normalizedIndex]
    }
}
