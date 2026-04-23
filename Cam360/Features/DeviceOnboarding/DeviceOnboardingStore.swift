import Combine

final class DeviceOnboardingStore: ObservableObject {
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
    }

    func enterScaffold() {
        appPreferenceStore.hasCompletedOnboarding = true
        router.showMain(tab: .dashboard)
    }

    func clearPlaceholderData() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        router.showMain(tab: .dashboard)
    }
}
