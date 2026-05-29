import Foundation

enum RecordingResolutionOption: String, CaseIterable {
    case fullHD = "1080P"
    case hd = "720P"
    case wideVGA = "WVGA"
}

enum RecordingQualityPriorityOption: String, CaseIterable {
    case quality = "Quality"
    case balanced = "Balanced"
    case storage = "Storage"
}

enum LoopRecordingDurationOption: String, CaseIterable {
    case oneMinute = "1 min"
    case threeMinutes = "3 min"
    case fiveMinutes = "5 min"
}

enum RecordingStartBehaviorOption: String, CaseIterable {
    case auto = "Auto"
    case manual = "Manual"
}

struct RecordingSettingsState: Equatable {
    var resolution: RecordingResolutionOption
    var qualityPriority: RecordingQualityPriorityOption
    var loopDuration: LoopRecordingDurationOption
    var autoOverwrite: Bool
    var startBehavior: RecordingStartBehaviorOption
    var audioRecordingEnabled: Bool
    var hdrNightRecordingEnabled: Bool
    var recordingStatusIndicatorEnabled: Bool
    var recordingReminderEnabled: Bool

    static let defaultValue = RecordingSettingsState(
        resolution: .fullHD,
        qualityPriority: .balanced,
        loopDuration: .threeMinutes,
        autoOverwrite: true,
        startBehavior: .auto,
        audioRecordingEnabled: false,
        hdrNightRecordingEnabled: true,
        recordingStatusIndicatorEnabled: true,
        recordingReminderEnabled: false
    )
}

enum StorageCardStatus: String, CaseIterable {
    case ready = "Ready"
    case noCard = "No Card"
    case error = "Error"
}

enum LockedEventRetentionOption: String, CaseIterable {
    case keepForever = "Keep Forever"
    case thirtyDays = "30 Days"
    case sevenDays = "7 Days"
}

struct StoragePolicyState: Equatable {
    var cardStatus: StorageCardStatus
    var usedSpaceGB: Double
    var totalSpaceGB: Double
    var estimatedHoursRemaining: String
    var autoCleanupEnabled: Bool
    var autoOverwriteEnabled: Bool
    var lockedEventRetention: LockedEventRetentionOption
    var reservedEventSpacePercent: Int

    var usageProgress: Double {
        guard totalSpaceGB > 0 else {
            return 0
        }

        return usedSpaceGB / totalSpaceGB
    }

    var usedSpaceText: String {
        String(format: "%.1f GB", usedSpaceGB)
    }

    var totalSpaceText: String {
        String(format: "%.1f GB", totalSpaceGB)
    }

    var freeSpaceText: String {
        String(format: "%.1f GB", max(totalSpaceGB - usedSpaceGB, 0))
    }

    static let defaultValue = StoragePolicyState(
        cardStatus: .ready,
        usedSpaceGB: 74.2,
        totalSpaceGB: 128,
        estimatedHoursRemaining: "Approx. 5.5 hours remaining at current 1080p quality.",
        autoCleanupEnabled: false,
        autoOverwriteEnabled: true,
        lockedEventRetention: .keepForever,
        reservedEventSpacePercent: 20
    )
}

struct WatermarkConfigurationState: Equatable {
    var timestampEnabled: Bool
    var licensePlateEnabled: Bool
    var licensePlate: String

    static let defaultValue = WatermarkConfigurationState(
        timestampEnabled: true,
        licensePlateEnabled: true,
        licensePlate: "AB-123-CD"
    )
}

struct NetworkIdentityState: Equatable {
    var networkName: String
    var password: String

    static func defaultValue(networkName: String) -> NetworkIdentityState {
        NetworkIdentityState(
            networkName: networkName,
            password: "dashcamsecure"
        )
    }
}

enum SpeakerVolumeOption: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct DevicePreferencesState: Equatable {
    var deviceName: String
    var connectionName: String
    var firmwareVersion: String
    var timeZone: String
    var dateTime: String
    var speakerVolume: SpeakerVolumeOption
    var statusSoundsEnabled: Bool

    static func defaultValue(deviceName: String, connectionName: String) -> DevicePreferencesState {
        DevicePreferencesState(
            deviceName: deviceName,
            connectionName: connectionName,
            firmwareVersion: "v2.4.1",
            timeZone: "UTC+8 (Asia/Shanghai)",
            dateTime: "2026-04-24 10:30",
            speakerVolume: .medium,
            statusSoundsEnabled: true
        )
    }
}

enum SafetySensitivityOption: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum EventClipDurationOption: String, CaseIterable {
    case fifteenSeconds = "15s"
    case thirtySeconds = "30s"
    case sixtySeconds = "60s"
}

struct SafetySettingsState: Equatable {
    var gSensorSensitivity: SafetySensitivityOption
    var emergencyVideoLockEnabled: Bool
    var parkingModeEnabled: Bool
    var motionDetectionEnabled: Bool
    var impactDetectionEnabled: Bool
    var eventClipDuration: EventClipDurationOption
    var eventNotificationsEnabled: Bool

    static let defaultValue = SafetySettingsState(
        gSensorSensitivity: .medium,
        emergencyVideoLockEnabled: true,
        parkingModeEnabled: true,
        motionDetectionEnabled: true,
        impactDetectionEnabled: true,
        eventClipDuration: .thirtySeconds,
        eventNotificationsEnabled: true
    )
}

enum FirmwareUpdateStage: Equatable {
    case available
    case downloading(progress: Double, downloadedSize: String, remainingTime: String)
    case failed
}

extension RecordingQualityPriorityOption {
    nonisolated var protocolValue: String {
        rawValue.lowercased()
    }

    nonisolated static func protocolValue(_ value: String) -> RecordingQualityPriorityOption? {
        allCases.first { $0.protocolValue == value.lowercased() }
    }
}

extension LoopRecordingDurationOption {
    var minutes: Int {
        switch self {
        case .oneMinute:
            return 1
        case .threeMinutes:
            return 3
        case .fiveMinutes:
            return 5
        }
    }

    static func minutes(_ value: Int) -> LoopRecordingDurationOption? {
        allCases.first { $0.minutes == value }
    }
}

extension RecordingStartBehaviorOption {
    nonisolated var protocolValue: String {
        rawValue.lowercased()
    }

    nonisolated static func protocolValue(_ value: String) -> RecordingStartBehaviorOption? {
        allCases.first { $0.protocolValue == value.lowercased() }
    }
}

extension LockedEventRetentionOption {
    nonisolated var protocolValue: String {
        switch self {
        case .keepForever:
            return "forever"
        case .thirtyDays:
            return "days:30"
        case .sevenDays:
            return "days:7"
        }
    }

    nonisolated static func protocolValue(_ value: String) -> LockedEventRetentionOption? {
        switch value.lowercased() {
        case "forever":
            return .keepForever
        case "days:30":
            return .thirtyDays
        case "days:7":
            return .sevenDays
        default:
            return nil
        }
    }
}

extension StorageCardStatus {
    nonisolated static func protocolValue(_ value: String) -> StorageCardStatus {
        switch value.lowercased() {
        case "missing", "no_card":
            return .noCard
        case "error":
            return .error
        default:
            return .ready
        }
    }
}

extension SafetySensitivityOption {
    nonisolated var protocolValue: String {
        rawValue.lowercased()
    }

    nonisolated static func protocolValue(_ value: String) -> SafetySensitivityOption? {
        allCases.first { $0.protocolValue == value.lowercased() }
    }
}

extension EventClipDurationOption {
    var seconds: Int {
        switch self {
        case .fifteenSeconds:
            return 15
        case .thirtySeconds:
            return 30
        case .sixtySeconds:
            return 60
        }
    }

    static func seconds(_ value: Int) -> EventClipDurationOption? {
        allCases.first { $0.seconds == value }
    }
}

extension SpeakerVolumeOption {
    nonisolated var protocolValue: String {
        rawValue.lowercased()
    }

    nonisolated static func protocolValue(_ value: String) -> SpeakerVolumeOption? {
        allCases.first { $0.protocolValue == value.lowercased() }
    }
}
