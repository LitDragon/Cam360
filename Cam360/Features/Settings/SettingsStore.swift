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
    @Published private(set) var networkIdentity = NetworkIdentityState.defaultValue(networkName: "Vigilant_Dash_4K")
    @Published private(set) var devicePreferences = DevicePreferencesState.defaultValue(
        deviceName: "DriveCam X Pro",
        connectionName: "Vigilant_Dash_4K"
    )
    @Published private(set) var safetySettings = SafetySettingsState.defaultValue
    @Published private(set) var firmwareUpdateStage: FirmwareUpdateStage = .available
    @Published private(set) var renameDeviceDraft = "DriveCam X Pro"

    private let router: AppRouter
    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore

    init(
        router: AppRouter,
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore
    ) {
        self.router = router
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        seedDeviceState(from: knownDeviceRepository.fetchKnownDevices().first)
        refresh()
    }

    func refresh() {
        knownDeviceCount = knownDeviceRepository.fetchKnownDevices().count
        hasCompletedOnboarding = appPreferenceStore.hasCompletedOnboarding
        shareAnonymousLogs = appPreferenceStore.shareAnonymousLogs
        notificationPreferences = appPreferenceStore.notificationPreferences
    }

    func resetShell() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        seedDeviceState(from: nil)
        route = nil
        refresh()
        router.showMain(tab: .dashboard)
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

    func renameDevice() {
        let trimmedName = renameDeviceDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            return
        }

        devicePreferences.deviceName = trimmedName
        renameDeviceDraft = trimmedName
        route = nil
    }

    func startFirmwareUpdate() {
        firmwareUpdateStage = .downloading(
            progress: 0.45,
            downloadedSize: "1.3 MB",
            remainingTime: "2 mins left"
        )
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

    private func seedDeviceState(from device: KnownDeviceSummary?) {
        let deviceName = device?.name ?? "DriveCam X Pro"
        let connectionName = device?.hotspotSSID ?? "Vigilant_Dash_4K"
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
}
