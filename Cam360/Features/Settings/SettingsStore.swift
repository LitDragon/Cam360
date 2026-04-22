import Combine

final class SettingsStore: ObservableObject {
    @Published private(set) var route: SettingsRoute?
    @Published private(set) var knownDeviceCount = 0
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var shareAnonymousLogs = true
    @Published private(set) var notificationPreferences = NotificationPreferences.defaultValue

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
        shareAnonymousLogs = appPreferenceStore.shareAnonymousLogs
        notificationPreferences = appPreferenceStore.notificationPreferences
    }

    func resetShell() {
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        route = nil
        refresh()
        router.showOnboarding()
    }

    func show(_ route: SettingsRoute) {
        self.route = route
    }

    func dismissRoute() {
        route = nil
    }

    func setShareAnonymousLogs(_ isEnabled: Bool) {
        shareAnonymousLogs = isEnabled
        appPreferenceStore.shareAnonymousLogs = isEnabled
    }

    func setNotificationPreference<Value>(
        _ keyPath: WritableKeyPath<NotificationPreferences, Value>,
        to value: Value
    ) {
        var updatedPreferences = notificationPreferences
        updatedPreferences[keyPath: keyPath] = value
        notificationPreferences = updatedPreferences
        appPreferenceStore.notificationPreferences = updatedPreferences
    }
}
