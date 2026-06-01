import Combine
import Foundation

final class DeviceInitialStateCoordinator {
    private(set) var didApplySnapshot = false

    private let deviceSession: DeviceSession
    private let recordingStore: RecordingStore
    private let settingsStore: SettingsStore
    private let statisticsStore: StatisticsStore
    private var didRequestSnapshot = false
    private var cancellables = Set<AnyCancellable>()

    init(
        deviceSession: DeviceSession,
        recordingStore: RecordingStore,
        settingsStore: SettingsStore,
        statisticsStore: StatisticsStore
    ) {
        self.deviceSession = deviceSession
        self.recordingStore = recordingStore
        self.settingsStore = settingsStore
        self.statisticsStore = statisticsStore

        bindDeviceSession()
        loadInitialSnapshotIfNeeded(from: deviceSession.state)
    }

    private func bindDeviceSession() {
        deviceSession.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.loadInitialSnapshotIfNeeded(from: state)
            }
            .store(in: &cancellables)
    }

    private func loadInitialSnapshotIfNeeded(from state: DeviceSessionState) {
        switch state {
        case .ready:
            break
        case .busy:
            return
        case .idle, .apConnecting, .handshaking, .recovering, .failed, .disconnected:
            didRequestSnapshot = false
            didApplySnapshot = false
            return
        }

        guard didRequestSnapshot == false else {
            return
        }

        didRequestSnapshot = true
        deviceSession.fetchStateSync(scope: .initial) { [weak self] result in
            guard let self, case .success(let snapshot) = result else {
                return
            }

            self.apply(snapshot)
            self.fetchOmittedSectionsIfNeeded(from: snapshot)
        }
    }

    private func fetchOmittedSectionsIfNeeded(from snapshot: DeviceStateSyncSnapshot) {
        let scopes = Self.stateSyncScopes(from: snapshot.omittedSections)
        guard scopes.isEmpty == false else {
            didApplySnapshot = true
            return
        }

        fetchNextOmittedSection(from: scopes)
    }

    private func fetchNextOmittedSection(from scopes: [DeviceStateSyncScope]) {
        guard scopes.isEmpty == false else {
            didApplySnapshot = true
            return
        }

        var remainingScopes = scopes
        let scope = remainingScopes.removeFirst()
        deviceSession.fetchStateSync(scope: scope) { [weak self] result in
            guard let self else {
                return
            }

            if case .success(let snapshot) = result {
                self.apply(snapshot)
            }

            self.fetchNextOmittedSection(from: remainingScopes)
        }
    }

    private func apply(_ snapshot: DeviceStateSyncSnapshot) {
        recordingStore.applyInitialStateSyncSnapshot(snapshot)
        settingsStore.applyInitialStateSyncSnapshot(snapshot)
        statisticsStore.applyInitialStateSyncSnapshot(snapshot)
    }

    private static func stateSyncScopes(from omittedSections: [String]) -> [DeviceStateSyncScope] {
        omittedSections.reduce(into: []) { scopes, section in
            guard let scope = DeviceStateSyncScope(omittedSection: section),
                  scopes.contains(scope) == false else {
                return
            }

            scopes.append(scope)
        }
    }
}

private extension DeviceStateSyncScope {
    init?(omittedSection: String) {
        switch omittedSection {
        case "home":
            self = .home
        case "storage":
            self = .storage
        case "settings_home":
            self = .settingsHome
        case "recording":
            self = .recording
        case "safety":
            self = .safety
        case "watermark":
            self = .watermark
        case "wifi":
            self = .wifi
        case "system_preferences":
            self = .systemPreferences
        case "statistics":
            self = .statistics
        default:
            return nil
        }
    }
}
