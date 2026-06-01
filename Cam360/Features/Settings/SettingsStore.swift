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
    @Published private(set) var networkIdentityValidationMessage: String?
    @Published private(set) var devicePreferences = DevicePreferencesState.defaultValue(
        deviceName: SettingsPlaceholder.deviceName,
        connectionName: SettingsPlaceholder.connectionName
    )
    @Published private(set) var safetySettings = SafetySettingsState.defaultValue
    @Published private(set) var firmwareUpdateStage: FirmwareUpdateStage = SettingsPlaceholder.firmwareCandidateUnavailableStage
    @Published private(set) var renameDeviceDraft = SettingsPlaceholder.deviceName
    @Published private(set) var deviceConnectionStatusTitle = "OFFLINE"
    @Published private(set) var deviceConnectionStatusText = "Not connected"
    @Published private(set) var deviceConnectionStatusTone: StatusTagTone = .neutral
    @Published private(set) var deviceCapabilities: Set<DeviceCapability> = []
    @Published private(set) var settingsHomeCategorySupport: [SettingsHomeCategory: Bool] = [:]

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

    var canCommitNetworkIdentityChanges: Bool {
        Self.networkIdentityValidationMessage(for: networkIdentity) == nil
    }

    func resetShell() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        seedDeviceState(from: nil)
        route = nil
        refresh()
    }

    func show(_ route: SettingsRoute) {
        guard isSettingsRouteSupported(route) else {
            return
        }

        if route == .renameDevice {
            renameDeviceDraft = devicePreferences.deviceName
        }

        self.route = route
        loadDeviceConfiguration(for: route)
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
        loadSettingsHomeSnapshot()
    }

    func isSettingsHomeCategorySupported(_ category: SettingsHomeCategory) -> Bool {
        settingsHomeCategorySupport[category] ?? true
    }

    func applyInitialStateSyncSnapshot(_ snapshot: DeviceStateSyncSnapshot) {
        if let settingsHome = snapshot.sections.object("settings_home") {
            if let deviceInfo = settingsHome.object("device_info") {
                applySettingsHomeDeviceInfo(deviceInfo)
            }
            if let categories = settingsHome["categories"]?.arrayValue {
                applySettingsHomeCategories(categories)
            }
        }

        if let recording = snapshot.sections.object("recording"),
           let state = Self.recordingState(from: recording) {
            applyRecordingSettingsState(state)
        }
        if let storage = snapshot.sections.object("storage"),
           let state = Self.storagePolicyState(from: storage) {
            applyStoragePolicyState(state)
        }
        if let safety = snapshot.sections.object("safety"),
           let state = Self.safetyState(from: safety) {
            safetySettings = state
        }
        if let systemPreferences = snapshot.sections.object("system_preferences") {
            devicePreferences = Self.devicePreferencesState(
                from: systemPreferences,
                fallback: devicePreferences
            )
        }
        if let watermark = snapshot.sections.object("watermark"),
           let state = Self.watermarkState(from: watermark) {
            watermarkConfiguration = state
        }
        if let wifi = snapshot.sections.object("wifi"),
           let ssid = wifi.string("ssid"),
           ssid.isEmpty == false {
            networkIdentity = NetworkIdentityState(
                networkName: ssid,
                password: networkIdentity.password,
                statusCode: wifi.int("status") ?? networkIdentity.statusCode
            )
            networkIdentityValidationMessage = Self.networkIdentityValidationMessage(for: networkIdentity)
            devicePreferences.connectionName = ssid
        }
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
        guard Self.isStoragePolicyEditKeyPath(keyPath) == false || storagePolicy.canEditPolicies else {
            return
        }

        var nextState = storagePolicy
        if keyPath == \StoragePolicyState.reservedEventSpacePercent,
           let percent = value as? Int {
            nextState.reservedEventSpacePercent = Self.normalizedReservedEventSpacePercent(percent)
            submitStoragePolicy(nextState)
            return
        }
        if keyPath == \StoragePolicyState.autoCleanupRetentionDays,
           let days = value as? Int {
            nextState.autoCleanupRetentionDays = Self.normalizedAutoCleanupRetentionDays(days)
            submitStoragePolicy(nextState)
            return
        }
        nextState[keyPath: keyPath] = value
        submitStoragePolicy(nextState)
    }

    func retryStorageCardCheck() {
        storagePolicy.cardStatus = .ready
        storagePolicy.formatStage = .idle
    }

    func formatStorageCard() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            storagePolicy.cardStatus = .ready
            storagePolicy.usedSpaceGB = 74.2
            storagePolicy.formatStage = .idle
            return
        }

        storagePolicy.formatStage = .inProgress(progress: 0)
        deviceSession.formatStorage { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let format) where format.formatted:
                self.storagePolicy.cardStatus = .ready
                self.storagePolicy.usedSpaceGB = 0
                self.storagePolicy.formatStage = .completed
                self.refreshStorageSourcesAfterFormat(using: deviceSession)
            case .success, .failure:
                self.storagePolicy.formatStage = .failed
            }
        }
    }

    private func resetOfflineStorageCard() {
        storagePolicy.cardStatus = .ready
        storagePolicy.usedSpaceGB = 74.2
        storagePolicy.formatStage = .idle
    }

    private func refreshStorageSourcesAfterFormat(using deviceSession: DeviceSession) {
        deviceSession.fetchSDCardStatus { [weak self] result in
            guard let self, case .success(let online) = result else {
                return
            }

            self.applyStorageCardStatus(online)
        }
        deviceSession.fetchStorageCapacity { [weak self] result in
            guard let self, case .success(let capacity) = result else {
                return
            }

            self.applyStorageCapacity(capacity)
        }
        deviceSession.fetchFileList { _ in }
    }

    private func applyStorageCardStatus(_ online: Int) {
        switch online {
        case 0:
            storagePolicy.cardStatus = .noCard
        case 1:
            storagePolicy.cardStatus = .ready
            storagePolicy.formatRequired = false
        case 2:
            storagePolicy.cardStatus = .error
            storagePolicy.formatRequired = true
        default:
            storagePolicy.cardStatus = .error
        }
    }

    private func applyStorageCapacity(_ capacity: DeviceStorageCapacity) {
        let usedMegabytes = max(0, capacity.totalMegabytes - capacity.remainingMegabytes)
        storagePolicy.usedSpaceGB = Double(usedMegabytes) / 1024
        storagePolicy.totalSpaceGB = Double(capacity.totalMegabytes) / 1024
        storagePolicy.usagePercent = nil
    }

    func updateWatermarkConfiguration<Value>(
        _ keyPath: WritableKeyPath<WatermarkConfigurationState, Value>,
        to value: Value
    ) {
        if keyPath == \WatermarkConfigurationState.licensePlate,
           let plateNumber = value as? String {
            watermarkConfiguration.licensePlate = Self.normalizedWatermarkPlateNumber(plateNumber)
            return
        }
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
        networkIdentityValidationMessage = Self.networkIdentityValidationMessage(for: networkIdentity)
    }

    func prepareNetworkIdentity() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            return
        }

        deviceSession.fetchStateSync(scope: .wifi) { [weak self] result in
            guard let self,
                  case .success(let snapshot) = result,
                  let wifi = snapshot.sections.object("wifi"),
                  let ssid = wifi.string("ssid"),
                  ssid.isEmpty == false else {
                return
            }

            self.networkIdentity = NetworkIdentityState(
                networkName: ssid,
                password: self.networkIdentity.password,
                statusCode: wifi.int("status") ?? self.networkIdentity.statusCode
            )
            self.networkIdentityValidationMessage = Self.networkIdentityValidationMessage(for: self.networkIdentity)
            self.devicePreferences.connectionName = ssid
        }
    }

    @discardableResult
    func commitNetworkIdentityChanges() -> Bool {
        if let validationMessage = Self.networkIdentityValidationMessage(for: networkIdentity) {
            networkIdentityValidationMessage = validationMessage
            return false
        }

        networkIdentityValidationMessage = nil
        guard canSubmitSettingsToDevice, let deviceSession else {
            devicePreferences.connectionName = networkIdentity.networkName
            return true
        }

        deviceSession.updateAccessPointIdentity(ssid: networkIdentity.networkName, password: networkIdentity.password) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let identity) = result {
                self.networkIdentity = NetworkIdentityState(
                    networkName: identity.ssid,
                    password: identity.password ?? self.networkIdentity.password,
                    statusCode: identity.isEnabled ? 1 : 0
                )
                self.networkIdentityValidationMessage = Self.networkIdentityValidationMessage(for: self.networkIdentity)
                self.devicePreferences.connectionName = identity.ssid
                self.devicePreferences.connectionStatus = "disconnected"
                deviceSession.send(.disconnect)
            }
        }

        return true
    }

    private func commitOfflineNetworkIdentityChanges() {
        devicePreferences.connectionName = networkIdentity.networkName
    }

    private static func networkIdentityValidationMessage(for identity: NetworkIdentityState) -> String? {
        let trimmedNetworkName = identity.networkName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNetworkName.isEmpty == false else {
            return "Wi-Fi name is required."
        }
        guard identity.networkName.lengthOfBytes(using: .utf8) <= 32 else {
            return "Wi-Fi name must be 32 bytes or fewer."
        }
        guard (8...63).contains(identity.password.count) else {
            return "Wi-Fi password must be 8-63 characters."
        }
        guard identity.password.unicodeScalars.allSatisfy({ (0x20...0x7E).contains($0.value) }) else {
            return "Wi-Fi password must use printable ASCII characters."
        }

        return nil
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
        guard devicePreferences.deviceNameEditable else {
            return
        }

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
        firmwareUpdateStage = SettingsPlaceholder.firmwareCandidateUnavailableStage
    }

    func markFirmwareUpdateFailed() {
        firmwareUpdateStage = .failed
    }

    func cancelFirmwareUpdate() {
        firmwareUpdateStage = SettingsPlaceholder.firmwareCandidateUnavailableStage
    }

    func restoreDefaultDeviceConfiguration() {
        guard devicePreferences.factoryResetSupported else {
            return
        }

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
        firmwareUpdateStage = SettingsPlaceholder.firmwareCandidateUnavailableStage
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
        firmwareUpdateStage = SettingsPlaceholder.firmwareCandidateUnavailableStage
        renameDeviceDraft = deviceName
    }

    private func bindDeviceSession() {
        deviceSession?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncDeviceSessionState(state)
            }
            .store(in: &cancellables)

        deviceSession?.$deviceStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncDeviceSessionStatus(status)
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

    private func syncDeviceSessionStatus(_ status: DeviceSessionStatus) {
        if let latestProgressEvent = status.latestProgressEvent {
            applySettingsProgressEvent(latestProgressEvent)
            return
        }

        if let formatProgress = status.progressEvents.values.first(where: { $0.topic == "FORMAT_PROGRESS" }) {
            applyStorageFormatProgress(formatProgress)
        }

        if let upgradeProgress = status.progressEvents.values.first(where: { $0.topic == "UPGRADE_PROGRESS" }) {
            applyFirmwareUpdateProgress(upgradeProgress)
        }
    }

    private func applySettingsProgressEvent(_ progressEvent: DeviceProgressEvent) {
        switch progressEvent.topic {
        case "FORMAT_PROGRESS":
            applyStorageFormatProgress(progressEvent)
        case "UPGRADE_PROGRESS":
            applyFirmwareUpdateProgress(progressEvent)
        default:
            break
        }
    }

    private func applyFirmwareUpdateProgress(_ progressEvent: DeviceProgressEvent) {
        switch progressEvent.status?.lowercased() {
        case "failed":
            firmwareUpdateStage = .failed
        case "completed":
            firmwareUpdateStage = .completed
        default:
            guard let progress = progressEvent.progress else {
                return
            }
            firmwareUpdateStage = .inProgress(
                progress: Self.progressFraction(from: progress),
                stageTitle: Self.firmwareStageTitle(progressEvent.stage)
            )
        }
    }

    private func applyStorageFormatProgress(_ progressEvent: DeviceProgressEvent) {
        switch progressEvent.status?.lowercased() {
        case "failed":
            storagePolicy.cardStatus = .error
            storagePolicy.formatStage = .failed
        case "completed":
            storagePolicy.cardStatus = .ready
            storagePolicy.usedSpaceGB = 0
            storagePolicy.formatStage = .completed
        default:
            guard let progress = progressEvent.progress else {
                return
            }
            storagePolicy.formatStage = .inProgress(progress: Self.progressFraction(from: progress))
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

    private var canSubmitSettingsToDevice: Bool {
        deviceSessionState.canSendDeviceCommand && deviceSession != nil
    }

    private func loadSettingsHomeSnapshot() {
        guard canSubmitSettingsToDevice, let deviceSession else {
            return
        }

        deviceSession.fetchStateSync(scope: .settingsHome) { [weak self] result in
            guard let self,
                  case .success(let snapshot) = result,
                  let settingsHome = snapshot.sections.object("settings_home") else {
                return
            }

            if let deviceInfo = settingsHome.object("device_info") {
                self.applySettingsHomeDeviceInfo(deviceInfo)
            }
            if let categories = settingsHome["categories"]?.arrayValue {
                self.applySettingsHomeCategories(categories)
            }
        }
    }

    private func applySettingsHomeDeviceInfo(_ deviceInfo: [String: DeviceProtocolValue]) {
        var updatedPreferences = devicePreferences

        if let deviceName = deviceInfo.string("device_name") {
            updatedPreferences.deviceName = deviceName
            renameDeviceDraft = deviceName
        }

        if let firmwareVersion = deviceInfo.string("fw_version") {
            updatedPreferences.firmwareVersion = firmwareVersion
        }

        devicePreferences = updatedPreferences
    }

    private func applySettingsHomeCategories(_ categories: [DeviceProtocolValue]) {
        var support = settingsHomeCategorySupport
        for categoryValue in categories {
            guard let categoryObject = categoryValue.objectValue,
                  let categoryKey = categoryObject.string("key"),
                  let category = SettingsHomeCategory(rawValue: categoryKey) else {
                continue
            }

            support[category] = categoryObject.bool("supported") ?? true
        }
        settingsHomeCategorySupport = support
    }

    private func isSettingsRouteSupported(_ route: SettingsRoute) -> Bool {
        guard let category = Self.settingsHomeCategory(for: route) else {
            return true
        }

        return isSettingsHomeCategorySupported(category)
    }

    private func loadDeviceConfiguration(for route: SettingsRoute) {
        guard canSubmitSettingsToDevice else {
            return
        }

        switch route {
        case .recordingSettings:
            loadRecordingConfiguration()
        case .storagePolicy:
            loadStoragePolicyConfiguration()
        case .safetySettings:
            loadSafetyConfiguration()
        case .systemPreferences:
            loadSystemPreferencesConfiguration()
        case .deviceSettings:
            loadSystemPreferencesConfiguration()
        case .watermarkConfiguration:
            loadWatermarkConfiguration()
        case .firmwareUpdate,
            .helpCenter,
            .notificationSettings,
            .renameDevice,
            .statistics,
            .systemPermissions:
            break
        }
    }

    private func loadRecordingConfiguration() {
        loadStateSyncConfiguration(scope: .recording, sectionKey: "recording") { [weak self] payload in
            guard let self, let state = Self.recordingState(from: payload) else {
                return false
            }
            self.applyRecordingSettingsState(state)
            return true
        } fallback: { [weak self] in
            self?.loadRecordingConfigurationFallback()
        }
    }

    private func loadStoragePolicyConfiguration() {
        loadStateSyncConfiguration(scope: .storage, sectionKey: "storage") { [weak self] payload in
            guard let self, let state = Self.storagePolicyState(from: payload) else {
                return false
            }
            self.applyStoragePolicyState(state)
            return true
        } fallback: { [weak self] in
            self?.loadStoragePolicyConfigurationFallback()
        }
    }

    private func loadSafetyConfiguration() {
        loadStateSyncConfiguration(scope: .safety, sectionKey: "safety") { [weak self] payload in
            guard let self, let state = Self.safetyState(from: payload) else {
                return false
            }
            self.safetySettings = state
            return true
        } fallback: { [weak self] in
            self?.loadSafetyConfigurationFallback()
        }
    }

    private func loadSystemPreferencesConfiguration() {
        loadStateSyncConfiguration(scope: .systemPreferences, sectionKey: "system_preferences") { [weak self] payload in
            guard let self else {
                return false
            }
            self.devicePreferences = Self.devicePreferencesState(
                from: payload,
                fallback: self.devicePreferences
            )
            return true
        } fallback: { [weak self] in
            self?.loadSystemPreferencesConfigurationFallback()
        }
    }

    private func loadWatermarkConfiguration() {
        loadStateSyncConfiguration(scope: .watermark, sectionKey: "watermark") { [weak self] payload in
            guard let self, let state = Self.watermarkState(from: payload) else {
                return false
            }
            self.watermarkConfiguration = state
            return true
        } fallback: { [weak self] in
            self?.loadWatermarkConfigurationFallback()
        }
    }

    private func loadStateSyncConfiguration(
        scope: DeviceStateSyncScope,
        sectionKey: String,
        apply: @escaping ([String: DeviceProtocolValue]) -> Bool,
        fallback: @escaping () -> Void
    ) {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchStateSync(scope: scope) { result in
            if case .success(let snapshot) = result,
               let section = snapshot.sections.object(sectionKey),
               apply(section) {
                return
            }

            fallback()
        }
    }

    private func loadRecordingConfigurationFallback() {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchRecordingConfiguration { [weak self] result in
            guard let self, case .success(let payload) = result else {
                return
            }
            self.applyRecordingSettingsState(Self.recordingState(from: payload) ?? self.recordingSettings)
        }
    }

    private func loadStoragePolicyConfigurationFallback() {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchStoragePolicyConfiguration { [weak self] result in
            guard let self, case .success(let payload) = result else {
                return
            }
            self.applyStoragePolicyState(Self.storagePolicyState(from: payload) ?? self.storagePolicy)
        }
    }

    private func loadSafetyConfigurationFallback() {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchSafetyConfiguration { [weak self] result in
            guard let self, case .success(let payload) = result else {
                return
            }
            self.safetySettings = Self.safetyState(from: payload) ?? self.safetySettings
        }
    }

    private func loadSystemPreferencesConfigurationFallback() {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchSystemPreferencesConfiguration { [weak self] result in
            guard let self, case .success(let payload) = result else {
                return
            }
            self.devicePreferences = Self.devicePreferencesState(
                from: payload,
                fallback: self.devicePreferences
            )
        }
    }

    private func loadWatermarkConfigurationFallback() {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchWatermarkConfiguration { [weak self] result in
            guard let self, case .success(let payload) = result else {
                return
            }
            self.watermarkConfiguration = Self.watermarkState(from: payload) ?? self.watermarkConfiguration
        }
    }

    private func submitRecordingSettings(_ state: RecordingSettingsState) {
        guard canSubmitSettingsToDevice, let deviceSession else {
            applyRecordingSettingsState(state)
            return
        }

        deviceSession.updateRecordingConfiguration(parameters: Self.recordingParameters(from: state)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.applyRecordingSettingsState(Self.recordingState(from: payload) ?? state)
            }
        }
    }

    private func submitStoragePolicy(_ state: StoragePolicyState) {
        guard canSubmitSettingsToDevice, let deviceSession else {
            applyStoragePolicyState(state)
            return
        }

        deviceSession.updateStoragePolicyConfiguration(parameters: Self.storagePolicyParameters(from: state)) { [weak self] result in
            guard let self else {
                return
            }
            if case .success(let payload) = result {
                self.applyStoragePolicyState(Self.storagePolicyState(from: payload) ?? state)
            }
        }
    }

    private func applyRecordingSettingsState(_ state: RecordingSettingsState) {
        recordingSettings = state
        storagePolicy.autoOverwriteEnabled = state.autoOverwrite
    }

    private func applyStoragePolicyState(_ state: StoragePolicyState) {
        storagePolicy = state
        recordingSettings.autoOverwrite = state.autoOverwriteEnabled
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
            "auto_cleanup": .object([
                "enabled": .int(state.autoCleanupEnabled ? 1 : 0),
                "retention_days": .int(Self.normalizedAutoCleanupRetentionDays(state.autoCleanupRetentionDays))
            ]),
            "auto_overwrite": .int(state.autoOverwriteEnabled ? 1 : 0),
            "locked_event_retention": .string(state.lockedEventRetention.protocolValue),
            "reserved_space_for_events_percent": .int(Self.normalizedReservedEventSpacePercent(state.reservedEventSpacePercent))
        ]
    }

    private static func isStoragePolicyEditKeyPath<Value>(
        _ keyPath: WritableKeyPath<StoragePolicyState, Value>
    ) -> Bool {
        let anyKeyPath = keyPath as AnyKeyPath
        return anyKeyPath == (\StoragePolicyState.autoCleanupEnabled as AnyKeyPath) ||
            anyKeyPath == (\StoragePolicyState.autoCleanupRetentionDays as AnyKeyPath) ||
            anyKeyPath == (\StoragePolicyState.autoOverwriteEnabled as AnyKeyPath) ||
            anyKeyPath == (\StoragePolicyState.lockedEventRetention as AnyKeyPath) ||
            anyKeyPath == (\StoragePolicyState.reservedEventSpacePercent as AnyKeyPath)
    }

    private static let supportedAutoCleanupRetentionDays: Set<Int> = [7, 15, 30, 60]

    private static func normalizedAutoCleanupRetentionDays(_ days: Int) -> Int {
        supportedAutoCleanupRetentionDays.contains(days) ? days : StoragePolicyState.defaultValue.autoCleanupRetentionDays
    }

    private static func normalizedReservedEventSpacePercent(_ percent: Int) -> Int {
        min(max(percent, 0), 50)
    }

    private static func storageUsagePercent(from value: DeviceProtocolValue) -> Int? {
        if case .bool = value {
            return nil
        }
        guard let percent = value.intValue, (0...100).contains(percent) else {
            return nil
        }
        return percent
    }

    private static func watermarkParameters(from state: WatermarkConfigurationState) -> [String: DeviceProtocolValue] {
        [
            "time_enabled": .int(state.timestampEnabled ? 1 : 0),
            "plate_enabled": .int(state.licensePlateEnabled ? 1 : 0),
            "plate_number": .string(Self.normalizedWatermarkPlateNumber(state.licensePlate)),
            "position": .string(state.position.protocolValue)
        ]
    }

    private static let watermarkPlateNumberMaxLength = 8

    private static func normalizedWatermarkPlateNumber(_ plateNumber: String) -> String {
        String(plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).prefix(watermarkPlateNumberMaxLength))
    }

    private static func systemPreferenceParameters(from state: DevicePreferencesState) -> [String: DeviceProtocolValue] {
        [
            "device_name": .string(state.deviceName),
            "time_zone": .string(state.timeZone),
            "language": .string(state.language),
            "date_time_auto_sync": .int(state.dateTimeAutoSyncEnabled ? 1 : 0),
            "speaker_volume": .string(state.speakerVolume.protocolValue),
            "status_sounds": .int(state.statusSoundsEnabled ? 1 : 0)
        ]
    }

    private static func unique<Value: Equatable>(_ values: [Value]) -> [Value] {
        values.reduce(into: []) { uniqueValues, value in
            if uniqueValues.contains(value) == false {
                uniqueValues.append(value)
            }
        }
    }

    private static func estimatedStorageText(megabytes: Double) -> String {
        let gigabytes = max(megabytes, 0) / 1024
        return String(format: "Estimated storage per hour: ~%.1f GB", gigabytes)
    }

    private static func recordingState(from payload: [String: DeviceProtocolValue]) -> RecordingSettingsState? {
        guard let resolutionText = payload.object("resolution")?.string("current"),
              let resolution = RecordingResolutionOption(rawValue: resolutionText) else {
            return nil
        }

        var state = RecordingSettingsState.defaultValue
        state.resolution = resolution
        if let resolutionOptions = payload.object("resolution")?["options"]?.arrayValue?
            .compactMap(\.stringValue)
            .compactMap(RecordingResolutionOption.init(rawValue:)),
            resolutionOptions.isEmpty == false {
            state.resolutionOptions = unique(resolutionOptions)
        }
        if let qualityPriority = payload.object("quality_priority") {
            state.qualityPriority = qualityPriority.string("current").flatMap(RecordingQualityPriorityOption.protocolValue(_:)) ?? state.qualityPriority
            let options = qualityPriority["options"]?.arrayValue?
                .compactMap(\.stringValue)
                .compactMap(RecordingQualityPriorityOption.protocolValue(_:)) ?? []
            if options.isEmpty == false {
                state.qualityPriorityOptions = unique(options)
            }
        }
        if let loopRecording = payload.object("loop_recording"),
           let loopMinutes = loopRecording.int("current") {
            state.loopDuration = LoopRecordingDurationOption.minutes(loopMinutes) ?? state.loopDuration
            let options = loopRecording["options"]?.arrayValue?
                .compactMap(\.intValue)
                .compactMap(LoopRecordingDurationOption.minutes(_:)) ?? []
            if options.isEmpty == false {
                state.loopDurationOptions = unique(options)
            }
        }
        state.autoOverwrite = payload.bool("auto_overwrite") ?? state.autoOverwrite
        state.startBehavior = payload.string("start_behavior").flatMap(RecordingStartBehaviorOption.protocolValue(_:)) ?? state.startBehavior
        state.audioRecordingEnabled = payload.bool("audio_recording") ?? state.audioRecordingEnabled
        state.hdrNightRecordingEnabled = payload.bool("hdr_night_recording") ?? state.hdrNightRecordingEnabled
        state.recordingStatusIndicatorEnabled = payload.bool("status_indicator") ?? state.recordingStatusIndicatorEnabled
        state.recordingReminderEnabled = payload.bool("recording_reminder") ?? state.recordingReminderEnabled
        if let estimatedStorageMB = payload.double("estimated_storage_per_hour_mb") {
            state.estimatedStoragePerHour = estimatedStorageText(megabytes: estimatedStorageMB)
        }
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
        if let gSensorSensitivity = collision.object("g_sensor_sensitivity") {
            state.gSensorSensitivity = gSensorSensitivity.string("current").flatMap(SafetySensitivityOption.protocolValue(_:)) ?? state.gSensorSensitivity
            let options = gSensorSensitivity["options"]?.arrayValue?
                .compactMap(\.stringValue)
                .compactMap(SafetySensitivityOption.protocolValue(_:)) ?? []
            if options.isEmpty == false {
                state.gSensorSensitivityOptions = unique(options)
            }
        }
        state.emergencyVideoLockEnabled = collision.bool("emergency_video_lock") ?? state.emergencyVideoLockEnabled
        state.parkingModeEnabled = parking.bool("parking_mode") ?? state.parkingModeEnabled
        state.motionDetectionEnabled = parking.bool("motion_detection") ?? state.motionDetectionEnabled
        state.impactDetectionEnabled = parking.bool("impact_detection") ?? state.impactDetectionEnabled
        if let clipDuration = eventRecording.object("clip_duration_sec"),
           let seconds = clipDuration.int("current") {
            state.eventClipDuration = EventClipDurationOption.seconds(seconds) ?? state.eventClipDuration
            let options = clipDuration["options"]?.arrayValue?
                .compactMap(\.intValue)
                .compactMap(EventClipDurationOption.seconds(_:)) ?? []
            if options.isEmpty == false {
                state.eventClipDurationOptions = unique(options)
            }
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
        if sd.int("online") == 0 {
            state.cardStatus = .noCard
        } else {
            state.cardStatus = StorageCardStatus.protocolValue(sd.string("status") ?? "normal")
        }
        state.cardErrorDescription = storageCardErrorDescription(
            code: sd.string("error_code"),
            message: sd.string("error_message")
        )
        state.formatRequired = sd.bool("format_required") ?? state.formatRequired
        state.policyEditable = sd.bool("policy_editable") ?? state.policyEditable
        state.usedSpaceGB = tf.double("used_gb") ?? state.usedSpaceGB
        state.totalSpaceGB = tf.double("total_gb") ?? state.totalSpaceGB
        if let usageValue = tf["usage_percent"] {
            guard let usagePercent = storageUsagePercent(from: usageValue) else {
                return nil
            }
            state.usagePercent = usagePercent
        }
        if let hours = payload.object("maintenance")?.double("estimated_remaining_recording_hours") {
            let profile = payload.object("maintenance")?.string("estimate_profile") ?? "current quality"
            state.estimatedHoursRemaining = String(format: "Approx. %.1f hours remaining at %@.", hours, profile)
        }
        if let maintenance = payload.object("maintenance") {
            state.formatSupported = maintenance.bool("format_supported") ?? state.formatSupported
        }
        if let cleanup = payload.object("maintenance")?.object("auto_cleanup") {
            state.autoCleanupEnabled = cleanup.bool("enabled") ?? state.autoCleanupEnabled
            if let retentionDays = cleanup.int("retention_days") {
                state.autoCleanupRetentionDays = normalizedAutoCleanupRetentionDays(retentionDays)
            }
        }
        if let policy = payload.object("general_policy") {
            state.autoOverwriteEnabled = policy.bool("auto_overwrite") ?? state.autoOverwriteEnabled
            state.lockedEventRetention = policy.string("locked_event_retention").flatMap(LockedEventRetentionOption.protocolValue(_:)) ?? state.lockedEventRetention
        }
        if let reservedPercent = payload.object("storage_allocation")?.int("reserved_space_for_events_percent") {
            state.reservedEventSpacePercent = normalizedReservedEventSpacePercent(reservedPercent)
        }
        return state
    }

    private static func storageCardErrorDescription(code: String?, message: String?) -> String {
        switch code?.lowercased() {
        case "no_card":
            return "No SD card was detected. Insert a card before recording."
        case "unsupported_card":
            return "The inserted SD card is not supported by this camera. Use a compatible card before recording."
        case "filesystem_error", "unreadable":
            return StoragePolicyState.defaultValue.cardErrorDescription
        default:
            if let message, message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return "\(StoragePolicyState.defaultValue.cardErrorDescription) Diagnostic: \(message)"
            }
            return StoragePolicyState.defaultValue.cardErrorDescription
        }
    }

    private static func settingsHomeCategory(for route: SettingsRoute) -> SettingsHomeCategory? {
        switch route {
        case .recordingSettings:
            return .recording
        case .storagePolicy:
            return .storage
        case .safetySettings:
            return .safety
        case .systemPreferences:
            return .systemPreferences
        case .watermarkConfiguration:
            return .watermark
        case .deviceSettings,
            .firmwareUpdate,
            .helpCenter,
            .notificationSettings,
            .renameDevice,
            .statistics,
            .systemPermissions:
            return nil
        }
    }

    private static func watermarkState(from payload: [String: DeviceProtocolValue]) -> WatermarkConfigurationState? {
        guard let timestampEnabled = payload.bool("time_enabled"),
              let plateEnabled = payload.bool("plate_enabled") else {
            return nil
        }

        return WatermarkConfigurationState(
            timestampEnabled: timestampEnabled,
            licensePlateEnabled: plateEnabled,
            licensePlate: normalizedWatermarkPlateNumber(
                payload.string("plate_number") ?? WatermarkConfigurationState.defaultValue.licensePlate
            ),
            position: payload.string("position").flatMap(WatermarkPositionOption.protocolValue(_:)) ?? WatermarkConfigurationState.defaultValue.position
        )
    }

    private static func devicePreferencesState(
        from payload: [String: DeviceProtocolValue],
        fallback: DevicePreferencesState
    ) -> DevicePreferencesState {
        var state = fallback
        if let identity = payload.object("device_identity") {
            state.deviceName = identity.string("device_name") ?? state.deviceName
            state.deviceNameEditable = identity.bool("device_name_editable") ?? state.deviceNameEditable
        }
        if let connectivity = payload.object("connectivity") {
            state.connectionName = connectivity.string("ssid") ?? state.connectionName
            state.connectionStatus = connectivity.string("status") ?? state.connectionStatus
        }
        if let software = payload.object("software") {
            state.firmwareVersion = software.string("firmware_version") ?? state.firmwareVersion
            state.firmwareUpdateEntryEnabled = software.bool("update_entry_enabled") ?? state.firmwareUpdateEntryEnabled
        }
        if let localization = payload.object("localization") {
            state.timeZone = localization.string("time_zone") ?? state.timeZone
            state.language = localization.string("language") ?? state.language
            state.dateTimeAutoSyncEnabled = localization.bool("date_time_auto_sync") ?? state.dateTimeAutoSyncEnabled
        }
        if let audio = payload.object("audio") {
            if let speakerVolume = audio.object("speaker_volume") {
                state.speakerVolume = speakerVolume.string("current").flatMap(SpeakerVolumeOption.protocolValue(_:)) ?? state.speakerVolume
                let options = speakerVolume["options"]?.arrayValue?
                    .compactMap(\.stringValue)
                    .compactMap(SpeakerVolumeOption.protocolValue(_:)) ?? []
                if options.isEmpty == false {
                    state.speakerVolumeOptions = options.reduce(into: []) { uniqueOptions, option in
                        if uniqueOptions.contains(option) == false {
                            uniqueOptions.append(option)
                        }
                    }
                }
            }
            state.statusSoundsEnabled = audio.bool("status_sounds") ?? state.statusSoundsEnabled
        }
        if let maintenance = payload.object("maintenance") {
            state.factoryResetSupported = maintenance.bool("factory_reset_supported") ?? state.factoryResetSupported
        }
        return state
    }
}

private enum SettingsPlaceholder {
    static let deviceName = "DriveCam X Pro"
    static let connectionName = "Vigilant_Dash_4K"
    static let firmwareCandidateUnavailableStage = FirmwareUpdateStage.unavailable(
        message: "升级候选版本服务尚未接入，无法发起设备固件升级。"
    )
}

private extension SettingsStore {
    static func progressFraction(from percent: Int) -> Double {
        min(1, max(0, Double(percent) / 100))
    }

    static func firmwareStageTitle(_ stage: String?) -> String {
        switch stage?.lowercased() {
        case "downloading":
            return "Downloading firmware"
        case "installing":
            return "Installing firmware"
        case "restarting":
            return "Restarting device"
        default:
            return "Updating firmware"
        }
    }
}
