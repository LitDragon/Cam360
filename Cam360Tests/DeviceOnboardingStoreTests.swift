import Testing
import Foundation
@testable import Cam360

struct DeviceOnboardingStoreTests {
    @Test
    func enterScaffoldCompletesOnboardingWithoutSeedingDevices() {
        let router = AppRouter(route: .onboarding)
        let userDefaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: userDefaults)

        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.enterScaffold()

        #expect(router.route == .main(.dashboard))
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == true)
    }

    @Test
    func clearPlaceholderDataResetsStorageAndShowsOnboarding() {
        let router = AppRouter(route: .main(.dashboard))
        let userDefaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: userDefaults)

        repository.store([makeKnownDevice()])
        preferenceStore.hasCompletedOnboarding = true

        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.clearPlaceholderData()

        #expect(router.route == .onboarding)
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
    }
}
