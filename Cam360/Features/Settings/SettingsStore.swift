import Combine

final class SettingsStore: ObservableObject {
    @Published private(set) var knownDeviceCount = 0
    @Published private(set) var hasCompletedOnboarding = false

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
        refresh()
    }

    func refresh() {
        knownDeviceCount = knownDeviceRepository.fetchKnownDevices().count
        hasCompletedOnboarding = appPreferenceStore.hasCompletedOnboarding
    }

    func resetShell() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        refresh()
        router.showOnboarding()
    }
}
