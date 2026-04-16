import Testing
import Foundation
@testable import Cam360

struct Cam360Tests {
    @Test
    func bootstrapWithoutKnownDevicesShowsOnboarding() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.router.route == .onboarding)
    }

    @Test
    func bootstrapAfterOnboardingShowsMain() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        preferenceStore.hasCompletedOnboarding = true

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.router.route == .main(.dashboard))
    }

    @Test
    func routerTransitionsArePredictable() {
        let router = AppRouter(route: .onboarding)

        router.showMain(tab: .gallery)
        #expect(router.route == .main(.gallery))

        router.selectedMainTab = .settings
        #expect(router.route == .main(.settings))

        router.showOnboarding()
        #expect(router.route == .onboarding)
    }

    @Test
    func userDefaultsStorageRoundTrips() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let device = makeKnownDevice()

        repository.store([device])
        preferenceStore.hasCompletedOnboarding = true

        #expect(repository.fetchKnownDevices() == [device])
        #expect(preferenceStore.hasCompletedOnboarding)

        repository.clear()
        preferenceStore.reset()

        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
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

extension UserDefaults {
    static var ephemeral: UserDefaults {
        UserDefaults(suiteName: "Cam360Tests.\(UUID().uuidString)")!
    }
}

private struct TestDefaults {
    let suiteName: String
    let userDefaults: UserDefaults
}
