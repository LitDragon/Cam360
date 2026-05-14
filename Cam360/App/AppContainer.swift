import Foundation

struct DeviceProtocolEndpoint: Equatable {
    let host: String
    let port: UInt16

    init(host: String, port: UInt16 = 8765) {
        self.host = host
        self.port = port
    }
}

final class AppContainer {
    typealias DeviceProtocolEndpointProvider = () -> DeviceProtocolEndpoint?

    let knownDeviceRepository: KnownDeviceRepository
    let appPreferenceStore: AppPreferenceStore
    let deviceSession: DeviceSession

    let dashboardStore: DashboardStore
    let deviceOnboardingStore: DeviceOnboardingStore
    let deviceListStore: DeviceListStore
    let galleryStore: GalleryStore
    let livePreviewStore: LivePreviewStore
    let playbackStore: PlaybackStore
    let downloadsStore: DownloadsStore
    let eventsStore: EventsStore
    let settingsStore: SettingsStore

    init(
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore,
        deviceProtocolEndpointProvider: @escaping DeviceProtocolEndpointProvider = { nil }
    ) {
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        deviceSession = Self.makeDeviceSession(endpointProvider: deviceProtocolEndpointProvider)

        dashboardStore = DashboardStore(
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
        livePreviewStore = LivePreviewStore()
        playbackStore = PlaybackStore(deviceSession: deviceSession)
        downloadsStore = DownloadsStore()
        eventsStore = EventsStore()
        settingsStore = SettingsStore(
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore,
            deviceSession: deviceSession
        )
    }

    private static func makeDeviceSession(endpointProvider: DeviceProtocolEndpointProvider) -> DeviceSession {
        guard let endpoint = endpointProvider() else {
            return DeviceSession()
        }

        return DeviceSession(
            protocolClient: DeviceProtocolClient(
                transport: NetworkDeviceProtocolTransport(host: endpoint.host, port: endpoint.port)
            )
        )
    }
}
