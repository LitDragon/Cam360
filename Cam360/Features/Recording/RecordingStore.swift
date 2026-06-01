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
    @Published private var deviceSessionStatus = DeviceSessionStatus()

    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore
    private let contentProvider: RecordingContentProviding
    private let deviceSession: DeviceSession?
    private var deviceSessionState: DeviceSessionState = .idle
    private var lastSessionDeviceID: KnownDeviceSummary.ID?
    private var recentEventsGeneration = 0
    private var sessionPreviewState: RecordingPreviewState?
    private var sessionStorageSummary: RecordingStorageSummary?
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
        if isSelectedSessionDevice, let sessionPreviewState {
            return sessionPreviewState
        }

        return selectedScenario?.previewState ?? contentProvider.scenario(forDeviceAt: 0).previewState
    }

    var storageState: RecordingStorageState {
        if isSelectedSessionDevice {
            if let sessionStorageState = storageState(for: deviceSessionStatus.sdCardOnline) {
                return sessionStorageState
            }

            if let sessionStorageSummary {
                return .available(sessionStorageSummary)
            }

            if let storageCapacity = deviceSessionStatus.storageCapacity {
                return .available(storageSummary(for: storageCapacity))
            }
        }

        return selectedScenario?.storageState ?? contentProvider.scenario(forDeviceAt: 0).storageState
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

    func applyInitialStateSyncSnapshot(_ snapshot: DeviceStateSyncSnapshot) {
        if let state = deviceSession?.state {
            deviceSessionState = state
            updateLastSessionDeviceID(from: state)
        }

        applyHomeSnapshot(snapshot)

        if let events = Self.recordingEvents(fromHomeSnapshot: snapshot) {
            deviceRecentEvents = events
        }
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

        deviceSession?.$deviceStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.applyDeviceSessionStatus(status)
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

    private func applyDeviceSessionStatus(_ status: DeviceSessionStatus) {
        deviceSessionStatus = status

        guard let activeDeviceID = activeSessionDeviceID,
              let recordingState = status.recordingState else {
            return
        }

        var nextStates = recordingStatesByDeviceID
        nextStates[activeDeviceID] = recordingState.isRecording
        recordingStatesByDeviceID = nextStates
    }

    private var activeSessionDeviceID: KnownDeviceSummary.ID? {
        switch deviceSessionState {
        case .ready(let deviceInfo), .busy(operation: _, deviceInfo: let deviceInfo):
            return deviceInfo.id
        default:
            return nil
        }
    }

    private var isSelectedSessionDevice: Bool {
        guard let selectedDeviceID, let activeSessionDeviceID else {
            return false
        }

        return selectedDeviceID == activeSessionDeviceID
    }

    private func storageState(for sdCardOnline: Int?) -> RecordingStorageState? {
        guard let sdCardOnline else {
            return nil
        }

        switch sdCardOnline {
        case 1:
            return nil
        case 0:
            return .unavailable(
                title: "No SD card detected",
                message: "Insert an SD card to store clips, or switch to cloud storage to browse history."
            )
        case 2:
            return .unavailable(
                title: "SD card requires formatting",
                message: "The device reports the TF card must be formatted before recording."
            )
        default:
            return .unavailable(
                title: "SD card status unavailable",
                message: "The device reported an unknown TF card state. Check the card before recording."
            )
        }
    }

    private func storageSummary(for capacity: DeviceStorageCapacity) -> RecordingStorageSummary {
        let usedMegabytes = max(0, capacity.totalMegabytes - capacity.remainingMegabytes)
        let usageFraction = capacity.totalMegabytes > 0
            ? min(1, Double(usedMegabytes) / Double(capacity.totalMegabytes))
            : 0

        return RecordingStorageSummary(
            usedCapacityText: Self.storageText(megabytes: usedMegabytes),
            totalCapacityText: Self.storageText(megabytes: capacity.totalMegabytes),
            usageFraction: usageFraction
        )
    }

    nonisolated private static func storageText(megabytes: Int) -> String {
        guard megabytes >= 1024 else {
            return "\(megabytes) MB"
        }

        let gigabytes = Double(megabytes) / 1024
        let roundedGigabytes = (gigabytes * 10).rounded() / 10
        if roundedGigabytes == roundedGigabytes.rounded() {
            return "\(Int(roundedGigabytes)) GB"
        }

        return String(format: "%.1f GB", roundedGigabytes)
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
        deviceSession.fetchStateSync(scope: .home) { [weak self] result in
            guard let self, self.recentEventsGeneration == generation else {
                return
            }

            if case .success(let snapshot) = result {
                self.applyHomeSnapshot(snapshot)

                if let events = Self.recordingEvents(fromHomeSnapshot: snapshot) {
                    self.deviceRecentEvents = events
                    return
                }
            }

            self.loadRecentEvents(generation: generation, deviceSession: deviceSession)
        }
    }

    private func applyHomeSnapshot(_ snapshot: DeviceStateSyncSnapshot) {
        guard snapshot.sections.object("home") != nil else {
            return
        }

        sessionPreviewState = Self.previewState(fromHomeSnapshot: snapshot)
        sessionStorageSummary = Self.storageSummary(fromHomeSnapshot: snapshot)
    }

    private func loadRecentEvents(generation: Int, deviceSession: DeviceSession) {
        loadRecentEvents(limit: 4, generation: generation, deviceSession: deviceSession)
    }

    private func loadRecentEvents(limit: Int, generation: Int, deviceSession: DeviceSession) {
        deviceSession.fetchRecentEvents(query: DeviceRecentEventsQuery(limit: limit)) { [weak self] result in
            guard let self, self.recentEventsGeneration == generation else {
                return
            }

            switch result {
            case .success(let page):
                self.deviceRecentEvents = page.items.map(Self.recordingEvent(from:))
            case .failure(let error):
                guard Self.shouldReduceRecentEventsLimit(for: error, limit: limit) else {
                    return
                }

                self.loadRecentEvents(
                    limit: max(1, limit / 2),
                    generation: generation,
                    deviceSession: deviceSession
                )
            }
        }
    }

    private static func shouldReduceRecentEventsLimit(for error: DeviceSessionReadOnlyError, limit: Int) -> Bool {
        guard limit > 1,
              case .protocolFailure(.deviceError(let errno, let topic, _)) = error else {
            return false
        }

        return errno == -7 && topic == "RECENT_EVENTS"
    }

    nonisolated private static func recordingEvents(fromHomeSnapshot snapshot: DeviceStateSyncSnapshot) -> [RecordingRecentEvent]? {
        guard let homeSection = snapshot.sections["home"]?.objectValue,
              let eventValues = homeSection["recent_events"]?.arrayValue,
              let page = try? DeviceAggregateResponseParser.recentEvents(from: [
                  "items": .array(eventValues),
                  "limit": .int(eventValues.count),
                  "total_recent_count": .int(eventValues.count)
              ]) else {
            return nil
        }

        return page.items.map(Self.recordingEvent(from:))
    }

    nonisolated private static func previewState(fromHomeSnapshot snapshot: DeviceStateSyncSnapshot) -> RecordingPreviewState? {
        guard let homeSection = snapshot.sections["home"]?.objectValue,
              let preview = homeSection.object("preview") else {
            return nil
        }

        let statusTitle = preview.bool("recording_status") == true ? "REC" : "READY"
        let resolutionTitle = streamSourceTitle(preview.string("stream_source_type"))
        let timestampText = homeSection.object("device")?.string("date_value").map(formatDeviceTimestamp) ?? "--"
        return RecordingPreviewState(
            statusTitle: statusTitle,
            resolutionTitle: resolutionTitle,
            timestampText: timestampText
        )
    }

    nonisolated private static func storageSummary(fromHomeSnapshot snapshot: DeviceStateSyncSnapshot) -> RecordingStorageSummary? {
        guard let homeSection = snapshot.sections["home"]?.objectValue,
              let summary = homeSection.object("storage_summary"),
              let totalMegabytes = summary.int("total_mb") else {
            return nil
        }

        let remainingMegabytes = summary.int("left_mb") ?? 0
        let usedMegabytes = max(0, totalMegabytes - remainingMegabytes)
        let usageFraction = summary.double("usage_percent").map { min(1, max(0, $0 / 100)) }
            ?? (totalMegabytes > 0 ? min(1, Double(usedMegabytes) / Double(totalMegabytes)) : 0)
        return RecordingStorageSummary(
            usedCapacityText: storageText(megabytes: usedMegabytes),
            totalCapacityText: storageText(megabytes: totalMegabytes),
            usageFraction: usageFraction
        )
    }

    nonisolated private static func streamSourceTitle(_ streamSourceType: String?) -> String {
        switch streamSourceType {
        case "rtsp_pending_protocol":
            return "RTSP pending"
        case .some(let value):
            return value.replacingOccurrences(of: "_", with: " ")
        case .none:
            return "Preview"
        }
    }

    nonisolated private static func formatDeviceTimestamp(_ value: String) -> String {
        guard value.count == 14 else {
            return value
        }

        let yearEnd = value.index(value.startIndex, offsetBy: 4)
        let monthEnd = value.index(yearEnd, offsetBy: 2)
        let dayEnd = value.index(monthEnd, offsetBy: 2)
        let hourEnd = value.index(dayEnd, offsetBy: 2)
        let minuteEnd = value.index(hourEnd, offsetBy: 2)
        return "\(value[..<yearEnd])-\(value[yearEnd..<monthEnd])-\(value[monthEnd..<dayEnd]) \(value[dayEnd..<hourEnd]):\(value[hourEnd..<minuteEnd]):\(value[minuteEnd...])"
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
