import Testing
import Foundation
@testable import Cam360

private let validCam360TestSnapshotBase64 = "CQoLDA=="

@MainActor
struct Cam360Tests {
    @Test
    func bootstrapWithoutKnownDevicesShowsHome() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.initialSelectedTab == .home)
    }

    @Test
    func bootstrapAfterOnboardingShowsMain() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        preferenceStore.hasCompletedOnboarding = true

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.initialSelectedTab == .home)
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
    func bootstrapReadsDeviceProtocolEndpointFromSimulatorReadyFile() {
        let readyFileData = Data(
            """
            {
              "ready": true,
              "host": "127.0.0.1",
              "port": 8765,
              "mode": "strict",
              "control_host": "127.0.0.1",
              "control_port": 18765
            }
            """.utf8
        )
        var requestedPath: String?

        let endpoint = AppBootstrap.deviceProtocolEndpoint(
            from: ["Cam360Tests", "-device-protocol-ready-file", "/tmp/device-ready.json"],
            readReadyFileData: { url in
                requestedPath = url.path
                return readyFileData
            }
        )

        #expect(requestedPath == "/tmp/device-ready.json")
        #expect(endpoint == DeviceProtocolEndpoint(
            host: "127.0.0.1",
            port: 8765,
            simulatorControlEndpoint: SimulatorControlEndpoint(host: "127.0.0.1", port: 18765)
        ))
    }

    @Test
    func bootstrapReadsMockPreviewAssetFromSimulatorReadyFile() {
        let readyFileData = Data(
            """
            {
              "ready": true,
              "host": "127.0.0.1",
              "port": 8765,
              "asset_host": "127.0.0.1",
              "asset_port": 18080,
              "asset": {
                "preview": {
                  "base_url": "http://127.0.0.1:18080",
                  "mjpeg_url": "http://127.0.0.1:18080/preview/live.mjpg",
                  "hls_url": "http://127.0.0.1:18080/preview/index.m3u8",
                  "mp4_url": "http://127.0.0.1:18080/preview/live.mp4"
                }
              }
            }
            """.utf8
        )

        let endpoint = AppBootstrap.deviceProtocolEndpoint(
            from: ["Cam360Tests", "-device-protocol-ready-file", "/tmp/device-ready.json"],
            readReadyFileData: { _ in readyFileData }
        )

        #expect(endpoint?.mockPreviewAsset == MockPreviewAsset(
            baseURL: "http://127.0.0.1:18080",
            mjpegURL: "http://127.0.0.1:18080/preview/live.mjpg",
            hlsURL: "http://127.0.0.1:18080/preview/index.m3u8",
            mp4URL: "http://127.0.0.1:18080/preview/live.mp4"
        ))
        #expect(endpoint?.simulatorAssetEndpoint == SimulatorAssetEndpoint(host: "127.0.0.1", port: 18080))
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
            store.queueState == .unavailable(message: "需要设备侧 DOWNLOAD_PROGRESS 或下载任务服务后才能读取队列。")
        })
        #expect(store.canRefreshQueue)
        #expect(store.title == "下载队列不可用")
        #expect(store.message == "当前只接收设备侧 DOWNLOAD_PROGRESS；开始、暂停和保存位置仍待下载服务接入。")
    }

    @Test
    func downloadsStoreConsumesDownloadProgressEventsFromSession() async {
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DownloadsStore(deviceSession: session)

        protocolClient.pushEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "transfer-task-0001",
                "type": "transfer",
                "path": "/DCIMA/REC00001.AVI",
                "progress": 75,
                "speed": 2_048_000,
                "status": "processing"
            ]
        )

        #expect(await waitForOnboardingState { store.statusTitle == "75%" })
        #expect(store.title == "正在下载")
        #expect(store.queueMessage == "/DCIMA/REC00001.AVI 正在传输，进度 75%，速度 2.0 MB/s。")
        #expect(store.canStartDownload == false)
        #expect(store.canPauseQueue == false)

        if case .transferring(let progress) = store.queueState {
            #expect(progress.progressFraction == 0.75)
            #expect(progress.progressText == "75%")
            #expect(progress.speedText == "2.0 MB/s")
        } else {
            Issue.record("DOWNLOAD_PROGRESS 应进入 transferring 状态")
        }
    }

    @Test
    func downloadsStoreUsesLatestDownloadProgressEventAcrossTasks() async {
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DownloadsStore(deviceSession: session)

        protocolClient.pushEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "transfer-task-9999",
                "type": "transfer",
                "path": "/DCIMA/REC09999.AVI",
                "progress": 10,
                "speed": 512_000,
                "status": "processing"
            ]
        )

        #expect(await waitForOnboardingState {
            store.queueMessage == "/DCIMA/REC09999.AVI 正在传输，进度 10%，速度 500 KB/s。"
        })

        protocolClient.pushEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "transfer-task-0001",
                "type": "transfer",
                "path": "/DCIMA/REC00001.AVI",
                "progress": 20,
                "speed": 0,
                "status": "failed"
            ]
        )

        #expect(await waitForOnboardingState {
            store.statusTitle == "失败"
                && store.queueMessage == "/DCIMA/REC00001.AVI 传输失败。"
        })
        #expect(store.title == "下载失败")
        #expect(store.message == "设备传输失败，开始、继续和取消仍待下载服务接入。")
    }

    @Test
    func downloadsStoreKeepsCompletedDownloadProgressItems() async {
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = DownloadsStore(deviceSession: session)

        protocolClient.pushEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "transfer-task-0001",
                "type": "transfer",
                "path": "/DCIMA/REC00001.AVI",
                "progress": 100,
                "speed": 0,
                "status": "completed"
            ]
        )

        #expect(await waitForOnboardingState {
            store.completedTransfers.map(\.taskID) == ["transfer-task-0001"]
        })
        #expect(store.title == "下载完成")
        #expect(store.message == "设备传输完成，本地保存仍等待下载服务接入。")
        #expect(store.completedTransfers.first?.path == "/DCIMA/REC00001.AVI")
    }

    @Test
    func localVideosStoreStartsWithLocalEmptyState() {
        let store = LocalVideosStore()

        #expect(store.items.isEmpty)
        #expect(store.screenshots.isEmpty)
        #expect(store.title == "暂无本地资源")
        #expect(store.message == "本地保存路径接入前，不展示伪造的视频或截图记录。")
        #expect(store.usedStorageText == "0 MB")
        #expect(store.canOpenItem == false)
        #expect(store.canShareItem == false)
        #expect(store.canDeleteItem == false)
        #expect(store.canDeleteScreenshot == false)
    }

    @Test
    func localVideosStoreLoadsConfirmedLocalCatalogItems() {
        let store = LocalVideosStore(catalog: StaticLocalVideoCatalog(items: [
            LocalVideoItem(
                id: "local-video-1",
                title: "Front Camera Clip",
                fileSizeBytes: 104_857_600,
                durationSeconds: 125,
                localPath: "/Documents/Cam360/FrontCameraClip.mp4"
            ),
            LocalVideoItem(
                id: "local-video-2",
                title: "Parking Incident",
                fileSizeBytes: 52_428_800,
                durationSeconds: 45,
                localPath: "/Documents/Cam360/ParkingIncident.mp4"
            )
        ]))

        store.reload()

        #expect(store.items.map(\.title) == ["Front Camera Clip", "Parking Incident"])
        #expect(store.title == "本地视频")
        #expect(store.message == "本地视频来自已确认的 App 保存记录。")
        #expect(store.usedStorageBytes == 157_286_400)
        #expect(store.canOpenItem)
        #expect(store.canShareItem)
        #expect(store.canDeleteItem)
    }

    @Test
    func localVideoCatalogPersistsConfirmedLocalItems() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }
        let catalog = UserDefaultsLocalVideoCatalog(userDefaults: testDefaults.userDefaults)
        let item = LocalVideoItem(
            id: "local-video-1",
            title: "Front Camera Clip",
            fileSizeBytes: 104_857_600,
            durationSeconds: 125,
            localPath: "/Documents/Cam360/FrontCameraClip.mp4"
        )

        catalog.store(item)

        #expect(UserDefaultsLocalVideoCatalog(userDefaults: testDefaults.userDefaults).loadItems() == [item])
    }

    @Test
    func localVideosStorePreparesConfirmedItemForSystemShare() {
        let store = LocalVideosStore(catalog: StaticLocalVideoCatalog(items: [
            LocalVideoItem(
                id: "local-video-1",
                title: "Front Camera Clip",
                fileSizeBytes: 104_857_600,
                durationSeconds: 125,
                localPath: "/Documents/Cam360/FrontCameraClip.mp4"
            )
        ]))

        store.reload()
        store.requestShare(itemID: "local-video-1")

        #expect(store.pendingShare?.id == "local-video-1")
        #expect(store.pendingShareURL == URL(fileURLWithPath: "/Documents/Cam360/FrontCameraClip.mp4"))

        store.cancelPendingShare()

        #expect(store.pendingShare == nil)
        #expect(store.pendingShareURL == nil)
    }

    @Test
    func localVideosStoreDeletesConfirmedItemAfterConfirmation() {
        let catalog = InMemoryLocalVideoCatalog(items: [
            LocalVideoItem(
                id: "local-video-1",
                title: "Front Camera Clip",
                fileSizeBytes: 104_857_600,
                durationSeconds: 125,
                localPath: "/Documents/Cam360/FrontCameraClip.mp4"
            )
        ])
        let store = LocalVideosStore(catalog: catalog)

        store.reload()
        store.requestDelete(itemID: "local-video-1")

        #expect(store.pendingDeletion?.id == "local-video-1")
        #expect(store.deleteConfirmationTitle == "删除本地视频？")

        store.confirmPendingDeletion()

        #expect(store.items.isEmpty)
        #expect(store.pendingDeletion == nil)
        #expect(catalog.loadItems().isEmpty)
    }

    @Test
    func localVideosStoreLoadsAndDeletesConfirmedLocalScreenshots() {
        let catalog = InMemoryLocalVideoCatalog(
            items: [],
            screenshots: [
                LocalScreenshotItem(
                    id: "local-screenshot-1",
                    title: "Preview Snapshot",
                    fileSizeBytes: 1_048_576,
                    localPath: "/Documents/Cam360/PreviewSnapshot.jpg"
                )
            ]
        )
        let store = LocalVideosStore(catalog: catalog)

        store.reload()

        #expect(store.screenshots.map(\.title) == ["Preview Snapshot"])
        #expect(store.title == "本地资源")
        #expect(store.message == "本地视频和截图来自已确认的 App 保存记录。")
        #expect(store.usedStorageBytes == 1_048_576)
        #expect(store.canDeleteScreenshot)

        store.requestDeleteScreenshot(itemID: "local-screenshot-1")

        #expect(store.pendingScreenshotDeletion?.id == "local-screenshot-1")
        #expect(store.deleteScreenshotConfirmationTitle == "删除本地截图？")

        store.confirmPendingScreenshotDeletion()

        #expect(store.screenshots.isEmpty)
        #expect(store.pendingScreenshotDeletion == nil)
        #expect(catalog.loadScreenshots().isEmpty)
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
            store.previewState == .unavailable(reason: "真实视频流和播放器尚未接入；截图数据仅在控制通道 ready 后可获取。")
        })
        #expect(store.canRefreshPreview)
        #expect(store.title == "实时预览暂不可用")
    }

    @Test
    func livePreviewStoreUsesMockPreviewAssetWithoutEnablingRealControls() async {
        let store = LivePreviewStore(mockPreviewAsset: MockPreviewAsset(
            mjpegURL: "http://127.0.0.1:18080/preview/live.mjpg",
            hlsURL: "http://127.0.0.1:18080/preview/index.m3u8",
            mp4URL: "http://127.0.0.1:18080/preview/live.mp4"
        ))

        store.refreshPreviewStatus()

        #expect(store.previewState == .checking)
        #expect(await waitForOnboardingState {
            store.previewState == .mockAssetReady(url: "http://127.0.0.1:18080/preview/index.m3u8")
        })
        #expect(store.statusTitle == "Mock 可用")
        #expect(store.placeholderTitle == "Mock 预览占位")
        #expect(store.message == "已读取本地模拟器 Mock 预览资源，仅用于占位联调；真实预览流协议仍未定义。")
        #expect(store.canCaptureSnapshot == false)
        #expect(store.canToggleRecording == false)
        #expect(store.canEnterFullscreen == false)
    }

    @Test
    func livePreviewStorePreparesMockPreviewSourceOnceOnEntry() async {
        let store = LivePreviewStore(mockPreviewAsset: MockPreviewAsset(
            mjpegURL: "http://127.0.0.1:18080/preview/live.mjpg",
            hlsURL: "http://127.0.0.1:18080/preview/index.m3u8",
            mp4URL: "http://127.0.0.1:18080/preview/live.mp4"
        ))

        store.preparePreviewIfNeeded()

        #expect(store.previewState == .checking)
        #expect(await waitForOnboardingState {
            store.previewState == .mockAssetReady(url: "http://127.0.0.1:18080/preview/index.m3u8")
        })

        store.preparePreviewIfNeeded()

        #expect(store.previewState == .mockAssetReady(url: "http://127.0.0.1:18080/preview/index.m3u8"))
    }

    @Test
    func livePreviewStoreCapturesSnapshotThroughReadySession() async {
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        let store = LivePreviewStore(deviceSession: session)

        protocolClient.responseProvider = { command in
            switch command.topic {
            case "SNAPSHOT_CTRL":
                return DeviceProtocolMessage(
                    topic: "SNAPSHOT_CTRL",
                    operation: .notify,
                    messageID: "dev-snapshot-ctrl",
                    notifyType: .response,
                    replyTo: "ios-snapshot-ctrl",
                    errno: 0,
                    parameters: [
                        "snapshot_id": .string("snap-1"),
                        "status": .string("ok")
                    ]
                )
            case "SNAPSHOT_DATA":
                return DeviceProtocolMessage(
                    topic: "SNAPSHOT_DATA",
                    operation: .notify,
                    messageID: "dev-snapshot-data",
                    notifyType: .response,
                    replyTo: "ios-snapshot-data",
                    errno: 0,
                    parameters: [
                        "snapshot_id": .string("snap-1"),
                        "format": .string("JPEG"),
                        "width": .int(1280),
                        "height": .int(720),
                        "size": .int(4),
                        "image_base64": .string(validCam360TestSnapshotBase64)
                    ]
                )
            default:
                return nil
            }
        }

        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.startProtocolHandshake()
        protocolClient.completeHandshakeSuccessfully(deviceID: "cam360-device")

        #expect(await waitForOnboardingState { store.canCaptureSnapshot })

        store.captureSnapshot()

        #expect(store.snapshotState == .capturing)
        #expect(await waitForOnboardingState {
            store.snapshotState == .captured(snapshotID: "snap-1", detail: "1280x720 JPEG")
        })
        #expect(store.snapshotStatusTitle == "截图已获取")
        #expect(store.snapshotStatusMessage == "已通过控制通道获取截图数据，可在本页预览；尚未保存到本地相册。")
        #expect(store.snapshotImageBase64 == validCam360TestSnapshotBase64)
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
            store.feedState == .unavailable(message: "事件列表需要控制通道 ready 后读取 MEDIA_INDEX(event_only=1)，离线占位不读取真实设备文件。")
        })
        #expect(store.canRefreshEvents)
        #expect(store.emptyTitle == "事件索引不可用")
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
    func deviceSessionRecoveryRequiresFreshHandshake() {
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

        #expect(session.state == .handshaking)
    }

    @Test
    func recordingStoreShowsFeatureSheetUntilDismissed() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let store = RecordingStore(
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
    func recordingStoreExposesDeviceHubStates() {
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

        let store = RecordingStore(
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
    func recordingStoreUsesInjectedContentProvider() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-real-source", name: "Road Camera")
        ])

        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            contentProvider: TestRecordingContentProvider()
        )

        #expect(store.selectedDevice?.status == .disconnected)
        #expect(store.isRecording)
    }

    @Test
    func recordingStoreDerivesKnownDeviceStatusFromDeviceSession() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let session = DeviceSession()
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro"),
            makeKnownDevice(id: "cam360-rear", name: "Rear View")
        ])
        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            contentProvider: TestRecordingContentProvider(),
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
    func recordingStoreConsumesSessionStatusEventsForSelectedDevice() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro")
        ])
        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            contentProvider: TestRecordingContentProvider(),
            deviceSession: session
        )

        #expect(store.isRecording)
        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(
            DeviceInfo(
                id: "cam360-main",
                name: "DriveCam X Pro",
                firmwareVersion: "v1.2.0",
                capabilities: [.settings]
            )
        ))

        protocolClient.pushEvent(topic: "VIDEO_CTRL", parameters: ["status": 0])
        protocolClient.pushEvent(topic: "SD_STATUS", parameters: ["online": 0])

        #expect(await waitForOnboardingState { store.isRecording == false })
        if case let .unavailable(title, _) = store.storageState {
            #expect(title == "No SD card detected")
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func recordingStoreUsesSessionStorageCapacityForSelectedDevice() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let protocolClient = OnboardingFakeProtocolClient()
        protocolClient.responseProvider = { command in
            guard command.topic == "TF_CAP" else {
                return nil
            }

            return DeviceProtocolMessage(
                topic: "TF_CAP",
                operation: .notify,
                messageID: "dev-tf-cap",
                notifyType: .response,
                replyTo: "ios-tf-cap",
                errno: 0,
                parameters: [
                    "left": 4_000,
                    "total": 22_222
                ]
            )
        }
        let session = DeviceSession(protocolClient: protocolClient)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro")
        ])
        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            contentProvider: TestRecordingContentProvider(),
            deviceSession: session
        )

        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(
            DeviceInfo(
                id: "cam360-main",
                name: "DriveCam X Pro",
                firmwareVersion: "v1.2.0",
                capabilities: [.settings]
            )
        ))

        session.fetchStorageCapacity { _ in }

        #expect(await waitForOnboardingState {
            if case let .available(summary) = store.storageState {
                return summary.usedCapacityText == "17.8 GB"
                    && summary.totalCapacityText == "21.7 GB"
                    && summary.usageText == "82% USED"
            }
            return false
        })
    }

    @Test
    func deviceOnboardingStoreHappyPathPersistsDeviceAndReturnsHome() async {
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
        #expect(store.firmwareUpdateStage == .unavailable(message: "升级候选版本服务尚未接入，无法发起设备固件升级。"))

        store.restoreSafetyDefaults()
        store.restoreDefaultDeviceConfiguration()

        #expect(store.safetySettings == .defaultValue)
        #expect(store.recordingSettings == .defaultValue)
        #expect(store.firmwareUpdateStage == .unavailable(message: "升级候选版本服务尚未接入，无法发起设备固件升级。"))
    }

    @Test
    func settingsStoreConsumesFirmwareUpgradeProgressEventsFromSession() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        repository.store([
            makeKnownDevice(id: "road-camera-001", name: "Road Camera")
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
                capabilities: [.settings]
            )
        ))

        protocolClient.pushEvent(
            topic: "UPGRADE_PROGRESS",
            parameters: [
                "task_id": "upgrade-task-0001",
                "type": "upgrade",
                "progress": 60,
                "stage": "installing",
                "status": "processing"
            ]
        )

        #expect(await waitForOnboardingState {
            store.firmwareUpdateStage == .inProgress(progress: 0.6, stageTitle: "Installing firmware")
        })

        protocolClient.pushEvent(
            topic: "UPGRADE_PROGRESS",
            parameters: [
                "task_id": "upgrade-task-0001",
                "type": "upgrade",
                "progress": 85,
                "stage": "restarting",
                "status": "processing"
            ]
        )

        #expect(await waitForOnboardingState {
            store.firmwareUpdateStage == .inProgress(progress: 0.85, stageTitle: "Restarting device")
        })

        protocolClient.pushEvent(
            topic: "UPGRADE_PROGRESS",
            parameters: [
                "task_id": "upgrade-task-0001",
                "type": "upgrade",
                "progress": 100,
                "stage": "restarting",
                "status": "completed"
            ]
        )

        #expect(await waitForOnboardingState {
            store.firmwareUpdateStage == .completed
        })
    }

    @Test
    func settingsStoreConsumesFormatProgressEventsFromSession() async {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let protocolClient = OnboardingFakeProtocolClient()
        let session = DeviceSession(protocolClient: protocolClient)
        repository.store([
            makeKnownDevice(id: "road-camera-001", name: "Road Camera")
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
                capabilities: [.settings]
            )
        ))

        protocolClient.pushEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "format-task-0001",
                "type": "format",
                "progress": 45,
                "status": "processing"
            ]
        )

        #expect(await waitForOnboardingState {
            store.storagePolicy.formatStage == .inProgress(progress: 0.45)
        })

        protocolClient.pushEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "format-task-0001",
                "type": "format",
                "progress": 100,
                "status": "completed"
            ]
        )

        #expect(await waitForOnboardingState {
            store.storagePolicy.formatStage == .completed
                && store.storagePolicy.cardStatus == .ready
                && store.storagePolicy.usedSpaceGB == 0
        })

        protocolClient.pushEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "format-task-0002",
                "type": "format",
                "progress": 20,
                "status": "failed"
            ],
            errno: -7
        )

        #expect(await waitForOnboardingState {
            store.storagePolicy.formatStage == .failed
                && store.storagePolicy.cardStatus == .error
        })
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

        let recordingStore = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )
        #expect(recordingStore.selectedDevice?.name == "RoadGuard Pro")
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
    func settingsStoreResetShellClearsRoute() {
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

private struct TestRecordingContentProvider: RecordingContentProviding {
    let placeholderDevices: [KnownDeviceSummary] = []
    let placeholderFeatureDeviceState = RecordingFeatureDeviceState(pairedDeviceName: "", connectionStatusText: "")

    func scenario(forDeviceAt index: Int) -> RecordingDeviceScenario {
        RecordingDeviceScenario(
            startsRecording: true,
            previewState: RecordingPreviewState(statusTitle: "", resolutionTitle: "", timestampText: ""),
            storageState: .available(RecordingStorageSummary(usedCapacityText: "", totalCapacityText: "", usageFraction: 0)),
            events: []
        )
    }

    func connectionStatusText(for device: RecordingDeviceItem) -> String {
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

final class InMemoryLocalVideoCatalog: LocalVideoCatalog {
    private var items: [LocalVideoItem]
    private var screenshots: [LocalScreenshotItem]

    init(
        items: [LocalVideoItem],
        screenshots: [LocalScreenshotItem] = []
    ) {
        self.items = items
        self.screenshots = screenshots
    }

    func loadItems() -> [LocalVideoItem] {
        items
    }

    func loadScreenshots() -> [LocalScreenshotItem] {
        screenshots
    }

    func store(_ item: LocalVideoItem) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
    }

    func storeScreenshot(_ item: LocalScreenshotItem) {
        screenshots.removeAll { $0.id == item.id }
        screenshots.insert(item, at: 0)
    }

    func deleteItem(id: String) {
        items.removeAll { $0.id == id }
    }

    func deleteScreenshot(id: String) {
        screenshots.removeAll { $0.id == id }
    }

    func clear() {
        items.removeAll()
        screenshots.removeAll()
    }
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
    var onEvent: ((DeviceProtocolMessage) -> Void)?
    var onDisconnect: ((DeviceProtocolError?) -> Void)?
    var responseProvider: ((DeviceProtocolCommand) -> DeviceProtocolMessage?)?
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
        if let response = responseProvider?(command) {
            completion(.success(response))
            return
        }

        completion(.failure(.transportDisconnected))
    }

    func disconnect() {}

    func completeHandshakeSuccessfully(deviceID: String) {
        handshakeCompletion?(.success(makeOnboardingHandshakeResponses(deviceID: deviceID)))
    }

    func failHandshake(_ error: DeviceProtocolError) {
        handshakeCompletion?(.failure(error))
    }

    func pushEvent(topic: String, parameters: [String: DeviceProtocolValue], errno: Int = 0) {
        onEvent?(
            DeviceProtocolMessage(
                topic: topic,
                operation: .notify,
                messageID: "evt-\(topic.lowercased())",
                notifyType: .event,
                errno: errno,
                parameters: parameters
            )
        )
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
            ),
            DeviceProtocolMessage(
                topic: "CAMERA_CAPABILITY",
                operation: .notify,
                messageID: "dev-camera-capability",
                notifyType: .response,
                replyTo: "ios-camera-capability",
                errno: 0,
                parameters: [
                    "capabilities": .object([
                        "protocol": .object([
                            "inline_media_base64": true
                        ]),
                        "video": .object([
                            "supported": true
                        ]),
                        "image": .object([
                            "snapshot_transport": ["base64"]
                        ])
                    ])
                ]
            )
        ]
    }
}
