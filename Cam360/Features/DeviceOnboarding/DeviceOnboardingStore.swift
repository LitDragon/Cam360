import Combine
import Foundation

enum DeviceOnboardingRecoveryAction: Equatable {
    case retryHotspot
    case checkLocalNetworkPermission
    case retryControlChannel

    var guidance: String {
        switch self {
        case .retryHotspot:
            return "Check the dashcam hotspot name and password, then try again."
        case .checkLocalNetworkPermission:
            return "Allow Local Network access for Cam360 in iOS Settings, then retry validation."
        case .retryControlChannel:
            return "Keep the phone on the dashcam hotspot and retry device validation."
        }
    }
}

enum DeviceOnboardingConnectionStage: Equatable {
    case idle
    case connectingHotspot
    case validatingControlChannel
    case ready
    case retryRequired(message: String, action: DeviceOnboardingRecoveryAction)

    static func retry(for error: DeviceError) -> DeviceOnboardingConnectionStage {
        switch error {
        case .apConnectionFailed:
            return .retryRequired(message: error.localizedDescription, action: .retryHotspot)
        case .handshakeFailed:
            return .retryRequired(message: error.localizedDescription, action: .checkLocalNetworkPermission)
        case .connectionLost, .timeout, .unknown:
            return .retryRequired(message: error.localizedDescription, action: .retryControlChannel)
        }
    }

    func title(deviceName: String) -> String {
        switch self {
        case .idle:
            return "Ready to connect"
        case .connectingHotspot:
            return "Connecting to \(deviceName)..."
        case .validatingControlChannel:
            return "Device hotspot connected"
        case .ready:
            return "Device ready"
        case .retryRequired:
            return "Connection needs retry"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Enter the dashcam hotspot details to start setup."
        case .connectingHotspot:
            return "Joining the dashcam Wi-Fi hotspot before checking device control."
        case .validatingControlChannel:
            return "Checking whether the dashcam control channel is ready."
        case .ready:
            return "The dashcam control channel is ready."
        case .retryRequired(let message, _):
            return message
        }
    }

    var progress: Double {
        switch self {
        case .idle:
            return 0
        case .connectingHotspot:
            return 0.36
        case .validatingControlChannel:
            return 0.72
        case .ready:
            return 1
        case .retryRequired:
            return 0
        }
    }

    var retryMessage: String? {
        if case .retryRequired(let message, _) = self {
            return message
        }
        return nil
    }

    var recoveryAction: DeviceOnboardingRecoveryAction? {
        if case .retryRequired(_, let action) = self {
            return action
        }
        return nil
    }

    var recoveryGuidance: String? {
        recoveryAction?.guidance
    }
}

final class DeviceOnboardingStore: ObservableObject {
    @Published private(set) var route: DeviceOnboardingRoute
    @Published var networkName: String
    @Published var password: String
    @Published var isPasswordVisible: Bool
    @Published private(set) var addedDeviceName: String
    @Published private(set) var pendingDeviceName: String
    @Published private(set) var connectionStage: DeviceOnboardingConnectionStage

    let deviceSession: DeviceSession

    private let router: AppRouter
    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore

    private var pendingTransition: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(
        router: AppRouter,
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore,
        deviceSession: DeviceSession = DeviceSession()
    ) {
        self.router = router
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        self.deviceSession = deviceSession
        route = .introduction
        networkName = DeviceOnboardingPlaceholder.networkName
        password = DeviceOnboardingPlaceholder.password
        isPasswordVisible = false
        addedDeviceName = DeviceOnboardingPlaceholder.deviceName
        pendingDeviceName = DeviceOnboardingPlaceholder.deviceName
        connectionStage = .idle

        bindDeviceSession()
    }

    deinit {
        pendingTransition?.cancel()
    }

    var canContinueWithWiFiDetails: Bool {
        password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func startSearch() {
        cancelScheduledTransition()
        pendingDeviceName = nextDeviceName()
        connectionStage = .idle
        route = .searching
        scheduleTransition(after: DeviceOnboardingTiming.searchToWiFiDetailsDelay) { [weak self] in
            self?.advanceFromSearching()
        }
    }

    func advanceFromSearching() {
        guard route == .searching else {
            return
        }

        route = .wifiDetails
    }

    func continueFromWiFiDetails() {
        guard canContinueWithWiFiDetails else {
            return
        }

        cancelScheduledTransition()
        connectionStage = .connectingHotspot
        route = .connecting
        startDeviceSessionHandshake()
    }

    private func completeConnection(with deviceInfo: DeviceInfo) {
        guard route == .connecting else {
            return
        }

        let device = persistDevice(deviceInfo)
        addedDeviceName = device.name
        connectionStage = .ready
        appPreferenceStore.hasCompletedOnboarding = true
        route = .success
    }

    func goBack() {
        cancelScheduledTransition()

        switch route {
        case .introduction, .success:
            route = .introduction
            router.showMain(tab: .dashboard)
        case .searching:
            route = .introduction
        case .wifiDetails:
            route = .introduction
        case .connecting:
            deviceSession.send(.reset)
            connectionStage = .idle
            route = .wifiDetails
        }
    }

    func cancelConnection() {
        cancelScheduledTransition()
        deviceSession.send(.reset)
        connectionStage = .idle
        route = .wifiDetails
    }

    func enterHome() {
        cancelScheduledTransition()
        connectionStage = .idle
        route = .introduction
        router.showMain(tab: .dashboard)
    }

    func addAnotherDevice() {
        cancelScheduledTransition()
        deviceSession.send(.reset)
        pendingDeviceName = nextDeviceName()
        connectionStage = .idle
        route = .introduction
    }

    func togglePasswordVisibility() {
        isPasswordVisible.toggle()
    }

    func clearPlaceholderData() {
        cancelScheduledTransition()
        deviceSession.send(.reset)
        knownDeviceRepository.clear()
        appPreferenceStore.reset()
        connectionStage = .idle
        route = .introduction
        router.showMain(tab: .dashboard)
    }

    private func scheduleTransition(after delay: TimeInterval, action: @escaping () -> Void) {
        let workItem = DispatchWorkItem(block: action)
        pendingTransition = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelScheduledTransition() {
        pendingTransition?.cancel()
        pendingTransition = nil
    }

    private func startDeviceSessionHandshake() {
        deviceSession.send(.reset)
        deviceSession.send(.startAPConnection(ssid: networkName))
        deviceSession.send(.apConnectionSucceeded)
        connectionStage = .validatingControlChannel
        deviceSession.startProtocolHandshake()
    }

    private func bindDeviceSession() {
        deviceSession.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleDeviceSessionState(state)
            }
            .store(in: &cancellables)
    }

    private func handleDeviceSessionState(_ state: DeviceSessionState) {
        guard route == .connecting else {
            return
        }

        switch state {
        case .apConnecting:
            connectionStage = .connectingHotspot
        case .handshaking:
            connectionStage = .validatingControlChannel
        case .ready(let deviceInfo):
            completeConnection(with: deviceInfo)
        case .failed(let error):
            connectionStage = .retry(for: error)
            route = .wifiDetails
        default:
            break
        }
    }

    private func persistDevice(_ deviceInfo: DeviceInfo) -> KnownDeviceSummary {
        var devices = knownDeviceRepository.fetchKnownDevices()
        let device = KnownDeviceSummary(
            id: deviceInfo.id,
            name: deviceInfo.name,
            hotspotSSID: networkName,
            lastConnectedAt: Date()
        )

        if let existingIndex = devices.firstIndex(where: { $0.id == device.id }) {
            devices[existingIndex] = device
        } else {
            devices.append(device)
        }

        knownDeviceRepository.store(devices)
        return device
    }

    private func nextDeviceName() -> String {
        nextDeviceName(for: knownDeviceRepository.fetchKnownDevices().count + 1)
    }

    private func nextDeviceName(for index: Int) -> String {
        index == 1 ? DeviceOnboardingPlaceholder.deviceName : "\(DeviceOnboardingPlaceholder.deviceName) \(index)"
    }
}

private enum DeviceOnboardingPlaceholder {
    static let networkName = "Cam360_AP"
    static let password = "password123"
    static let deviceName = "Vigilant DL-400 Pro"
}

private enum DeviceOnboardingTiming {
    static let searchToWiFiDetailsDelay: TimeInterval = 1.2
}
