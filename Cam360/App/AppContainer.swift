import Foundation

final class AppContainer {
    let knownDeviceRepository: KnownDeviceRepository
    let appPreferenceStore: AppPreferenceStore

    let dashboardStore: DashboardStore
    let deviceOnboardingStore: DeviceOnboardingStore
    let deviceListStore: DeviceListStore
    let livePreviewStore: LivePreviewStore
    let playbackStore: PlaybackStore
    let downloadsStore: DownloadsStore
    let settingsStore: SettingsStore

    init(
        router: AppRouter,
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore
    ) {
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore

        dashboardStore = DashboardStore(
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore
        )
        deviceOnboardingStore = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore
        )
        deviceListStore = DeviceListStore(knownDeviceRepository: knownDeviceRepository)
        livePreviewStore = LivePreviewStore()
        playbackStore = PlaybackStore()
        downloadsStore = DownloadsStore()
        settingsStore = SettingsStore(
            router: router,
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore
        )
    }
}
