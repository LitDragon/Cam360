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

struct DashboardPreviewState: Equatable {
    let statusTitle: String
    let resolutionTitle: String
    let timestampText: String
}

struct DashboardFeatureDeviceState: Equatable {
    let pairedDeviceName: String
    let connectionStatusText: String
}

struct DashboardDeviceScenario: Equatable {
    let startsRecording: Bool
    let previewState: DashboardPreviewState
    let storageState: DashboardStorageState
    let events: [DashboardRecentEvent]
}

protocol DashboardContentProviding {
    var placeholderDevices: [KnownDeviceSummary] { get }
    var placeholderFeatureDeviceState: DashboardFeatureDeviceState { get }

    func status(for device: KnownDeviceSummary, at index: Int) -> DashboardDeviceStatus
    func scenario(forDeviceAt index: Int) -> DashboardDeviceScenario
    func connectionStatusText(for device: DashboardDeviceItem) -> String
}

final class DashboardStore: ObservableObject {
    @Published private(set) var devices: [DashboardDeviceItem]
    @Published private(set) var selectedDeviceID: DashboardDeviceItem.ID?
    @Published private(set) var shouldShowFeatureSheet: Bool
    @Published private(set) var recordingStatesByDeviceID: [DashboardDeviceItem.ID: Bool]

    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore
    private let contentProvider: DashboardContentProviding
    private let deviceSession: DeviceSession?
    private var deviceSessionState: DeviceSessionState = .idle
    private var lastSessionDeviceID: KnownDeviceSummary.ID?
    private var cancellables = Set<AnyCancellable>()

    init(
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore,
        contentProvider: DashboardContentProviding = PlaceholderDashboardContentProvider(),
        deviceSession: DeviceSession? = nil
    ) {
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        self.contentProvider = contentProvider
        self.deviceSession = deviceSession
        devices = []
        selectedDeviceID = nil
        shouldShowFeatureSheet = false
        recordingStatesByDeviceID = [:]
        deviceSessionState = deviceSession?.state ?? .idle
        updateLastSessionDeviceID(from: deviceSessionState)
        bindDeviceSession()
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

    var previewState: DashboardPreviewState {
        selectedScenario?.previewState ?? contentProvider.scenario(forDeviceAt: 0).previewState
    }

    var storageState: DashboardStorageState {
        selectedScenario?.storageState ?? contentProvider.scenario(forDeviceAt: 0).storageState
    }

    var featureSheetDeviceState: DashboardFeatureDeviceState {
        guard let selectedDevice = selectedDevice else {
            return contentProvider.placeholderFeatureDeviceState
        }

        return DashboardFeatureDeviceState(
            pairedDeviceName: selectedDevice.name,
            connectionStatusText: contentProvider.connectionStatusText(for: selectedDevice)
        )
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
                status: status(for: device, at: index),
                hotspotSSID: device.hotspotSSID
            )
        }

        devices = items
        recordingStatesByDeviceID = items.enumerated().reduce(into: [:]) { partialResult, item in
            let defaultValue = contentProvider.scenario(forDeviceAt: item.offset).startsRecording
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

    func addPlaceholderDevicesIfNeeded() {
        guard knownDeviceRepository.fetchKnownDevices().isEmpty else {
            refresh()
            return
        }

        knownDeviceRepository.store(contentProvider.placeholderDevices)
        refresh()
    }

    func dismissFeatureSheet() {
        appPreferenceStore.hasCompletedOnboarding = true
        shouldShowFeatureSheet = false
    }

    private var selectedScenario: DashboardDeviceScenario? {
        guard let selectedDeviceID = selectedDeviceID,
              let selectedIndex = devices.firstIndex(where: { $0.id == selectedDeviceID }) else {
            return nil
        }

        return contentProvider.scenario(forDeviceAt: selectedIndex)
    }

    private func bindDeviceSession() {
        deviceSession?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.deviceSessionState = state
                self?.updateLastSessionDeviceID(from: state)
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    private func updateLastSessionDeviceID(from state: DeviceSessionState) {
        switch state {
        case .ready(let deviceInfo), .busy(operation: _, deviceInfo: let deviceInfo):
            lastSessionDeviceID = deviceInfo.id
        default:
            break
        }
    }

    private func status(for device: KnownDeviceSummary, at index: Int) -> DashboardDeviceStatus {
        switch deviceSessionState {
        case .ready(let deviceInfo), .busy(operation: _, deviceInfo: let deviceInfo):
            if device.id == deviceInfo.id {
                return .connected
            }
        case .failed, .disconnected:
            if device.id == lastSessionDeviceID {
                return .offline
            }
        default:
            break
        }

        return contentProvider.status(for: device, at: index)
    }
}

struct PlaceholderDashboardContentProvider: DashboardContentProviding {
    var placeholderDevices: [KnownDeviceSummary] {
        Self.placeholderDevices
    }

    var placeholderFeatureDeviceState: DashboardFeatureDeviceState {
        DashboardFeatureDeviceState(
            pairedDeviceName: Self.placeholderDevices.first?.name ?? "Placeholder Dashcam",
            connectionStatusText: Self.placeholderConnectionStatusText
        )
    }

    func status(for device: KnownDeviceSummary, at index: Int) -> DashboardDeviceStatus {
        switch index {
        case 0:
            return .connected
        case 1, 3:
            return .nearby
        default:
            return .offline
        }
    }

    func scenario(forDeviceAt index: Int) -> DashboardDeviceScenario {
        let normalizedIndex = index % Self.placeholderScenarios.count
        return Self.placeholderScenarios[normalizedIndex]
    }

    func connectionStatusText(for device: DashboardDeviceItem) -> String {
        Self.placeholderConnectionStatusText
    }
}

private extension PlaceholderDashboardContentProvider {
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

    static let placeholderPreviewState = DashboardPreviewState(
        statusTitle: "LIVE",
        resolutionTitle: "4K",
        timestampText: "2023-10-27 14:32:15"
    )

    static let placeholderConnectionStatusText = "Signal Strength: Optimal"

    static let placeholderScenarios: [DashboardDeviceScenario] = [
        DashboardDeviceScenario(
            startsRecording: false,
            previewState: placeholderPreviewState,
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
            previewState: placeholderPreviewState,
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
            previewState: placeholderPreviewState,
            storageState: .available(defaultStorageSummary),
            events: []
        ),
        DashboardDeviceScenario(
            startsRecording: true,
            previewState: placeholderPreviewState,
            storageState: .unavailable(
                title: "No SD card detected",
                message: "Insert an SD card to store clips, or switch to cloud storage to browse history."
            ),
            events: []
        )
    ]
}
