import Foundation

final class AppBootstrap {
    enum LaunchArgument {
        static let resetStorage = "-uitest-reset-storage"
        static let forceMain = "-uitest-force-main"
        static let forceOnboarding = "-uitest-force-onboarding"
        static let selectedTab = "-uitest-selected-tab"
        static let deviceProtocolHost = "-device-protocol-host"
        static let deviceProtocolPort = "-device-protocol-port"
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
            appPreferenceStore.hasCompletedOnboarding = true
        }

        let initialRoute = resolveInitialRoute(
            selectedTab: selectedTab
        )
        let router = AppRouter(route: initialRoute)
        let container = AppContainer(
            router: router,
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore,
            deviceProtocolEndpointProvider: {
                deviceProtocolEndpoint(from: arguments)
            }
        )

        return AppBootstrap(container: container, router: router)
    }

    private static func resolveInitialRoute(
        selectedTab: MainTab
    ) -> AppRoute {
        .main(selectedTab)
    }

    private static func tabOverride(from arguments: [String]) -> MainTab? {
        argumentValue(after: LaunchArgument.selectedTab, in: arguments).flatMap(MainTab.init(rawValue:))
    }

    private static func deviceProtocolEndpoint(from arguments: [String]) -> DeviceProtocolEndpoint? {
        guard let host = argumentValue(after: LaunchArgument.deviceProtocolHost, in: arguments),
              host.isEmpty == false else {
            return nil
        }

        let portValue = argumentValue(after: LaunchArgument.deviceProtocolPort, in: arguments)
        let port = portValue.flatMap { UInt16($0) } ?? 8765
        return DeviceProtocolEndpoint(host: host, port: port)
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        return arguments[valueIndex]
    }
}
