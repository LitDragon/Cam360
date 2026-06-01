import Combine
import Foundation

enum StatisticsLoadState: Equatable {
    case idle
    case loading
    case loaded
    case unavailable(message: String)
}

struct StatisticsSnapshot: Equatable {
    var videoCount: Int
    var photoCount: Int
    var lockedVideoCount: Int
    var lockedPhotoCount: Int
    var totalSizeBytes: Int
    var totalDurationSeconds: Int
    var usageDays: Int

    static let empty = StatisticsSnapshot(
        videoCount: 0,
        photoCount: 0,
        lockedVideoCount: 0,
        lockedPhotoCount: 0,
        totalSizeBytes: 0,
        totalDurationSeconds: 0,
        usageDays: 0
    )
}

struct StatisticsDeviceInfo: Equatable {
    var model: String
    var firmwareVersion: String
    var serialNumber: String

    static let placeholder = StatisticsDeviceInfo(
        model: "Unknown",
        firmwareVersion: "Unknown",
        serialNumber: "Unknown"
    )
}

final class StatisticsStore: ObservableObject {
    @Published private(set) var loadState: StatisticsLoadState = .idle
    @Published private(set) var statistics = StatisticsSnapshot.empty
    @Published private(set) var deviceInfo = StatisticsDeviceInfo.placeholder

    private let deviceSession: DeviceSession?
    private var refreshGeneration = 0

    init(deviceSession: DeviceSession? = nil) {
        self.deviceSession = deviceSession
    }

    var totalFilesText: String {
        "\(statistics.videoCount + statistics.photoCount)"
    }

    var totalSizeText: String {
        guard statistics.totalSizeBytes > 0 else {
            return "0 MB"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(statistics.totalSizeBytes))
    }

    var totalDurationText: String {
        let seconds = statistics.totalDurationSeconds
        guard seconds > 0 else {
            return "0 min"
        }

        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    var usageDaysText: String {
        "\(statistics.usageDays)d"
    }

    var canRefresh: Bool {
        loadState != .loading
    }

    func applyInitialStateSyncSnapshot(_ snapshot: DeviceStateSyncSnapshot) {
        if let settingsHomeDeviceInfo = snapshot.sections.object("settings_home")?.object("device_info") {
            deviceInfo = StatisticsDeviceInfo(
                model: settingsHomeDeviceInfo.string("model") ?? deviceInfo.model,
                firmwareVersion: settingsHomeDeviceInfo.string("fw_version") ?? deviceInfo.firmwareVersion,
                serialNumber: settingsHomeDeviceInfo.string("serial_no") ?? deviceInfo.serialNumber
            )
        }

        guard let statisticsSection = snapshot.sections.object("statistics") else {
            return
        }

        statistics = Self.statistics(from: statisticsSection)
        loadState = .loaded
    }

    func refresh() {
        guard canRefresh else {
            return
        }

        guard let deviceSession, deviceSession.state.canSendDeviceCommand else {
            loadState = .unavailable(message: "统计页需要设备控制通道 ready 后读取。")
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        loadState = .loading

        deviceSession.fetchStateSync(scope: .statistics) { [weak self] result in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            switch result {
            case .success(let snapshot):
                guard let statisticsSection = snapshot.sections.object("statistics") else {
                    self.loadState = .unavailable(message: "STATE_SYNC.statistics 缺失。")
                    return
                }
                self.statistics = Self.statistics(from: statisticsSection)
                self.loadState = .loaded
            case .failure:
                self.loadState = .unavailable(message: "无法读取设备统计聚合快照。")
            }
        }

        deviceSession.fetchDeviceBasicInfo { [weak self] result in
            guard let self, self.refreshGeneration == generation else {
                return
            }

            if case .success(let info) = result {
                self.deviceInfo = StatisticsDeviceInfo(
                    model: info.model,
                    firmwareVersion: info.firmwareVersion,
                    serialNumber: info.serialNumber
                )
            }
        }
    }

    private static func statistics(from section: [String: DeviceProtocolValue]) -> StatisticsSnapshot {
        let storageCounts = section.object("storage_counts") ?? [:]
        let lockedCounts = section.object("locked_counts") ?? [:]
        let deviceTotals = section.object("device_totals") ?? [:]

        return StatisticsSnapshot(
            videoCount: storageCounts.int("video_count") ?? 0,
            photoCount: storageCounts.int("photo_count") ?? 0,
            lockedVideoCount: lockedCounts.int("video_locked") ?? 0,
            lockedPhotoCount: lockedCounts.int("photo_locked") ?? 0,
            totalSizeBytes: deviceTotals.int("total_size") ?? 0,
            totalDurationSeconds: deviceTotals.int("total_duration_sec") ?? 0,
            usageDays: deviceTotals.int("usage_days") ?? 0
        )
    }
}
