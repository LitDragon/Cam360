import Combine

final class DeviceOnboardingStore: ObservableObject {
    @Published private(set) var route: DeviceOnboardingRoute = .preparation
    @Published private(set) var hasConnectedHotspot = false
    @Published private(set) var hasValidatedDevice = false

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

    func prepareForDisplay() {
        guard appPreferenceStore.hasCompletedOnboarding == false else {
            return
        }

        resetProgress()
    }

    func startHotspotGuide() {
        route = .hotspotGuide
    }

    func returnToPreparation() {
        resetProgress()
    }

    func confirmHotspotConnected() {
        hasConnectedHotspot = true
        hasValidatedDevice = false
        route = .verification
    }

    func confirmDeviceValidated() {
        hasValidatedDevice = true
        route = .ready
    }

    func showRecoveryGuide() {
        hasValidatedDevice = false
        route = .recovery
    }

    func retryVerification() {
        route = .verification
    }

    func returnToHotspotGuide() {
        hasConnectedHotspot = false
        hasValidatedDevice = false
        route = .hotspotGuide
    }

    func returnToVerification() {
        hasValidatedDevice = false
        route = .verification
    }

    func finishOnboarding() {
        appPreferenceStore.hasCompletedOnboarding = true
        router.showMain(tab: .dashboard)
    }

    func clearPlaceholderData() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        resetProgress()
        router.showOnboarding()
    }

    private func resetProgress() {
        route = .preparation
        hasConnectedHotspot = false
        hasValidatedDevice = false
    }
}
