import Foundation

final class AppBootstrap {
    enum LaunchArgument {
        static let resetStorage = "-uitest-reset-storage"
        static let forceMain = "-uitest-force-main"
        static let forceOnboarding = "-uitest-force-onboarding"
        static let selectedTab = "-uitest-selected-tab"
    }

    let container: AppContainer
    let router: AppRouter

    private init(container: AppContainer, router: AppRouter) {
        self.container = container
        self.router = router
    }

    static func launch(arguments: [String], userDefaults: UserDefaults = .standard) -> AppBootstrap {
        let knownDeviceRepository = UserDefaultsKnownDeviceRepository(userDefaults: userDefaults)
        let appPreferenceStore = UserDefaultsAppPreferenceStore(userDefaults: userDefaults)

        if arguments.contains(LaunchArgument.resetStorage) {
            knownDeviceRepository.clear()
            appPreferenceStore.reset()
        }

        if arguments.contains(LaunchArgument.forceOnboarding) {
            knownDeviceRepository.clear()
            appPreferenceStore.reset()
        }

        let selectedTab = tabOverride(from: arguments) ?? .dashboard
        if arguments.contains(LaunchArgument.forceMain) {
            knownDeviceRepository.store([.demo])
            appPreferenceStore.hasCompletedOnboarding = true
        }

        let initialRoute = resolveInitialRoute(
            knownDeviceRepository: knownDeviceRepository,
            selectedTab: selectedTab
        )
        let router = AppRouter(route: initialRoute)
        let container = AppContainer(
            router: router,
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore
        )

        return AppBootstrap(container: container, router: router)
    }

    private static func resolveInitialRoute(
        knownDeviceRepository: KnownDeviceRepository,
        selectedTab: MainTab
    ) -> AppRoute {
        knownDeviceRepository.fetchKnownDevices().isEmpty ? .onboarding : .main(selectedTab)
    }

    private static func tabOverride(from arguments: [String]) -> MainTab? {
        guard let index = arguments.firstIndex(of: LaunchArgument.selectedTab) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        return MainTab(rawValue: arguments[valueIndex])
    }
}
