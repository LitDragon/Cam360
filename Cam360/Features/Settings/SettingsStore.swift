import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published private(set) var route: SettingsRoute?
    @Published private(set) var knownDeviceCount = 0
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var shareAnonymousLogs = true
    @Published private(set) var notificationPreferences = NotificationPreferences.defaultValue
    @Published private(set) var recordingSettings = RecordingSettingsState.defaultValue
    @Published private(set) var storagePolicy = StoragePolicyState.defaultValue
    @Published private(set) var watermarkConfiguration = WatermarkConfigurationState.defaultValue
    @Published private(set) var networkIdentity = NetworkIdentityState.defaultValue(
        networkName: SettingsPlaceholder.connectionName
    )
    @Published private(set) var devicePreferences = DevicePreferencesState.defaultValue(
        deviceName: SettingsPlaceholder.deviceName,
        connectionName: SettingsPlaceholder.connectionName
    )
    @Published private(set) var safetySettings = SafetySettingsState.defaultValue
    @Published private(set) var firmwareUpdateStage: FirmwareUpdateStage = .available
    @Published private(set) var renameDeviceDraft = SettingsPlaceholder.deviceName
    @Published private(set) var deviceConnectionStatusTitle = "OFFLINE"
    @Published private(set) var deviceConnectionStatusText = "Not connected"
    @Published private(set) var deviceConnectionStatusTone: StatusTagTone = .neutral
    @Published private(set) var deviceCapabilities: Set<DeviceCapability> = []

    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore
    private let deviceSession: DeviceSession?
    private var seededDeviceID: KnownDeviceSummary.ID?
    private var deviceSessionState: DeviceSessionState = .idle
    private var appliedSessionDeviceInfo: DeviceInfo?
    private var cancellables = Set<AnyCancellable>()

    init(
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore,
        deviceSession: DeviceSession? = nil
    ) {
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        self.deviceSession = deviceSession
        deviceSessionState = deviceSession?.state ?? .idle
        seedDeviceState(from: knownDeviceRepository.fetchKnownDevices().first)
        bindDeviceSession()
        refresh()
    }

    func refresh() {
        let knownDevices = knownDeviceRepository.fetchKnownDevices()
        syncDeviceStateIfNeeded(with: knownDevices.first)
        knownDeviceCount = knownDevices.count
        hasCompletedOnboarding = appPreferenceStore.hasCompletedOnboarding
        shareAnonymousLogs = appPreferenceStore.shareAnonymousLogs
        notificationPreferences = appPreferenceStore.notificationPreferences
        syncDeviceSessionState(deviceSessionState)
    }

    var appVersionText: String {
        AppInfo.shortVersionText
    }

    var networkNamePlaceholderText: String {
        SettingsPlaceholder.connectionName
    }

    func resetShell() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        seedDeviceState(from: nil)
        route = nil
        refresh()
    }

    func show(_ route: SettingsRoute) {
        if route == .renameDevice {
            renameDeviceDraft = devicePreferences.deviceName
        }

        self.route = route
    }

    func dismissRoute() {
        route = nil
    }

    func setShareAnonymousLogs(_ isEnabled: Bool) {
        shareAnonymousLogs = isEnabled
        appPreferenceStore.shareAnonymousLogs = isEnabled
    }

    func setNotificationPreference<Value>(
        _ keyPath: WritableKeyPath<NotificationPreferences, Value>,
        to value: Value
    ) {
        var updatedPreferences = notificationPreferences
        updatedPreferences[keyPath: keyPath] = value
        notificationPreferences = updatedPreferences
        appPreferenceStore.notificationPreferences = updatedPreferences
    }

    func updateRecordingSetting<Value>(
        _ keyPath: WritableKeyPath<RecordingSettingsState, Value>,
        to value: Value
    ) {
        recordingSettings[keyPath: keyPath] = value
    }

    func updateStoragePolicy<Value>(
        _ keyPath: WritableKeyPath<StoragePolicyState, Value>,
        to value: Value
    ) {
        storagePolicy[keyPath: keyPath] = value
    }

    func retryStorageCardCheck() {
        storagePolicy.cardStatus = .ready
    }

    func formatStorageCard() {
        storagePolicy.cardStatus = .ready
        storagePolicy.usedSpaceGB = 18.8
    }

    func updateWatermarkConfiguration<Value>(
        _ keyPath: WritableKeyPath<WatermarkConfigurationState, Value>,
        to value: Value
    ) {
        watermarkConfiguration[keyPath: keyPath] = value
    }

    func saveWatermarkConfiguration() {
        route = nil
    }

    func updateNetworkIdentity<Value>(
        _ keyPath: WritableKeyPath<NetworkIdentityState, Value>,
        to value: Value
    ) {
        networkIdentity[keyPath: keyPath] = value
    }

    func commitNetworkIdentityChanges() {
        devicePreferences.connectionName = networkIdentity.networkName
    }

    func updateDevicePreferences<Value>(
        _ keyPath: WritableKeyPath<DevicePreferencesState, Value>,
        to value: Value
    ) {
        devicePreferences[keyPath: keyPath] = value
    }

    func updateSafetySetting<Value>(
        _ keyPath: WritableKeyPath<SafetySettingsState, Value>,
        to value: Value
    ) {
        safetySettings[keyPath: keyPath] = value
    }

    func restoreSafetyDefaults() {
        safetySettings = .defaultValue
    }

    func setRenameDeviceDraft(_ value: String) {
        renameDeviceDraft = value
    }

    func renameDevice(dismissRoute: Bool = true) {
        let trimmedName = renameDeviceDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            return
        }

        devicePreferences.deviceName = trimmedName
        renameDeviceDraft = trimmedName
        updateKnownDeviceName(trimmedName)

        if dismissRoute {
            route = nil
        }
    }

    func startFirmwareUpdate() {
        firmwareUpdateStage = SettingsPlaceholder.firmwareUpdateStage
    }

    func markFirmwareUpdateFailed() {
        firmwareUpdateStage = .failed
    }

    func cancelFirmwareUpdate() {
        firmwareUpdateStage = .available
    }

    func restoreDefaultDeviceConfiguration() {
        let currentName = devicePreferences.deviceName
        let currentConnectionName = networkIdentity.networkName
        recordingSettings = .defaultValue
        storagePolicy = .defaultValue
        watermarkConfiguration = .defaultValue
        networkIdentity = .defaultValue(networkName: currentConnectionName)
        devicePreferences = .defaultValue(
            deviceName: currentName,
            connectionName: currentConnectionName
        )
        safetySettings = .defaultValue
        firmwareUpdateStage = .available
        renameDeviceDraft = currentName
    }

    private func syncDeviceStateIfNeeded(with device: KnownDeviceSummary?) {
        guard seededDeviceID != device?.id else {
            return
        }

        seedDeviceState(from: device)
    }

    private func updateKnownDeviceName(_ name: String) {
        var devices = knownDeviceRepository.fetchKnownDevices()
        guard devices.isEmpty == false else {
            return
        }

        let targetIndex: Int
        if let seededDeviceID = seededDeviceID,
           let index = devices.firstIndex(where: { $0.id == seededDeviceID }) {
            targetIndex = index
        } else {
            targetIndex = devices.startIndex
            seededDeviceID = devices[targetIndex].id
        }

        let device = devices[targetIndex]
        devices[targetIndex] = KnownDeviceSummary(
            id: device.id,
            name: name,
            hotspotSSID: device.hotspotSSID,
            lastConnectedAt: device.lastConnectedAt
        )
        knownDeviceRepository.store(devices)
    }

    private func seedDeviceState(from device: KnownDeviceSummary?) {
        seededDeviceID = device?.id
        let deviceName = device?.name ?? SettingsPlaceholder.deviceName
        let connectionName = device?.hotspotSSID ?? SettingsPlaceholder.connectionName
        recordingSettings = .defaultValue
        storagePolicy = .defaultValue
        watermarkConfiguration = .defaultValue
        networkIdentity = .defaultValue(networkName: connectionName)
        devicePreferences = .defaultValue(
            deviceName: deviceName,
            connectionName: connectionName
        )
        safetySettings = .defaultValue
        firmwareUpdateStage = .available
        renameDeviceDraft = deviceName
    }

    private func bindDeviceSession() {
        deviceSession?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncDeviceSessionState(state)
            }
            .store(in: &cancellables)
    }

    private func syncDeviceSessionState(_ state: DeviceSessionState) {
        deviceSessionState = state

        switch state {
        case .idle:
            deviceConnectionStatusTitle = "OFFLINE"
            deviceConnectionStatusText = "Not connected"
            deviceConnectionStatusTone = .neutral
            deviceCapabilities = []
        case .apConnecting, .handshaking, .recovering:
            deviceConnectionStatusTitle = "CONNECTING"
            deviceConnectionStatusText = "Connecting to device"
            deviceConnectionStatusTone = .warning
        case .ready(let deviceInfo), .busy(operation: _, deviceInfo: let deviceInfo):
            if appliedSessionDeviceInfo != deviceInfo {
                applyDeviceInfo(deviceInfo)
                appliedSessionDeviceInfo = deviceInfo
            }
            deviceConnectionStatusTitle = "CONNECTED"
            deviceConnectionStatusText = "Connected and ready to record"
            deviceConnectionStatusTone = .success
            deviceCapabilities = deviceInfo.capabilities
        case .failed(let error):
            deviceConnectionStatusTitle = "FAILED"
            deviceConnectionStatusText = error.localizedDescription
            deviceConnectionStatusTone = .danger
            deviceCapabilities = []
        case .disconnected:
            deviceConnectionStatusTitle = "OFFLINE"
            deviceConnectionStatusText = "Disconnected"
            deviceConnectionStatusTone = .neutral
            deviceCapabilities = []
        }
    }

    private func applyDeviceInfo(_ deviceInfo: DeviceInfo) {
        let knownDevice = knownDeviceRepository.fetchKnownDevices().first { $0.id == deviceInfo.id }
        let connectionName = knownDevice?.hotspotSSID ?? devicePreferences.connectionName
        var updatedPreferences = DevicePreferencesState.defaultValue(
            deviceName: deviceInfo.name,
            connectionName: connectionName
        )
        updatedPreferences.firmwareVersion = deviceInfo.firmwareVersion
        devicePreferences = updatedPreferences
        networkIdentity = .defaultValue(networkName: connectionName)
        renameDeviceDraft = deviceInfo.name
        seededDeviceID = knownDevice?.id ?? seededDeviceID
    }
}

private enum SettingsPlaceholder {
    static let deviceName = "DriveCam X Pro"
    static let connectionName = "Vigilant_Dash_4K"
    static let firmwareUpdateStage = FirmwareUpdateStage.downloading(
        progress: 0.45,
        downloadedSize: "1.3 MB",
        remainingTime: "2 mins left"
    )
}
