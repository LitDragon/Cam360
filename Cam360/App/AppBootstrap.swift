import Foundation

final class AppBootstrap {
    enum LaunchArgument {
        static let resetStorage = "-uitest-reset-storage"
        static let forceMain = "-uitest-force-main"
        static let forceOnboarding = "-uitest-force-onboarding"
        static let selectedTab = "-uitest-selected-tab"
        static let deviceProtocolHost = "-device-protocol-host"
        static let deviceProtocolPort = "-device-protocol-port"
        static let deviceProtocolReadyFile = "-device-protocol-ready-file"
    }

    let container: AppContainer
    let initialSelectedTab: MainTab

    private init(container: AppContainer, initialSelectedTab: MainTab) {
        self.container = container
        self.initialSelectedTab = initialSelectedTab
    }

    static func launch(arguments: [String], userDefaults: UserDefaults = .standard) -> AppBootstrap {
        let knownDeviceRepository = UserDefaultsKnownDeviceRepository(userDefaults: userDefaults)
        let appPreferenceStore = UserDefaultsAppPreferenceStore(userDefaults: userDefaults)
        let localVideoCatalog = UserDefaultsLocalVideoCatalog(userDefaults: userDefaults)

        if arguments.contains(LaunchArgument.resetStorage) {
            knownDeviceRepository.clear()
            appPreferenceStore.reset()
            localVideoCatalog.clear()
        }

        if arguments.contains(LaunchArgument.forceOnboarding) {
            knownDeviceRepository.clear()
            appPreferenceStore.reset()
        }

        let selectedTab = tabOverride(from: arguments) ?? .home
        if arguments.contains(LaunchArgument.forceMain) {
            appPreferenceStore.hasCompletedOnboarding = true
        }

        let container = AppContainer(
            knownDeviceRepository: knownDeviceRepository,
            appPreferenceStore: appPreferenceStore,
            localVideoCatalog: localVideoCatalog,
            deviceProtocolEndpointProvider: {
                deviceProtocolEndpoint(from: arguments)
            }
        )

        return AppBootstrap(container: container, initialSelectedTab: selectedTab)
    }

    private static func tabOverride(from arguments: [String]) -> MainTab? {
        argumentValue(after: LaunchArgument.selectedTab, in: arguments).flatMap(MainTab.init(rawValue:))
    }

    static func deviceProtocolEndpoint(
        from arguments: [String],
        readReadyFileData: (URL) -> Data? = { try? Data(contentsOf: $0) }
    ) -> DeviceProtocolEndpoint? {
        if let host = argumentValue(after: LaunchArgument.deviceProtocolHost, in: arguments),
           host.isEmpty == false {
            let portValue = argumentValue(after: LaunchArgument.deviceProtocolPort, in: arguments)
            let port = portValue.flatMap { UInt16($0) } ?? 8765
            return DeviceProtocolEndpoint(host: host, port: port)
        }

        guard let readyFilePath = argumentValue(after: LaunchArgument.deviceProtocolReadyFile, in: arguments),
              readyFilePath.isEmpty == false,
              let data = readReadyFileData(URL(fileURLWithPath: readyFilePath)) else {
            return nil
        }

        return deviceProtocolEndpoint(fromReadyFileData: data)
    }

    private static func deviceProtocolEndpoint(fromReadyFileData data: Data) -> DeviceProtocolEndpoint? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              payload["ready"] as? Bool == true,
              let host = payload["host"] as? String,
              host.isEmpty == false,
              let port = deviceProtocolPort(from: payload["port"]) else {
            return nil
        }

        return DeviceProtocolEndpoint(
            host: host,
            port: port,
            mockPreviewAsset: mockPreviewAsset(from: payload),
            simulatorControlEndpoint: simulatorControlEndpoint(from: payload),
            simulatorAssetEndpoint: simulatorAssetEndpoint(from: payload)
        )
    }

    private static func simulatorControlEndpoint(from payload: [String: Any]) -> SimulatorControlEndpoint? {
        guard let host = payload["control_host"] as? String,
              host.isEmpty == false,
              let port = deviceProtocolPort(from: payload["control_port"]) else {
            return nil
        }

        return SimulatorControlEndpoint(host: host, port: port)
    }

    private static func simulatorAssetEndpoint(from payload: [String: Any]) -> SimulatorAssetEndpoint? {
        guard let host = payload["asset_host"] as? String,
              host.isEmpty == false,
              let port = deviceProtocolPort(from: payload["asset_port"]) else {
            return nil
        }

        return SimulatorAssetEndpoint(host: host, port: port)
    }

    private static func mockPreviewAsset(from payload: [String: Any]) -> MockPreviewAsset? {
        guard let asset = payload["asset"] as? [String: Any],
              let preview = asset["preview"] as? [String: Any] else {
            return nil
        }

        let mockPreviewAsset = MockPreviewAsset(
            baseURL: nonEmptyString(from: preview["base_url"]),
            mjpegURL: nonEmptyString(from: preview["mjpeg_url"]),
            hlsURL: nonEmptyString(from: preview["hls_url"]),
            mp4URL: nonEmptyString(from: preview["mp4_url"])
        )
        return mockPreviewAsset.preferredURL == nil ? nil : mockPreviewAsset
    }

    private static func deviceProtocolPort(from value: Any?) -> UInt16? {
        if let port = value as? UInt16 {
            return port
        }
        if let port = value as? Int {
            return UInt16(exactly: port)
        }
        if let port = value as? String {
            return UInt16(port)
        }
        if let port = value as? NSNumber {
            return UInt16(exactly: port.intValue)
        }
        return nil
    }

    private static func nonEmptyString(from value: Any?) -> String? {
        guard let value = value as? String,
              value.isEmpty == false else {
            return nil
        }
        return value
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
