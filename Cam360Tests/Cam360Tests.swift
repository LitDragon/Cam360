import Testing
import Foundation
@testable import Cam360

@MainActor
struct Cam360Tests {
    @Test
    func bootstrapWithoutKnownDevicesShowsDashboard() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.router.route == .main(.dashboard))
    }

    @Test
    func bootstrapAfterOnboardingShowsMain() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        preferenceStore.hasCompletedOnboarding = true

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.router.route == .main(.dashboard))
    }

    @Test
    func routerTransitionsArePredictable() {
        let router = AppRouter(route: .main(.dashboard))

        router.showMain(tab: .gallery)
        #expect(router.route == .main(.gallery))

        router.selectedMainTab = .settings
        #expect(router.route == .main(.settings))

        router.showOnboarding()
        #expect(router.route == .onboarding)
    }

    @Test
    func appContainerSharesDeviceSessionWithOnboarding() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.container.deviceOnboardingStore.deviceSession === bootstrap.container.deviceSession)
    }

    @Test
    func deviceSessionCompletesOperationBackToReadyDevice() {
        let session = DeviceSession()
        let deviceInfo = makeDeviceInfo()

        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(deviceInfo))
        session.send(.startOperation(.livePreview))

        #expect(session.state == .busy(operation: .livePreview, deviceInfo: deviceInfo))
        #expect(session.currentOperation == .livePreview)

        session.send(.operationCompleted)

        #expect(session.state == .ready(deviceInfo))
        #expect(session.currentOperation == nil)
    }

    @Test
    func deviceSessionRecoveryReturnsToLastReadyDevice() {
        let session = DeviceSession()
        let deviceInfo = makeDeviceInfo()

        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(deviceInfo))
        session.send(.startOperation(.updateSettings))
        session.send(.connectionLost)
        session.send(.startRecovery)

        #expect(session.state == .recovering(previousState: .ready(deviceInfo)))

        session.send(.recoverySucceeded)

        #expect(session.state == .ready(deviceInfo))
    }

    @Test
    func dashboardStoreShowsFeatureSheetUntilDismissed() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let store = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(store.hasDevices == false)
        #expect(store.shouldShowFeatureSheet)

        store.dismissFeatureSheet()
        #expect(store.shouldShowFeatureSheet == false)
        #expect(preferenceStore.hasCompletedOnboarding)
    }

    @Test
    func dashboardStoreExposesDeviceHubStates() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro"),
            makeKnownDevice(id: "cam360-rear", name: "Rear View"),
            makeKnownDevice(id: "cam360-cabin", name: "Cabin View"),
            makeKnownDevice(id: "cam360-side", name: "Side View")
        ])

        let store = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(store.hasDevices)
        #expect(store.isRecording == false)
        #expect(store.recentEvents.count == 4)

        store.toggleRecording()
        #expect(store.isRecording)

        store.selectDevice(id: "cam360-cabin")
        #expect(store.recentEvents.isEmpty)
        if case let .available(summary) = store.storageState {
            #expect(summary.usageText == "58% USED")
        } else {
            #expect(Bool(false))
        }

        store.selectDevice(id: "cam360-side")
        #expect(store.isRecording)
        if case let .unavailable(title, _) = store.storageState {
            #expect(title == "No SD card detected")
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func dashboardStoreUsesInjectedContentProvider() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-real-source", name: "Road Camera")
        ])

        let store = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            contentProvider: TestDashboardContentProvider()
        )

        #expect(store.selectedDevice?.status == .offline)
        #expect(store.isRecording)
    }

    @Test
    func dashboardStoreDerivesKnownDeviceStatusFromDeviceSession() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let session = DeviceSession()
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro"),
            makeKnownDevice(id: "cam360-rear", name: "Rear View")
        ])
        let store = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            contentProvider: TestDashboardContentProvider(),
            deviceSession: session
        )

        #expect(store.devices.first(where: { $0.id == "cam360-rear" })?.status == .offline)

        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(
            DeviceInfo(
                id: "cam360-rear",
                name: "Rear View",
                firmwareVersion: "v1.1.0",
                capabilities: [.settings]
            )
        ))

        #expect(await waitForOnboardingState {
            store.devices.first(where: { $0.id == "cam360-rear" })?.status == .connected
        })

        session.send(.connectionLost)

        #expect(await waitForOnboardingState {
            store.devices.first(where: { $0.id == "cam360-rear" })?.status == .offline
        })
    }

    @Test
    func deviceOnboardingStoreHappyPathPersistsDeviceAndReturnsToDashboard() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.dashboard))
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(
            protocolClient: protocolClient,
            appVersion: "1.2.3",
            deviceName: "Road Camera"
        )
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        store.networkName = "RoadCam_AP"

        store.startSearch()
        #expect(store.route == .searching)

        store.advanceFromSearching()
        #expect(store.route == .wifiDetails)
        #expect(store.canContinueWithWiFiDetails)

        store.continueFromWiFiDetails()
        #expect(store.route == .connecting)

        protocolClient.completeHandshakeSuccessfully(deviceID: "road-camera-001")
        #expect(await waitForOnboardingState { store.route == .success })
        #expect(store.route == .success)
        #expect(store.addedDeviceName == "Road Camera")
        #expect(repository.fetchKnownDevices().count == 1)
        #expect(repository.fetchKnownDevices().first?.id == "road-camera-001")
        #expect(repository.fetchKnownDevices().first?.name == "Road Camera")
        #expect(repository.fetchKnownDevices().first?.hotspotSSID == "RoadCam_AP")
        #expect(preferenceStore.hasCompletedOnboarding)

        store.enterHome()
        #expect(router.route == .main(.dashboard))
    }

    @Test
    func deviceOnboardingRequiresPasswordBeforeConnecting() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.dashboard))
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.startSearch()
        store.advanceFromSearching()
        store.password = "  "
        store.continueFromWiFiDetails()

        #expect(store.route == .wifiDetails)
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
    }

    @Test
    func deviceOnboardingCancelConnectionIgnoresStaleCompletion() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.dashboard))
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(
            protocolClient: protocolClient,
            appVersion: "1.2.3",
            deviceName: "Road Camera"
        )
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        store.startSearch()
        store.advanceFromSearching()
        store.continueFromWiFiDetails()
        #expect(store.route == .connecting)

        store.cancelConnection()
        protocolClient.completeHandshakeSuccessfully(deviceID: "road-camera-001")
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(store.route == .wifiDetails)
        #expect(store.connectionStage == .idle)
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
    }

    @Test
    func deviceOnboardingSeparatesHotspotConnectionFromControlValidation() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.dashboard))
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        store.startSearch()
        store.advanceFromSearching()
        store.continueFromWiFiDetails()

        #expect(store.route == .connecting)
        #expect(store.connectionStage == .validatingControlChannel)
        #expect(session.state == .handshaking)
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
    }

    @Test
    func deviceOnboardingHandshakeFailureDoesNotPersistDevice() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.dashboard))
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        store.startSearch()
        store.advanceFromSearching()
        store.continueFromWiFiDetails()
        #expect(store.route == .connecting)

        protocolClient.failHandshake(.requestTimedOut(topic: "APP_ACCESS"))

        #expect(await waitForOnboardingState { store.route == .wifiDetails })
        #expect(store.connectionStage == .retryRequired("设备握手失败: 请求超时: APP_ACCESS"))
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
    }

    @Test
    func userDefaultsStorageRoundTrips() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let device = makeKnownDevice()
        let notificationPreferences = NotificationPreferences(
            emergencyEventNotifications: false,
            collisionAlerts: true,
            parkingIncidentAlerts: true,
            pushNotifications: false,
            soundForNotifications: false,
            quietHoursEnabled: true,
            quietHoursStart: "09:30 PM",
            quietHoursEnd: "07:00 AM"
        )

        repository.store([device])
        preferenceStore.hasCompletedOnboarding = true
        preferenceStore.shareAnonymousLogs = false
        preferenceStore.notificationPreferences = notificationPreferences

        #expect(repository.fetchKnownDevices() == [device])
        #expect(preferenceStore.hasCompletedOnboarding)
        #expect(preferenceStore.shareAnonymousLogs == false)
        #expect(preferenceStore.notificationPreferences == notificationPreferences)

        repository.clear()
        preferenceStore.reset()

        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
        #expect(preferenceStore.shareAnonymousLogs)
        #expect(preferenceStore.notificationPreferences == .defaultValue)
    }

    @Test
    func settingsStoreRoutesAndPersistsPreferences() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.show(.helpCenter)
        #expect(store.route == .helpCenter)

        store.show(.notificationSettings)
        #expect(store.route == .notificationSettings)

        store.dismissRoute()
        #expect(store.route == nil)

        store.setShareAnonymousLogs(false)
        store.setNotificationPreference(\.quietHoursEnabled, to: true)
        store.setNotificationPreference(\.parkingIncidentAlerts, to: true)

        let reloadedStore = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(reloadedStore.shareAnonymousLogs == false)
        #expect(reloadedStore.notificationPreferences.quietHoursEnabled)
        #expect(reloadedStore.notificationPreferences.parkingIncidentAlerts)
    }

    @Test
    func settingsStoreUpdatesDeviceConfigurationState() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.show(.recordingSettings)
        #expect(store.route == .recordingSettings)

        store.updateRecordingSetting(\.autoOverwrite, to: false)
        store.updateSafetySetting(\.parkingModeEnabled, to: false)
        store.updateNetworkIdentity(\.networkName, to: "RoadGuard_4K")
        store.commitNetworkIdentityChanges()
        store.setRenameDeviceDraft("RoadGuard Pro")
        store.renameDevice()
        store.startFirmwareUpdate()

        #expect(store.recordingSettings.autoOverwrite == false)
        #expect(store.safetySettings.parkingModeEnabled == false)
        #expect(store.devicePreferences.connectionName == "RoadGuard_4K")
        #expect(store.devicePreferences.deviceName == "RoadGuard Pro")
        #expect(store.route == nil)
        #expect(
            store.firmwareUpdateStage == .downloading(
                progress: 0.45,
                downloadedSize: "1.3 MB",
                remainingTime: "2 mins left"
            )
        )

        store.restoreSafetyDefaults()
        store.restoreDefaultDeviceConfiguration()

        #expect(store.safetySettings == .defaultValue)
        #expect(store.recordingSettings == .defaultValue)
        #expect(store.firmwareUpdateStage == .available)
    }

    @Test
    func settingsStoreRefreshSeedsDeviceAddedAfterInitialization() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        repository.store([
            makeKnownDevice(id: "cam360-added-device", name: "Vigilant DL-400 Pro")
        ])
        store.refresh()

        #expect(store.devicePreferences.deviceName == "Vigilant DL-400 Pro")
        #expect(store.devicePreferences.connectionName == "Cam360_AP_cam360-added-device")
        #expect(store.knownDeviceCount == 1)
    }

    @Test
    func settingsStoreRenamePersistsKnownDeviceName() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "Old Name"),
            makeKnownDevice(id: "cam360-rear", name: "Rear Camera")
        ])
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.setRenameDeviceDraft("RoadGuard Pro")
        store.renameDevice()

        let devices = repository.fetchKnownDevices()
        #expect(devices.first?.name == "RoadGuard Pro")
        #expect(devices.last?.name == "Rear Camera")

        let dashboardStore = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )
        #expect(dashboardStore.selectedDevice?.name == "RoadGuard Pro")
    }

    @Test
    func settingsStoreReadsReadyDeviceInfoFromDeviceSession() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        let session = DeviceSession()
        repository.store([
            makeKnownDevice(id: "road-camera-001", name: "Old Name")
        ])
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(
            DeviceInfo(
                id: "road-camera-001",
                name: "Road Camera",
                firmwareVersion: "v3.0.0",
                capabilities: [.download, .settings]
            )
        ))

        #expect(await waitForOnboardingState {
            store.devicePreferences.deviceName == "Road Camera"
        })
        #expect(store.devicePreferences.connectionName == "Cam360_AP_road-camera-001")
        #expect(store.devicePreferences.firmwareVersion == "v3.0.0")
        #expect(store.deviceCapabilities == [.download, .settings])
        #expect(store.deviceConnectionStatusTitle == "CONNECTED")
        #expect(store.deviceConnectionStatusTone == .success)

        session.send(.disconnect)

        #expect(await waitForOnboardingState {
            store.deviceConnectionStatusTitle == "OFFLINE"
        })
        #expect(store.deviceCapabilities.isEmpty)
    }

    @Test
    func galleryStoreKeepsDeletedItemsInSharedState() {
        let items = Array(GallerySampleMediaProvider().fetchItems().prefix(2))
        let store = GalleryStore(items: items)
        let deletedItem = items[0]

        store.showItemMenu(deletedItem)
        store.handleMenuDelete()

        #expect(store.items.contains(where: { $0.id == deletedItem.id }) == false)
        #expect(store.items.count == 1)
        #expect(store.activeMenuItem == nil)
    }

    @Test
    func settingsStoreResetShellReturnsToDashboard() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        repository.store([makeKnownDevice()])
        preferenceStore.hasCompletedOnboarding = true

        store.resetShell()

        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
        #expect(router.route == .main(.dashboard))
    }

    private func makeUserDefaults() -> TestDefaults {
        let suiteName = "Cam360Tests.\(UUID().uuidString)"
        return TestDefaults(
            suiteName: suiteName,
            userDefaults: UserDefaults(suiteName: suiteName)!
        )
    }

    private func clear(_ testDefaults: TestDefaults) {
        testDefaults.userDefaults.removePersistentDomain(forName: testDefaults.suiteName)
    }
}

private struct TestDashboardContentProvider: DashboardContentProviding {
    let placeholderDevices: [KnownDeviceSummary] = []
    let placeholderFeatureDeviceState = DashboardFeatureDeviceState(pairedDeviceName: "", connectionStatusText: "")

    func status(for device: KnownDeviceSummary, at index: Int) -> DashboardDeviceStatus {
        .offline
    }

    func scenario(forDeviceAt index: Int) -> DashboardDeviceScenario {
        DashboardDeviceScenario(
            startsRecording: true,
            previewState: DashboardPreviewState(statusTitle: "", resolutionTitle: "", timestampText: ""),
            storageState: .available(DashboardStorageSummary(usedCapacityText: "", totalCapacityText: "", usageFraction: 0)),
            events: []
        )
    }

    func connectionStatusText(for device: DashboardDeviceItem) -> String {
        ""
    }
}

func makeKnownDevice(
    id: String = "cam360-test-device",
    name: String = "Cam360 Test Device"
) -> KnownDeviceSummary {
    KnownDeviceSummary(
        id: id,
        name: name,
        hotspotSSID: "Cam360_AP_\(id)",
        lastConnectedAt: Date(timeIntervalSince1970: 1_713_139_200)
    )
}

func makeDeviceInfo() -> DeviceInfo {
    DeviceInfo(
        id: "cam360-device",
        name: "Cam360 Test Device",
        firmwareVersion: "v1.0.0",
        capabilities: [.livePreview, .settings]
    )
}

extension UserDefaults {
    static var ephemeral: UserDefaults {
        UserDefaults(suiteName: "Cam360Tests.\(UUID().uuidString)")!
    }
}

private struct TestDefaults {
    let suiteName: String
    let userDefaults: UserDefaults
}

@MainActor
private func waitForOnboardingState(
    timeout: TimeInterval = 1,
    condition: @escaping @MainActor () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    return condition()
}

private final class OnboardingFakeProtocolClient: DeviceSessionProtocolClient {
    var onDisconnect: ((DeviceProtocolError?) -> Void)?
    private var handshakeCompletion: ((Result<[DeviceProtocolMessage], DeviceProtocolError>) -> Void)?

    func connect(completion: @escaping (Result<Void, DeviceProtocolError>) -> Void) {
        completion(.success(()))
    }

    func startHandshake(
        appVersion: String,
        commandTimeout: TimeInterval,
        completion: @escaping (Result<[DeviceProtocolMessage], DeviceProtocolError>) -> Void
    ) {
        handshakeCompletion = completion
    }

    func send(
        _ command: DeviceProtocolCommand,
        completion: @escaping (Result<DeviceProtocolMessage, DeviceProtocolError>) -> Void
    ) {
        completion(.failure(.transportDisconnected))
    }

    func disconnect() {}

    func completeHandshakeSuccessfully(deviceID: String) {
        handshakeCompletion?(.success(makeOnboardingHandshakeResponses(deviceID: deviceID)))
    }

    func failHandshake(_ error: DeviceProtocolError) {
        handshakeCompletion?(.failure(error))
    }

    private func makeOnboardingHandshakeResponses(deviceID: String) -> [DeviceProtocolMessage] {
        [
            DeviceProtocolMessage(
                topic: "UUID",
                operation: .notify,
                messageID: "dev-uuid",
                notifyType: .response,
                replyTo: "ios-uuid",
                errno: 0,
                parameters: ["uuid": .string(deviceID)]
            )
        ]
    }
}
