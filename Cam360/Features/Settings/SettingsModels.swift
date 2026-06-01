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
    var resolutionOptions: [RecordingResolutionOption]
    var qualityPriority: RecordingQualityPriorityOption
    var qualityPriorityOptions: [RecordingQualityPriorityOption]
    var loopDuration: LoopRecordingDurationOption
    var loopDurationOptions: [LoopRecordingDurationOption]
    var autoOverwrite: Bool
    var startBehavior: RecordingStartBehaviorOption
    var audioRecordingEnabled: Bool
    var hdrNightRecordingEnabled: Bool
    var recordingStatusIndicatorEnabled: Bool
    var recordingReminderEnabled: Bool
    var estimatedStoragePerHour: String

    static let defaultValue = RecordingSettingsState(
        resolution: .fullHD,
        resolutionOptions: RecordingResolutionOption.allCases,
        qualityPriority: .balanced,
        qualityPriorityOptions: RecordingQualityPriorityOption.allCases,
        loopDuration: .threeMinutes,
        loopDurationOptions: LoopRecordingDurationOption.allCases,
        autoOverwrite: true,
        startBehavior: .auto,
        audioRecordingEnabled: false,
        hdrNightRecordingEnabled: true,
        recordingStatusIndicatorEnabled: true,
        recordingReminderEnabled: false,
        estimatedStoragePerHour: "Estimated storage per hour: ~4.2 GB"
    )
}

enum StorageCardStatus: String, CaseIterable {
    case ready = "Ready"
    case noCard = "No Card"
    case error = "Error"
}

enum SettingsHomeCategory: String, CaseIterable {
    case recording
    case safety
    case storage
    case watermark
    case wifi
    case systemPreferences = "system_preferences"
}

enum StorageFormatStage: Equatable {
    case idle
    case inProgress(progress: Double)
    case completed
    case failed
}

enum LockedEventRetentionOption: String, CaseIterable {
    case keepForever = "Keep Forever"
    case thirtyDays = "30 Days"
    case sevenDays = "7 Days"
}

struct StoragePolicyState: Equatable {
    var cardStatus: StorageCardStatus
    var cardErrorDescription: String
    var usedSpaceGB: Double
    var totalSpaceGB: Double
    var usagePercent: Int?
    var estimatedHoursRemaining: String
    var autoCleanupEnabled: Bool
    var autoCleanupRetentionDays: Int
    var autoOverwriteEnabled: Bool
    var lockedEventRetention: LockedEventRetentionOption
    var reservedEventSpacePercent: Int
    var formatStage: StorageFormatStage
    var formatRequired: Bool
    var formatSupported: Bool
    var policyEditable: Bool

    var usageProgress: Double {
        if let usagePercent {
            return min(max(Double(usagePercent) / 100, 0), 1)
        }

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

    var canFormat: Bool {
        formatSupported && (cardStatus == .ready || formatRequired)
    }

    var canEditPolicies: Bool {
        cardStatus == .ready && policyEditable
    }

    static let defaultValue = StoragePolicyState(
        cardStatus: .ready,
        cardErrorDescription: "The inserted SD card is unreadable or has a file system error. Formatting is required to use this card for recording.",
        usedSpaceGB: 74.2,
        totalSpaceGB: 128,
        usagePercent: nil,
        estimatedHoursRemaining: "Approx. 5.5 hours remaining at current 1080p quality.",
        autoCleanupEnabled: false,
        autoCleanupRetentionDays: 30,
        autoOverwriteEnabled: true,
        lockedEventRetention: .keepForever,
        reservedEventSpacePercent: 20,
        formatStage: .idle,
        formatRequired: false,
        formatSupported: true,
        policyEditable: true
    )
}

enum WatermarkPositionOption: String, CaseIterable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
}

struct WatermarkConfigurationState: Equatable {
    var timestampEnabled: Bool
    var licensePlateEnabled: Bool
    var licensePlate: String
    var position: WatermarkPositionOption

    static let defaultValue = WatermarkConfigurationState(
        timestampEnabled: true,
        licensePlateEnabled: true,
        licensePlate: "AB1234CD",
        position: .bottomRight
    )
}

struct NetworkIdentityState: Equatable {
    var networkName: String
    var password: String
    var statusCode: Int?

    static func defaultValue(networkName: String) -> NetworkIdentityState {
        NetworkIdentityState(
            networkName: networkName,
            password: "dashcamsecure",
            statusCode: nil
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
    var deviceNameEditable: Bool
    var connectionName: String
    var connectionStatus: String
    var firmwareVersion: String
    var firmwareUpdateEntryEnabled: Bool
    var factoryResetSupported: Bool
    var timeZone: String
    var dateTime: String
    var language: String
    var dateTimeAutoSyncEnabled: Bool
    var speakerVolume: SpeakerVolumeOption
    var speakerVolumeOptions: [SpeakerVolumeOption]
    var statusSoundsEnabled: Bool

    static func defaultValue(deviceName: String, connectionName: String) -> DevicePreferencesState {
        DevicePreferencesState(
            deviceName: deviceName,
            deviceNameEditable: true,
            connectionName: connectionName,
            connectionStatus: "connected",
            firmwareVersion: "v2.4.1",
            firmwareUpdateEntryEnabled: true,
            factoryResetSupported: true,
            timeZone: "UTC+8 (Asia/Shanghai)",
            dateTime: "2026-04-24 10:30",
            language: "zh-CN",
            dateTimeAutoSyncEnabled: true,
            speakerVolume: .medium,
            speakerVolumeOptions: SpeakerVolumeOption.allCases,
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
    var gSensorSensitivityOptions: [SafetySensitivityOption]
    var emergencyVideoLockEnabled: Bool
    var parkingModeEnabled: Bool
    var motionDetectionEnabled: Bool
    var impactDetectionEnabled: Bool
    var eventClipDuration: EventClipDurationOption
    var eventClipDurationOptions: [EventClipDurationOption]
    var eventNotificationsEnabled: Bool

    static let defaultValue = SafetySettingsState(
        gSensorSensitivity: .medium,
        gSensorSensitivityOptions: SafetySensitivityOption.allCases,
        emergencyVideoLockEnabled: true,
        parkingModeEnabled: true,
        motionDetectionEnabled: true,
        impactDetectionEnabled: true,
        eventClipDuration: .thirtySeconds,
        eventClipDurationOptions: EventClipDurationOption.allCases,
        eventNotificationsEnabled: true
    )
}

enum FirmwareUpdateStage: Equatable {
    case unavailable(message: String)
    case available
    case inProgress(progress: Double, stageTitle: String)
    case completed
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
    nonisolated var minutes: Int {
        switch self {
        case .oneMinute:
            return 1
        case .threeMinutes:
            return 3
        case .fiveMinutes:
            return 5
        }
    }

    nonisolated static func minutes(_ value: Int) -> LoopRecordingDurationOption? {
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
    nonisolated var seconds: Int {
        switch self {
        case .fifteenSeconds:
            return 15
        case .thirtySeconds:
            return 30
        case .sixtySeconds:
            return 60
        }
    }

    nonisolated static func seconds(_ value: Int) -> EventClipDurationOption? {
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

extension WatermarkPositionOption {
    nonisolated var protocolValue: String {
        switch self {
        case .topLeft:
            return "top_left"
        case .topRight:
            return "top_right"
        case .bottomLeft:
            return "bottom_left"
        case .bottomRight:
            return "bottom_right"
        }
    }

    nonisolated static func protocolValue(_ value: String) -> WatermarkPositionOption? {
        allCases.first { $0.protocolValue == value.lowercased() }
    }
}
