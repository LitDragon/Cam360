import Combine
import Foundation

enum RecordingDeviceStatus: Equatable {
    case connected
    case connecting
    case disconnected

    var title: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        }
    }

    var subtitle: String {
        switch self {
        case .connected:
            return "Ready to preview"
        case .connecting:
            return "Connecting to device"
        case .disconnected:
            return "Not connected"
        }
    }
}

struct RecordingDeviceItem: Identifiable, Equatable {
    let id: String
    let name: String
    let status: RecordingDeviceStatus
    let hotspotSSID: String
}

struct RecordingStorageSummary: Equatable {
    let usedCapacityText: String
    let totalCapacityText: String
    let usageFraction: Double

    var usageText: String {
        "\(Int((usageFraction * 100).rounded()))% USED"
    }
}

enum RecordingStorageState: Equatable {
    case available(RecordingStorageSummary)
    case unavailable(title: String, message: String)
}

enum RecordingEventArtwork: Equatable {
    case vehicle
    case landscape
    case nightDrive
    case parking
}

struct RecordingRecentEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let badgeTitle: String
    let badgeTone: StatusTagTone
    let artwork: RecordingEventArtwork
}

struct RecordingPreviewState: Equatable {
    let statusTitle: String
    let resolutionTitle: String
    let timestampText: String
}

struct RecordingFeatureDeviceState: Equatable {
    let pairedDeviceName: String
    let connectionStatusText: String
}

struct RecordingDeviceScenario: Equatable {
    let startsRecording: Bool
    let previewState: RecordingPreviewState
    let storageState: RecordingStorageState
    let events: [RecordingRecentEvent]
}

protocol RecordingContentProviding {
    var placeholderDevices: [KnownDeviceSummary] { get }
    var placeholderFeatureDeviceState: RecordingFeatureDeviceState { get }

    func scenario(forDeviceAt index: Int) -> RecordingDeviceScenario
    func connectionStatusText(for device: RecordingDeviceItem) -> String
}

final class RecordingStore: ObservableObject {
    @Published private(set) var devices: [RecordingDeviceItem]
    @Published private(set) var selectedDeviceID: RecordingDeviceItem.ID?
    @Published private(set) var shouldShowFeatureSheet: Bool
    @Published private(set) var recordingStatesByDeviceID: [RecordingDeviceItem.ID: Bool]
    @Published private(set) var deviceRecentEvents: [RecordingRecentEvent]

    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore
    private let contentProvider: RecordingContentProviding
    private let deviceSession: DeviceSession?
    private var deviceSessionState: DeviceSessionState = .idle
    private var lastSessionDeviceID: KnownDeviceSummary.ID?
    private var recentEventsGeneration = 0
    private var cancellables = Set<AnyCancellable>()

    init(
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore,
        contentProvider: RecordingContentProviding = PlaceholderRecordingContentProvider(),
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
        deviceRecentEvents = []
        deviceSessionState = deviceSession?.state ?? .idle
        updateLastSessionDeviceID(from: deviceSessionState)
        bindDeviceSession()
        refresh()
    }

    var hasDevices: Bool {
        devices.isEmpty == false
    }

    var selectedDevice: RecordingDeviceItem? {
        guard let selectedDeviceID = selectedDeviceID else {
            return nil
        }

        return devices.first(where: { $0.id == selectedDeviceID })
    }

    var recentEvents: [RecordingRecentEvent] {
        deviceRecentEvents.isEmpty ? (selectedScenario?.events ?? []) : deviceRecentEvents
    }

    var previewState: RecordingPreviewState {
        selectedScenario?.previewState ?? contentProvider.scenario(forDeviceAt: 0).previewState
    }

    var storageState: RecordingStorageState {
        selectedScenario?.storageState ?? contentProvider.scenario(forDeviceAt: 0).storageState
    }

    var featureSheetDeviceState: RecordingFeatureDeviceState {
        guard let selectedDevice = selectedDevice else {
            return contentProvider.placeholderFeatureDeviceState
        }

        return RecordingFeatureDeviceState(
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
        let knownDevices = knownDeviceRepository.fetchKnownDevices()
        let nextSelectedDeviceID = selectedDeviceID(in: knownDevices)
        let items = knownDevices.enumerated().map { index, device in
            RecordingDeviceItem(
                id: device.id,
                name: device.name,
                status: status(for: device, selectedDeviceID: nextSelectedDeviceID),
                hotspotSSID: device.hotspotSSID
            )
        }

        devices = items
        recordingStatesByDeviceID = items.enumerated().reduce(into: [:]) { partialResult, item in
            let defaultValue = contentProvider.scenario(forDeviceAt: item.offset).startsRecording
            partialResult[item.element.id] = currentRecordingStates[item.element.id] ?? defaultValue
        }

        selectedDeviceID = nextSelectedDeviceID

        shouldShowFeatureSheet = appPreferenceStore.hasCompletedOnboarding == false
    }

    func selectDevice(id: RecordingDeviceItem.ID) {
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

    private var selectedScenario: RecordingDeviceScenario? {
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
                self?.loadRecentEventsIfNeeded(from: state)
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

    private func selectedDeviceID(in devices: [KnownDeviceSummary]) -> KnownDeviceSummary.ID? {
        if let selectedDeviceID = selectedDeviceID,
           devices.contains(where: { $0.id == selectedDeviceID }) {
            return selectedDeviceID
        }

        return devices.first?.id
    }

    private func loadRecentEventsIfNeeded(from state: DeviceSessionState) {
        guard case .ready = state, let deviceSession else {
            if state.canSendDeviceCommand == false {
                recentEventsGeneration += 1
                deviceRecentEvents = []
            }
            return
        }

        let generation = nextRecentEventsGeneration()
        deviceSession.fetchRecentEvents(query: DeviceRecentEventsQuery(limit: 4)) { [weak self] result in
            guard let self, self.recentEventsGeneration == generation else {
                return
            }
            if case .success(let page) = result {
                self.deviceRecentEvents = page.items.map(Self.recordingEvent(from:))
            }
        }
    }

    private func nextRecentEventsGeneration() -> Int {
        recentEventsGeneration += 1
        return recentEventsGeneration
    }

    private func status(
        for device: KnownDeviceSummary,
        selectedDeviceID: KnownDeviceSummary.ID?
    ) -> RecordingDeviceStatus {
        switch deviceSessionState {
        case .ready(let deviceInfo), .busy(operation: _, deviceInfo: let deviceInfo):
            if device.id == deviceInfo.id {
                return .connected
            }
        case .apConnecting, .handshaking, .recovering:
            let connectingDeviceID = lastSessionDeviceID ?? selectedDeviceID
            if device.id == connectingDeviceID {
                return .connecting
            }
        default:
            break
        }

        return .disconnected
    }

    nonisolated private static func recordingEvent(from item: DeviceRecentEventItem) -> RecordingRecentEvent {
        RecordingRecentEvent(
            id: item.id,
            title: item.title,
            detail: item.createTime ?? "Recent event",
            badgeTitle: badgeTitle(for: item.eventType),
            badgeTone: item.eventType == "impact" || item.eventType == "emergency" ? .danger : .accent,
            artwork: artwork(for: item.eventType)
        )
    }

    nonisolated private static func badgeTitle(for eventType: String) -> String {
        switch eventType {
        case "impact":
            return "IMPACT"
        case "motion":
            return "MOTION"
        case "manual":
            return "MANUAL"
        case "parking":
            return "PARKING"
        default:
            return "EVENT"
        }
    }

    nonisolated private static func artwork(for eventType: String) -> RecordingEventArtwork {
        switch eventType {
        case "parking":
            return .parking
        case "motion":
            return .nightDrive
        case "manual":
            return .landscape
        default:
            return .vehicle
        }
    }
}

struct PlaceholderRecordingContentProvider: RecordingContentProviding {
    var placeholderDevices: [KnownDeviceSummary] {
        Self.placeholderDevices
    }

    var placeholderFeatureDeviceState: RecordingFeatureDeviceState {
        RecordingFeatureDeviceState(
            pairedDeviceName: Self.placeholderDevices.first?.name ?? "Placeholder Dashcam",
            connectionStatusText: Self.placeholderConnectionStatusText
        )
    }

    func scenario(forDeviceAt index: Int) -> RecordingDeviceScenario {
        let normalizedIndex = index % Self.placeholderScenarios.count
        return Self.placeholderScenarios[normalizedIndex]
    }

    func connectionStatusText(for device: RecordingDeviceItem) -> String {
        Self.placeholderConnectionStatusText
    }
}

private extension PlaceholderRecordingContentProvider {
    static let placeholderDevices: [KnownDeviceSummary] = [
        KnownDeviceSummary(
            id: "recording-device-main",
            name: "Vigilant Lens DL-400",
            hotspotSSID: "Cam360_DL400",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_139_200)
        ),
        KnownDeviceSummary(
            id: "recording-device-rear",
            name: "Rear View Pro",
            hotspotSSID: "Cam360_Rear",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_128_400)
        ),
        KnownDeviceSummary(
            id: "recording-device-cabin",
            name: "Cabin Cam",
            hotspotSSID: "Cam360_Cabin",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_117_600)
        ),
        KnownDeviceSummary(
            id: "recording-device-side",
            name: "Side Cam",
            hotspotSSID: "Cam360_Side",
            lastConnectedAt: Date(timeIntervalSince1970: 1_713_106_800)
        )
    ]

    static let defaultStorageSummary = RecordingStorageSummary(
        usedCapacityText: "74.2 GB",
        totalCapacityText: "128 GB",
        usageFraction: 0.58
    )

    static let placeholderPreviewState = RecordingPreviewState(
        statusTitle: "LIVE",
        resolutionTitle: "4K",
        timestampText: "2023-10-27 14:32:15"
    )

    static let placeholderConnectionStatusText = "Signal Strength: Optimal"

    static let placeholderScenarios: [RecordingDeviceScenario] = [
        RecordingDeviceScenario(
            startsRecording: false,
            previewState: placeholderPreviewState,
            storageState: .available(defaultStorageSummary),
            events: [
                RecordingRecentEvent(
                    id: "collision-detected",
                    title: "Collision Detected",
                    detail: "Today, 10:42 AM",
                    badgeTitle: "IMPACT",
                    badgeTone: .danger,
                    artwork: .vehicle
                ),
                RecordingRecentEvent(
                    id: "motion-detected",
                    title: "Motion Detected",
                    detail: "Today, 9:15 AM",
                    badgeTitle: "MOTION",
                    badgeTone: .neutral,
                    artwork: .landscape
                ),
                RecordingRecentEvent(
                    id: "manual-save",
                    title: "Manual Save",
                    detail: "Yesterday, 8:15 PM",
                    badgeTitle: "MANUAL",
                    badgeTone: .neutral,
                    artwork: .nightDrive
                ),
                RecordingRecentEvent(
                    id: "parking-incident",
                    title: "Parking Incident",
                    detail: "Mon, 2:30 PM",
                    badgeTitle: "IMPACT",
                    badgeTone: .danger,
                    artwork: .parking
                )
            ]
        ),
        RecordingDeviceScenario(
            startsRecording: true,
            previewState: placeholderPreviewState,
            storageState: .available(defaultStorageSummary),
            events: [
                RecordingRecentEvent(
                    id: "collision-detected-secondary",
                    title: "Collision Detected",
                    detail: "Today, 10:42 AM",
                    badgeTitle: "IMPACT",
                    badgeTone: .danger,
                    artwork: .vehicle
                ),
                RecordingRecentEvent(
                    id: "motion-detected-secondary",
                    title: "Motion Detected",
                    detail: "Today, 9:15 AM",
                    badgeTitle: "MOTION",
                    badgeTone: .neutral,
                    artwork: .nightDrive
                ),
                RecordingRecentEvent(
                    id: "manual-save-secondary",
                    title: "Manual Save",
                    detail: "Yesterday, 8:15 PM",
                    badgeTitle: "MANUAL",
                    badgeTone: .neutral,
                    artwork: .landscape
                )
            ]
        ),
        RecordingDeviceScenario(
            startsRecording: true,
            previewState: placeholderPreviewState,
            storageState: .available(defaultStorageSummary),
            events: []
        ),
        RecordingDeviceScenario(
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
