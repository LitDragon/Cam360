import Testing
import Foundation
@testable import Cam360

struct DeviceOnboardingStoreTests {
    @Test
    func enterScaffoldStoresDemoDeviceAndCompletesOnboarding() {
        let router = AppRouter(route: .onboarding)
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: .ephemeral)

        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.enterScaffold()

        #expect(router.route == .main(.dashboard))
        #expect(repository.fetchKnownDevices() == [.demo])
        #expect(preferenceStore.hasCompletedOnboarding == true)
    }

    @Test
    func clearPlaceholderDataResetsStorageAndShowsOnboarding() {
        let router = AppRouter(route: .main(.dashboard))
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: .ephemeral)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: .ephemeral)

        repository.store([.demo])
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
