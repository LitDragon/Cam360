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

        #expect(bootstrap.initialSelectedTab == .dashboard)
    }

    @Test
    func bootstrapAfterOnboardingShowsMain() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        preferenceStore.hasCompletedOnboarding = true

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.initialSelectedTab == .dashboard)
    }

    @Test
    func bootstrapRespectsSelectedTabOverride() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let bootstrap = AppBootstrap.launch(
            arguments: ["Cam360Tests", "-uitest-selected-tab", "gallery"],
            userDefaults: testDefaults.userDefaults
        )

        #expect(bootstrap.initialSelectedTab == .gallery)
    }

    @Test
    func downloadsStoreStartsWithOfflineEmptyState() {
        let store = DownloadsStore()

        #expect(store.queueState == .empty)
        #expect(store.canRefreshQueue)
        #expect(store.canStartDownload == false)
        #expect(store.canPauseQueue == false)
        #expect(store.title == "没有下载任务")
        #expect(store.message == "当前没有进行中或已完成的下载。")
    }

    @Test
    func downloadsStoreRefreshShowsLoadingThenOfflineError() async {
        let store = DownloadsStore()

        store.refreshQueue()

        #expect(store.queueState == .loading)
        #expect(store.canRefreshQueue == false)
        #expect(store.title == "正在读取下载队列")

        #expect(await waitForOnboardingState {
            store.queueState == .unavailable(message: "下载服务尚未接入，无法读取真实下载队列。")
        })
        #expect(store.canRefreshQueue)
        #expect(store.title == "下载链路未接入")
        #expect(store.message == "请先从设备文件选择下载项；真实下载任务会在设备和本地保存链路恢复后接入。")
    }

    @Test
    func livePreviewStoreRefreshShowsCheckingThenOfflineUnavailable() async {
        let store = LivePreviewStore()

        #expect(store.previewState == .unavailable(reason: "当前没有可显示的视频流。"))
        #expect(store.canRefreshPreview)
        #expect(store.canCaptureSnapshot == false)
        #expect(store.canToggleRecording == false)
        #expect(store.canEnterFullscreen == false)

        store.refreshPreviewStatus()

        #expect(store.previewState == .checking)
        #expect(store.canRefreshPreview == false)
        #expect(store.title == "正在检查预览状态")

        #expect(await waitForOnboardingState {
            store.previewState == .unavailable(reason: "真实视频流和播放器尚未接入，当前只能展示离线预览占位。")
        })
        #expect(store.canRefreshPreview)
        #expect(store.title == "实时预览暂不可用")
    }

    @Test
    func eventsStoreFiltersCategoriesAndRefreshesToOfflineUnavailable() async {
        let store = EventsStore()

        #expect(store.feedState == .empty)
        #expect(store.visibleCategories.count == 3)

        store.selectedFilter = .parking
        #expect(store.visibleCategories.map(\.id) == [.parking])

        store.refreshEvents()

        #expect(store.feedState == .refreshing)
        #expect(store.canRefreshEvents == false)
        #expect(store.statusTitle == "刷新中")

        #expect(await waitForOnboardingState {
            store.feedState == .unavailable(message: "事件推送和历史事件读取尚未接入，无法读取真实事件列表。")
        })
        #expect(store.canRefreshEvents)
        #expect(store.emptyTitle == "事件列表未接入")
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
        #expect(store.devices.map(\.status) == [
            .disconnected,
            .disconnected,
            .disconnected,
            .disconnected
        ])
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

        #expect(store.selectedDevice?.status == .disconnected)
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

        store.selectDevice(id: "cam360-rear")
        #expect(store.devices.first(where: { $0.id == "cam360-rear" })?.status == .disconnected)

        session.send(.startAPConnection(ssid: "Cam360_AP"))

        #expect(await waitForOnboardingState {
            store.devices.first(where: { $0.id == "cam360-rear" })?.status == .connecting
        })

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
            store.devices.first(where: { $0.id == "cam360-rear" })?.status == .disconnected
        })
    }

    @Test
    func deviceOnboardingStoreHappyPathPersistsDeviceAndReturnsToDashboard() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(
            protocolClient: protocolClient,
            appVersion: "1.2.3",
            deviceName: "Road Camera"
        )
        let store = DeviceOnboardingStore(
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
        #expect(store.route == .introduction)
    }

    @Test
    func deviceOnboardingRequiresPasswordBeforeConnecting() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let store = DeviceOnboardingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: DeviceSession()
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
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(
            protocolClient: protocolClient,
            appVersion: "1.2.3",
            deviceName: "Road Camera"
        )
        let store = DeviceOnboardingStore(
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
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DeviceOnboardingStore(
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
    func deviceOnboardingConnectionFailuresExposeRecoveryActions() {
        #expect(
            DeviceOnboardingConnectionStage.retry(for: .apConnectionFailed(reason: "Wrong password")) ==
                .retryRequired(
                    message: "热点连接失败: Wrong password",
                    action: .retryHotspot
                )
        )
        #expect(
            DeviceOnboardingConnectionStage.retry(for: .handshakeFailed(reason: "请求超时: APP_ACCESS")) ==
                .retryRequired(
                    message: "设备握手失败: 请求超时: APP_ACCESS",
                    action: .checkLocalNetworkPermission
                )
        )
        #expect(
            DeviceOnboardingConnectionStage.retry(for: .connectionLost) ==
                .retryRequired(
                    message: "连接已断开",
                    action: .retryControlChannel
                )
        )
        #expect(
            DeviceOnboardingRecoveryAction.retryHotspot.guidance ==
                "Open iOS Settings > Wi-Fi, join the dashcam hotspot with the shown password, then return to Cam360 and try again."
        )
        #expect(
            DeviceOnboardingRecoveryAction.checkLocalNetworkPermission.guidance ==
                "Open iOS Settings > Cam360 and allow Local Network access, then retry validation."
        )
    }

    @Test
    func deviceOnboardingManualSetupGuidanceKeepsWiFiAndControlValidationSeparate() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let store = DeviceOnboardingStore(
            knownDeviceRepository: UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults),
            appPreferenceStore: UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults),
            deviceSession: DeviceSession()
        )
        store.networkName = "RoadCam_AP"

        #expect(
            store.manualHotspotSetupMessage ==
                "Open iOS Settings > Wi-Fi and join RoadCam_AP, then return to Cam360."
        )
        #expect(
            store.localNetworkPermissionMessage ==
                "If iOS asks for Local Network access, allow it before device validation."
        )
        #expect(
            DeviceOnboardingConnectionStage.validatingControlChannel.title(deviceName: "Road Camera") ==
                "Validating device control"
        )
        #expect(
            DeviceOnboardingConnectionStage.validatingControlChannel.message ==
                "The phone should already be on the dashcam hotspot. Cam360 is now checking the control channel."
        )
    }

    @Test
    func deviceOnboardingHandshakeFailureDoesNotPersistDevice() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DeviceOnboardingStore(
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
        #expect(
            store.connectionStage == .retryRequired(
                message: "设备握手失败: 请求超时: APP_ACCESS",
                action: .checkLocalNetworkPermission
            )
        )
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
    func knownDeviceRepositoryPreservesStoredDevicesWhenEncodingFails() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let existingDevice = makeKnownDevice(id: "existing-device")
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        repository.store([existingDevice])

        let failingRepository = UserDefaultsKnownDeviceRepository(
            userDefaults: testDefaults.userDefaults,
            encodeDevices: { _ in throw TestEncodingError.forced }
        )

        failingRepository.store([makeKnownDevice(id: "replacement-device")])

        #expect(repository.fetchKnownDevices() == [existingDevice])
    }

    @Test
    func appPreferenceStorePreservesNotificationPreferencesWhenEncodingFails() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let existingPreferences = NotificationPreferences(
            emergencyEventNotifications: false,
            collisionAlerts: true,
            parkingIncidentAlerts: true,
            pushNotifications: false,
            soundForNotifications: false,
            quietHoursEnabled: true,
            quietHoursStart: "09:30 PM",
            quietHoursEnd: "07:00 AM"
        )
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        preferenceStore.notificationPreferences = existingPreferences

        let failingPreferenceStore = UserDefaultsAppPreferenceStore(
            userDefaults: testDefaults.userDefaults,
            encodeNotificationPreferences: { _ in throw TestEncodingError.forced }
        )

        failingPreferenceStore.notificationPreferences = .defaultValue

        #expect(preferenceStore.notificationPreferences == existingPreferences)
    }

    @Test
    func settingsStoreRoutesAndPersistsPreferences() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let store = SettingsStore(
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
        let store = SettingsStore(
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
        let store = SettingsStore(
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
    func settingsStoreRefreshKeepsSelectedKnownDevice() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "Front Camera"),
            makeKnownDevice(id: "cam360-rear", name: "Rear Camera")
        ])
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.prepareDeviceSettings(for: "cam360-rear")
        store.refresh()

        #expect(store.devicePreferences.deviceName == "Rear Camera")
        #expect(store.devicePreferences.connectionName == "Cam360_AP_cam360-rear")
        #expect(store.knownDeviceCount == 2)
    }

    @Test
    func settingsStoreShowsKnownDeviceAsConnectedWhenSessionIsIdle() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro")
        ])
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: DeviceSession()
        )

        #expect(store.deviceConnectionStatusTitle == "CONNECTED")
        #expect(store.deviceConnectionStatusText == "Connected and ready to record")
        #expect(store.deviceConnectionStatusTone == .success)
    }

    @Test
    func settingsStoreRenamePersistsKnownDeviceName() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "Old Name"),
            makeKnownDevice(id: "cam360-rear", name: "Rear Camera")
        ])
        let store = SettingsStore(
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
        let session = DeviceSession()
        repository.store([
            makeKnownDevice(id: "road-camera-001", name: "Old Name")
        ])
        let store = SettingsStore(
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
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        repository.store([makeKnownDevice()])
        preferenceStore.hasCompletedOnboarding = true

        store.resetShell()

        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
        #expect(store.route == nil)
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

private enum TestEncodingError: Error {
    case forced
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
