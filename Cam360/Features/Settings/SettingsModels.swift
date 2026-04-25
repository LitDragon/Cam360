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
        usedSpaceGB: 18.8,
        totalSpaceGB: 72.4,
        estimatedHoursRemaining: "Approx. 1.5 hours",
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
