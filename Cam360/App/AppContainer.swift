import Foundation

struct MockPreviewAsset: Equatable {
    let baseURL: String?
    let mjpegURL: String?
    let hlsURL: String?
    let mp4URL: String?

    init(baseURL: String? = nil, mjpegURL: String?, hlsURL: String?, mp4URL: String?) {
        self.baseURL = baseURL
        self.mjpegURL = mjpegURL
        self.hlsURL = hlsURL
        self.mp4URL = mp4URL
    }

    var preferredURL: String? {
        hlsURL ?? mp4URL ?? mjpegURL
    }
}

struct SimulatorControlEndpoint: Equatable {
    let host: String
    let port: UInt16
}

struct SimulatorAssetEndpoint: Equatable {
    let host: String
    let port: UInt16
}

struct DeviceProtocolEndpoint: Equatable {
    let host: String
    let port: UInt16
    let mockPreviewAsset: MockPreviewAsset?
    let simulatorControlEndpoint: SimulatorControlEndpoint?
    let simulatorAssetEndpoint: SimulatorAssetEndpoint?

    init(
        host: String,
        port: UInt16 = 8765,
        mockPreviewAsset: MockPreviewAsset? = nil,
        simulatorControlEndpoint: SimulatorControlEndpoint? = nil,
        simulatorAssetEndpoint: SimulatorAssetEndpoint? = nil
    ) {
        self.host = host
        self.port = port
        self.mockPreviewAsset = mockPreviewAsset
        self.simulatorControlEndpoint = simulatorControlEndpoint
        self.simulatorAssetEndpoint = simulatorAssetEndpoint
    }
}

final class AppContainer {
    typealias DeviceProtocolEndpointProvider = () -> DeviceProtocolEndpoint?

    let knownDeviceRepository: KnownDeviceRepository
    let appPreferenceStore: AppPreferenceStore
    let deviceSession: DeviceSession

    let recordingStore: RecordingStore
    let deviceOnboardingStore: DeviceOnboardingStore
    let deviceListStore: DeviceListStore
    let galleryStore: GalleryStore
    let livePreviewStore: LivePreviewStore
    let playbackStore: PlaybackStore
    let downloadsStore: DownloadsStore
    let localVideosStore: LocalVideosStore
    let eventsStore: EventsStore
    let settingsStore: SettingsStore
    let statisticsStore: StatisticsStore
    let deviceInitialStateCoordinator: DeviceInitialStateCoordinator

    init(
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore,
        localVideoCatalog: LocalVideoCatalog = StaticLocalVideoCatalog(items: []),
        deviceProtocolEndpointProvider: @escaping DeviceProtocolEndpointProvider = { nil }
    ) {
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        let deviceProtocolEndpoint = deviceProtocolEndpointProvider()
        deviceSession = Self.makeDeviceSession(endpoint: deviceProtocolEndpoint)

        recordingStore = RecordingStore(
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore,
            deviceSession: deviceSession
        )
        deviceOnboardingStore = DeviceOnboardingStore(
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore,
            deviceSession: deviceSession
        )
        deviceListStore = DeviceListStore(knownDeviceRepository: knownDeviceRepository)
        galleryStore = GalleryStore(deviceSession: deviceSession)
        livePreviewStore = LivePreviewStore(
            deviceSession: deviceSession,
            mockPreviewAsset: deviceProtocolEndpoint?.mockPreviewAsset
        )
        playbackStore = PlaybackStore(deviceSession: deviceSession)
        downloadsStore = DownloadsStore(deviceSession: deviceSession)
        localVideosStore = LocalVideosStore(catalog: localVideoCatalog)
        eventsStore = EventsStore(deviceSession: deviceSession)
        statisticsStore = StatisticsStore(deviceSession: deviceSession)
        settingsStore = SettingsStore(
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore,
            deviceSession: deviceSession
        )
        deviceInitialStateCoordinator = DeviceInitialStateCoordinator(
            deviceSession: deviceSession,
            recordingStore: recordingStore,
            settingsStore: settingsStore,
            statisticsStore: statisticsStore
        )
    }

    private static func makeDeviceSession(endpoint: DeviceProtocolEndpoint?) -> DeviceSession {
        guard let endpoint else {
            return DeviceSession()
        }

        return DeviceSession(
            protocolClient: DeviceProtocolClient(
                transport: NetworkDeviceProtocolTransport(host: endpoint.host, port: endpoint.port)
            )
        )
    }
}
