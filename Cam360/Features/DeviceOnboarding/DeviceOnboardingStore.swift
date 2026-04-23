import Combine
import Foundation

final class DeviceOnboardingStore: ObservableObject {
    @Published private(set) var route: DeviceOnboardingRoute
    @Published var networkName: String
    @Published var password: String
    @Published var isPasswordVisible: Bool
    @Published private(set) var addedDeviceName: String
    @Published private(set) var pendingDeviceName: String

    private let router: AppRouter
    private let knownDeviceRepository: KnownDeviceRepository
    private let appPreferenceStore: AppPreferenceStore

    private var pendingTransition: DispatchWorkItem?

    init(
        router: AppRouter,
        knownDeviceRepository: KnownDeviceRepository,
        appPreferenceStore: AppPreferenceStore
    ) {
        self.router = router
        self.knownDeviceRepository = knownDeviceRepository
        self.appPreferenceStore = appPreferenceStore
        route = .introduction
        networkName = "MyHome_WiFi_2.4G"
        password = "securecam360"
        isPasswordVisible = false
        addedDeviceName = "Vigilant DL-400 Pro"
        pendingDeviceName = "Vigilant DL-400 Pro"
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
        scheduleTransition(after: 1.2) { [weak self] in
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
        scheduleTransition(after: 1.4) { [weak self] in
            self?.completeConnection()
        }
    }

    func completeConnection() {
        guard route == .connecting else {
            return
        }

        let device = persistPlaceholderDevice()
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
            route = .wifiDetails
        }
    }

    func cancelConnection() {
        cancelScheduledTransition()
        route = .wifiDetails
    }

    func enterHome() {
        cancelScheduledTransition()
        route = .introduction
        router.showMain(tab: .dashboard)
    }

    func addAnotherDevice() {
        cancelScheduledTransition()
        pendingDeviceName = nextDeviceName()
        route = .introduction
    }

    func togglePasswordVisibility() {
        isPasswordVisible.toggle()
    }

    func clearPlaceholderData() {
        cancelScheduledTransition()
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

    private func persistPlaceholderDevice() -> KnownDeviceSummary {
        var devices = knownDeviceRepository.fetchKnownDevices()
        let nextIndex = devices.count + 1
        let device = KnownDeviceSummary(
            id: "cam360-device-\(nextIndex)",
            name: nextDeviceName(for: nextIndex),
            hotspotSSID: "Cam360_DL400_\(nextIndex)",
            lastConnectedAt: Date()
        )
        devices.append(device)
        knownDeviceRepository.store(devices)
        return device
    }

    private func nextDeviceName() -> String {
        nextDeviceName(for: knownDeviceRepository.fetchKnownDevices().count + 1)
    }

    private func nextDeviceName(for index: Int) -> String {
        index == 1 ? "Vigilant DL-400 Pro" : "Vigilant DL-400 Pro \(index)"
    }
}
