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
        syncDeviceStateIfNeeded(with: preferredDevice(from: knownDevices))
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

    func prepareDeviceSettings(for deviceID: KnownDeviceSummary.ID?) {
        let knownDevices = knownDeviceRepository.fetchKnownDevices()
        let device = selectedDevice(for: deviceID, in: knownDevices)
        syncDeviceStateIfNeeded(with: device)
        knownDeviceCount = knownDevices.count
        syncDeviceSessionState(deviceSessionState)
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
        var nextState = recordingSettings
        nextState[keyPath: keyPath] = value
        submitRecordingSettings(nextState)
    }

    func updateStoragePolicy<Value>(
        _ keyPath: WritableKeyPath<StoragePolicyState, Value>,
        to value: Value
    ) {
        var nextState = storagePolicy
        nextState[keyPath: keyPath] = value
        submitStoragePolicy(nextState)
    }

    func retryStorageCardCheck() {
        storagePolicy.cardStatus = .ready
    }

    func formatStorageCard() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            storagePolicy.cardStatus = .ready
            storagePolicy.usedSpaceGB = 74.2
            return
        }

        deviceSession.formatStorage { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let format) = result, format.formatted {
                self.storagePolicy.cardStatus = .ready
                self.storagePolicy.usedSpaceGB = 0
            }
        }
    }

    private func resetOfflineStorageCard() {
        storagePolicy.cardStatus = .ready
        storagePolicy.usedSpaceGB = 74.2
    }

    func updateWatermarkConfiguration<Value>(
        _ keyPath: WritableKeyPath<WatermarkConfigurationState, Value>,
        to value: Value
    ) {
        watermarkConfiguration[keyPath: keyPath] = value
    }

    func saveWatermarkConfiguration() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            route = nil
            return
        }

        deviceSession.updateWatermarkConfiguration(parameters: Self.watermarkParameters(from: watermarkConfiguration)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.watermarkConfiguration = Self.watermarkState(from: payload) ?? self.watermarkConfiguration
                self.route = nil
            }
        }
    }

    private func dismissWatermarkConfiguration() {
        route = nil
    }

    func updateNetworkIdentity<Value>(
        _ keyPath: WritableKeyPath<NetworkIdentityState, Value>,
        to value: Value
    ) {
        networkIdentity[keyPath: keyPath] = value
    }

    func commitNetworkIdentityChanges() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            devicePreferences.connectionName = networkIdentity.networkName
            return
        }

        deviceSession.updateAccessPointIdentity(ssid: networkIdentity.networkName, password: networkIdentity.password) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let identity) = result {
                self.networkIdentity = NetworkIdentityState(
                    networkName: identity.ssid,
                    password: identity.password ?? self.networkIdentity.password
                )
                self.devicePreferences.connectionName = identity.ssid
            }
        }
    }

    private func commitOfflineNetworkIdentityChanges() {
        devicePreferences.connectionName = networkIdentity.networkName
    }

    func updateDevicePreferences<Value>(
        _ keyPath: WritableKeyPath<DevicePreferencesState, Value>,
        to value: Value
    ) {
        var nextState = devicePreferences
        nextState[keyPath: keyPath] = value
        submitSystemPreferences(nextState)
    }

    func updateSafetySetting<Value>(
        _ keyPath: WritableKeyPath<SafetySettingsState, Value>,
        to value: Value
    ) {
        var nextState = safetySettings
        nextState[keyPath: keyPath] = value
        submitSafetySettings(nextState)
    }

    func restoreSafetyDefaults() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            safetySettings = .defaultValue
            return
        }

        deviceSession.updateSafetyConfiguration(parameters: ["reset_defaults": 1]) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.safetySettings = Self.safetyState(from: payload) ?? .defaultValue
            }
        }
    }

    private func restoreOfflineSafetyDefaults() {
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

    private func preferredDevice(from devices: [KnownDeviceSummary]) -> KnownDeviceSummary? {
        guard let seededDeviceID = seededDeviceID else {
            return devices.first
        }

        return devices.first { $0.id == seededDeviceID } ?? devices.first
    }

    private func selectedDevice(
        for deviceID: KnownDeviceSummary.ID?,
        in devices: [KnownDeviceSummary]
    ) -> KnownDeviceSummary? {
        guard let deviceID = deviceID else {
            return preferredDevice(from: devices)
        }

        return devices.first { $0.id == deviceID } ?? preferredDevice(from: devices)
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
            if seededDeviceID == nil {
                showOfflineStatus(text: "Not connected")
            } else {
                showConnectedStatus()
            }
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
            showConnectedStatus()
            deviceCapabilities = deviceInfo.capabilities
        case .failed(let error):
            deviceConnectionStatusTitle = "FAILED"
            deviceConnectionStatusText = error.localizedDescription
            deviceConnectionStatusTone = .danger
            deviceCapabilities = []
        case .disconnected:
            showOfflineStatus(text: "Disconnected")
            deviceCapabilities = []
        }
    }

    private func showConnectedStatus() {
        deviceConnectionStatusTitle = "CONNECTED"
        deviceConnectionStatusText = "Connected and ready to record"
        deviceConnectionStatusTone = .success
    }

    private func showOfflineStatus(text: String) {
        deviceConnectionStatusTitle = "OFFLINE"
        deviceConnectionStatusText = text
        deviceConnectionStatusTone = .neutral
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

    private var canSubmitSettingsToDevice: Bool {
        deviceSessionState.canSendDeviceCommand && deviceSession != nil
    }

    private func submitRecordingSettings(_ state: RecordingSettingsState) {
        guard canSubmitSettingsToDevice, let deviceSession else {
            recordingSettings = state
            return
        }

        deviceSession.updateRecordingConfiguration(parameters: Self.recordingParameters(from: state)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.recordingSettings = Self.recordingState(from: payload) ?? state
            }
        }
    }

    private func submitStoragePolicy(_ state: StoragePolicyState) {
        guard canSubmitSettingsToDevice, let deviceSession else {
            storagePolicy = state
            return
        }

        deviceSession.updateStoragePolicyConfiguration(parameters: Self.storagePolicyParameters(from: state)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.storagePolicy = Self.storagePolicyState(from: payload) ?? state
            }
        }
    }

    private func submitSafetySettings(_ state: SafetySettingsState) {
        guard canSubmitSettingsToDevice, let deviceSession else {
            safetySettings = state
            return
        }

        deviceSession.updateSafetyConfiguration(parameters: Self.safetyParameters(from: state)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.safetySettings = Self.safetyState(from: payload) ?? state
            }
        }
    }

    private func submitSystemPreferences(_ state: DevicePreferencesState) {
        guard canSubmitSettingsToDevice, let deviceSession else {
            devicePreferences = state
            return
        }

        deviceSession.updateSystemPreferencesConfiguration(parameters: Self.systemPreferenceParameters(from: state)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.devicePreferences = Self.devicePreferencesState(
                    from: payload,
                    fallback: state
                )
            }
        }
    }

    private static func recordingParameters(from state: RecordingSettingsState) -> [String: DeviceProtocolValue] {
        [
            "resolution": .string(state.resolution.rawValue),
            "quality_priority": .string(state.qualityPriority.protocolValue),
            "loop_minutes": .int(state.loopDuration.minutes),
            "auto_overwrite": .int(state.autoOverwrite ? 1 : 0),
            "start_behavior": .string(state.startBehavior.protocolValue),
            "audio_recording": .int(state.audioRecordingEnabled ? 1 : 0),
            "hdr_night_recording": .int(state.hdrNightRecordingEnabled ? 1 : 0),
            "status_indicator": .int(state.recordingStatusIndicatorEnabled ? 1 : 0),
            "recording_reminder": .int(state.recordingReminderEnabled ? 1 : 0)
        ]
    }

    private static func safetyParameters(from state: SafetySettingsState) -> [String: DeviceProtocolValue] {
        [
            "g_sensor_sensitivity": .string(state.gSensorSensitivity.protocolValue),
            "emergency_video_lock": .int(state.emergencyVideoLockEnabled ? 1 : 0),
            "parking_mode": .int(state.parkingModeEnabled ? 1 : 0),
            "motion_detection": .int(state.motionDetectionEnabled ? 1 : 0),
            "impact_detection": .int(state.impactDetectionEnabled ? 1 : 0),
            "clip_duration_sec": .int(state.eventClipDuration.seconds),
            "event_notifications": .int(state.eventNotificationsEnabled ? 1 : 0)
        ]
    }

    private static func storagePolicyParameters(from state: StoragePolicyState) -> [String: DeviceProtocolValue] {
        [
            "auto_cleanup": .object(["enabled": .int(state.autoCleanupEnabled ? 1 : 0)]),
            "auto_overwrite": .int(state.autoOverwriteEnabled ? 1 : 0),
            "locked_event_retention": .string(state.lockedEventRetention.protocolValue),
            "reserved_space_for_events_percent": .int(state.reservedEventSpacePercent)
        ]
    }

    private static func watermarkParameters(from state: WatermarkConfigurationState) -> [String: DeviceProtocolValue] {
        [
            "time_enabled": .int(state.timestampEnabled ? 1 : 0),
            "plate_enabled": .int(state.licensePlateEnabled ? 1 : 0),
            "plate_number": .string(state.licensePlate),
            "position": .string("bottom_right")
        ]
    }

    private static func systemPreferenceParameters(from state: DevicePreferencesState) -> [String: DeviceProtocolValue] {
        [
            "device_name": .string(state.deviceName),
            "time_zone": .string(state.timeZone),
            "language": .string("zh-CN"),
            "date_time_auto_sync": .int(1),
            "speaker_volume": .string(state.speakerVolume.protocolValue),
            "status_sounds": .int(state.statusSoundsEnabled ? 1 : 0)
        ]
    }

    private static func recordingState(from payload: [String: DeviceProtocolValue]) -> RecordingSettingsState? {
        guard let resolutionText = payload.object("resolution")?.string("current"),
              let resolution = RecordingResolutionOption(rawValue: resolutionText) else {
            return nil
        }

        var state = RecordingSettingsState.defaultValue
        state.resolution = resolution
        state.qualityPriority = payload.object("quality_priority")?.string("current").flatMap(RecordingQualityPriorityOption.protocolValue(_:)) ?? state.qualityPriority
        if let loopMinutes = payload.object("loop_recording")?.int("current") {
            state.loopDuration = LoopRecordingDurationOption.minutes(loopMinutes) ?? state.loopDuration
        }
        state.autoOverwrite = payload.bool("auto_overwrite") ?? state.autoOverwrite
        state.startBehavior = payload.string("start_behavior").flatMap(RecordingStartBehaviorOption.protocolValue(_:)) ?? state.startBehavior
        state.audioRecordingEnabled = payload.bool("audio_recording") ?? state.audioRecordingEnabled
        state.hdrNightRecordingEnabled = payload.bool("hdr_night_recording") ?? state.hdrNightRecordingEnabled
        state.recordingStatusIndicatorEnabled = payload.bool("status_indicator") ?? state.recordingStatusIndicatorEnabled
        state.recordingReminderEnabled = payload.bool("recording_reminder") ?? state.recordingReminderEnabled
        return state
    }

    private static func safetyState(from payload: [String: DeviceProtocolValue]) -> SafetySettingsState? {
        guard let collision = payload.object("collision"),
              let parking = payload.object("parking"),
              let eventRecording = payload.object("event_recording"),
              let notifications = payload.object("notifications") else {
            return nil
        }

        var state = SafetySettingsState.defaultValue
        state.gSensorSensitivity = collision.object("g_sensor_sensitivity")?.string("current").flatMap(SafetySensitivityOption.protocolValue(_:)) ?? state.gSensorSensitivity
        state.emergencyVideoLockEnabled = collision.bool("emergency_video_lock") ?? state.emergencyVideoLockEnabled
        state.parkingModeEnabled = parking.bool("parking_mode") ?? state.parkingModeEnabled
        state.motionDetectionEnabled = parking.bool("motion_detection") ?? state.motionDetectionEnabled
        state.impactDetectionEnabled = parking.bool("impact_detection") ?? state.impactDetectionEnabled
        if let seconds = eventRecording.object("clip_duration_sec")?.int("current") {
            state.eventClipDuration = EventClipDurationOption.seconds(seconds) ?? state.eventClipDuration
        }
        state.eventNotificationsEnabled = notifications.bool("event_notifications") ?? state.eventNotificationsEnabled
        return state
    }

    private static func storagePolicyState(from payload: [String: DeviceProtocolValue]) -> StoragePolicyState? {
        guard let sd = payload.object("sd"),
              let tf = payload.object("tf") else {
            return nil
        }

        var state = StoragePolicyState.defaultValue
        state.cardStatus = StorageCardStatus.protocolValue(sd.string("status") ?? "normal")
        state.usedSpaceGB = tf.double("used_gb") ?? state.usedSpaceGB
        state.totalSpaceGB = tf.double("total_gb") ?? state.totalSpaceGB
        if let hours = payload.object("maintenance")?.double("estimated_remaining_recording_hours") {
            state.estimatedHoursRemaining = String(format: "Approx. %.1f hours remaining at current quality.", hours)
        }
        if let cleanup = payload.object("maintenance")?.object("auto_cleanup") {
            state.autoCleanupEnabled = cleanup.bool("enabled") ?? state.autoCleanupEnabled
        }
        if let policy = payload.object("general_policy") {
            state.autoOverwriteEnabled = policy.bool("auto_overwrite") ?? state.autoOverwriteEnabled
            state.lockedEventRetention = policy.string("locked_event_retention").flatMap(LockedEventRetentionOption.protocolValue(_:)) ?? state.lockedEventRetention
        }
        state.reservedEventSpacePercent = payload.object("storage_allocation")?.int("reserved_space_for_events_percent") ?? state.reservedEventSpacePercent
        return state
    }

    private static func watermarkState(from payload: [String: DeviceProtocolValue]) -> WatermarkConfigurationState? {
        guard let timestampEnabled = payload.bool("time_enabled"),
              let plateEnabled = payload.bool("plate_enabled") else {
            return nil
        }

        return WatermarkConfigurationState(
            timestampEnabled: timestampEnabled,
            licensePlateEnabled: plateEnabled,
            licensePlate: payload.string("plate_number") ?? WatermarkConfigurationState.defaultValue.licensePlate
        )
    }

    private static func devicePreferencesState(
        from payload: [String: DeviceProtocolValue],
        fallback: DevicePreferencesState
    ) -> DevicePreferencesState {
        var state = fallback
        if let identity = payload.object("device_identity") {
            state.deviceName = identity.string("device_name") ?? state.deviceName
        }
        if let connectivity = payload.object("connectivity") {
            state.connectionName = connectivity.string("ssid") ?? state.connectionName
        }
        if let software = payload.object("software") {
            state.firmwareVersion = software.string("firmware_version") ?? state.firmwareVersion
        }
        if let localization = payload.object("localization") {
            state.timeZone = localization.string("time_zone") ?? state.timeZone
        }
        if let audio = payload.object("audio") {
            state.speakerVolume = audio.object("speaker_volume")?.string("current").flatMap(SpeakerVolumeOption.protocolValue(_:)) ?? state.speakerVolume
            state.statusSoundsEnabled = audio.bool("status_sounds") ?? state.statusSoundsEnabled
        }
        return state
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
