import Combine
import Foundation

final class DeviceOnboardingStore: ObservableObject {
    @Published private(set) var route: DeviceOnboardingRoute
    @Published var networkName: String
    @Published var password: String
    @Published var isPasswordVisible: Bool
    @Published private(set) var addedDeviceName: String
    @Published private(set) var pendingDeviceName: String

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
        route = .connecting
        startDeviceSessionHandshake()
    }

    private func completeConnection(with deviceInfo: DeviceInfo) {
        guard route == .connecting else {
            return
        }

        let device = persistDevice(deviceInfo)
        addedDeviceName = device.name
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
            route = .wifiDetails
        }
    }

    func cancelConnection() {
        cancelScheduledTransition()
        deviceSession.send(.reset)
        route = .wifiDetails
    }

    func enterHome() {
        cancelScheduledTransition()
        route = .introduction
        router.showMain(tab: .dashboard)
    }

    func addAnotherDevice() {
        cancelScheduledTransition()
        deviceSession.send(.reset)
        pendingDeviceName = nextDeviceName()
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
        case .ready(let deviceInfo):
            completeConnection(with: deviceInfo)
        case .failed:
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
    static let networkName = "MyHome_WiFi_2.4G"
    static let password = "password123"
    static let deviceName = "Vigilant DL-400 Pro"
}

private enum DeviceOnboardingTiming {
    static let searchToWiFiDetailsDelay: TimeInterval = 1.2
}
