import Testing
import Foundation
@testable import Cam360

@MainActor
struct Cam360Tests {
    @Test
    func bootstrapWithoutKnownDevicesShowsDashboard() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let bootstrap = AppBootstrap.launch(arguments: ["Cam360Tests"], userDefaults: testDefaults.userDefaults)

        #expect(bootstrap.router.route == .main(.dashboard))
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
        let router = AppRouter(route: .main(.dashboard))

        router.showMain(tab: .gallery)
        #expect(router.route == .main(.gallery))

        router.selectedMainTab = .settings
        #expect(router.route == .main(.settings))

        router.showOnboarding()
        #expect(router.route == .onboarding)
    }

    @Test
    func dashboardStoreShowsFeatureSheetUntilDismissed() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let store = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(store.hasDevices == false)
        #expect(store.shouldShowFeatureSheet)

        store.dismissFeatureSheet()
        #expect(store.shouldShowFeatureSheet == false)
        #expect(preferenceStore.hasCompletedOnboarding)
    }

    @Test
    func dashboardStoreExposesDeviceHubStates() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        repository.store([
            makeKnownDevice(id: "cam360-main", name: "DriveCam X Pro"),
            makeKnownDevice(id: "cam360-rear", name: "Rear View"),
            makeKnownDevice(id: "cam360-cabin", name: "Cabin View"),
            makeKnownDevice(id: "cam360-side", name: "Side View")
        ])

        let store = DashboardStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        #expect(store.hasDevices)
        #expect(store.isRecording == false)
        #expect(store.recentEvents.count == 4)

        store.toggleRecording()
        #expect(store.isRecording)

        store.selectDevice(id: "cam360-cabin")
        #expect(store.recentEvents.isEmpty)
        if case let .available(summary) = store.storageState {
            #expect(summary.usageText == "58% USED")
        } else {
            #expect(Bool(false))
        }

        store.selectDevice(id: "cam360-side")
        #expect(store.isRecording)
        if case let .unavailable(title, _) = store.storageState {
            #expect(title == "No SD card detected")
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func deviceOnboardingStoreHappyPathPersistsDeviceAndReturnsToDashboard() {
        let testDefaults = makeUserDefaults()
        defer { clear(testDefaults) }

        let repository = UserDefaultsKnownDeviceRepository(userDefaults: testDefaults.userDefaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: testDefaults.userDefaults)
        let router = AppRouter(route: .main(.dashboard))
        let store = DeviceOnboardingStore(
            router: router,
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore
        )

        store.startSearch()
        #expect(store.route == .searching)

        store.advanceFromSearching()
        #expect(store.route == .wifiDetails)
        #expect(store.canContinueWithWiFiDetails)

        store.continueFromWiFiDetails()
        #expect(store.route == .connecting)

        store.completeConnection()
        #expect(store.route == .success)
        #expect(store.addedDeviceName == "Vigilant DL-400 Pro")
        #expect(repository.fetchKnownDevices().count == 1)
        #expect(repository.fetchKnownDevices().first?.name == "Vigilant DL-400 Pro")
        #expect(preferenceStore.hasCompletedOnboarding)

        store.enterHome()
        #expect(router.route == .main(.dashboard))
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

        store.show(.helpCenter)
        #expect(store.route == .helpCenter)

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
    func settingsStoreResetShellReturnsToDashboard() {
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

        repository.store([makeKnownDevice()])
        preferenceStore.hasCompletedOnboarding = true

        store.resetShell()

        #expect(repository.fetchKnownDevices().isEmpty)
        #expect(preferenceStore.hasCompletedOnboarding == false)
        #expect(router.route == .main(.dashboard))
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
