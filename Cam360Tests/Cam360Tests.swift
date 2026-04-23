import Testing
import Foundation
@testable import Cam360

@MainActor
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
    func settingsStoreRoutesAndPersistsPreferences() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.settings))
        let store = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.show(.notificationSettings)
        #expect(store.route == .notificationSettings)

        store.dismissRoute()
        #expect(store.route == nil)

        store.setShareAnonymousLogs(false)
        store.setNotificationPreference(\.quietHoursEnabled, to: true)
        store.setNotificationPreference(\.parkingIncidentAlerts, to: true)

        let reloadedStore = SettingsStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(reloadedStore.shareAnonymousLogs == false)
        #expect(reloadedStore.notificationPreferences.quietHoursEnabled)
        #expect(reloadedStore.notificationPreferences.parkingIncidentAlerts)
    }

    @Test
    func onboardingStoreSupportsHappyPath() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .onboarding)
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(store.route == .preparation)
        #expect(store.hasConnectedHotspot == false)
        #expect(store.hasValidatedDevice == false)

        store.startHotspotGuide()
        #expect(store.route == .hotspotGuide)

        store.confirmHotspotConnected()
        #expect(store.route == .verification)
        #expect(store.hasConnectedHotspot)
        #expect(store.hasValidatedDevice == false)

        store.confirmDeviceValidated()
        #expect(store.route == .ready)
        #expect(store.hasValidatedDevice)

        store.finishOnboarding()
        #expect(preferenceStore.hasCompletedOnboarding)
        #expect(router.route == .main(.dashboard))
    }

    @Test
    func onboardingStoreSupportsRecoveryAndReset() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .onboarding)
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.startHotspotGuide()
        store.confirmHotspotConnected()
        store.showRecoveryGuide()

        #expect(store.route == .recovery)
        #expect(store.hasConnectedHotspot)
        #expect(store.hasValidatedDevice == false)

        store.retryVerification()
        #expect(store.route == .verification)

        store.returnToHotspotGuide()
        #expect(store.route == .hotspotGuide)
        #expect(store.hasConnectedHotspot == false)

        repository.store([makeKnownDevice()])
        preferenceStore.hasCompletedOnboarding = true

        store.clearPlaceholderData()

        #expect(store.route == .preparation)
        #expect(store.hasConnectedHotspot == false)
        #expect(store.hasValidatedDevice == false)
        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
        #expect(router.route == .onboarding)
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
