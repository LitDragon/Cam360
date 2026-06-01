import Foundation

struct DeviceProtocolCommand: Equatable {
    let topic: String
    let operation: DeviceProtocolOperation
    let parameters: [String: DeviceProtocolValue]
    let timeout: TimeInterval

    init(
        topic: String,
        operation: DeviceProtocolOperation,
        parameters: [String: DeviceProtocolValue] = [:],
        timeout: TimeInterval = 10
    ) {
        self.topic = topic
        self.operation = operation
        self.parameters = parameters
        self.timeout = timeout
    }

    func message(messageID: String) -> DeviceProtocolMessage {
        DeviceProtocolMessage(
            topic: topic,
            operation: operation,
            messageID: messageID,
            parameters: parameters
        )
    }

    func withTimeout(_ timeout: TimeInterval) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: topic,
            operation: operation,
            parameters: parameters,
            timeout: timeout
        )
    }
}

extension DeviceProtocolCommand {
    static func appAccess(appVersion: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "APP_ACCESS",
            operation: .post,
            parameters: [
                "type": 1,
                "ver": .string(appVersion),
                "protocol_ver": "1.2"
            ]
        )
    }

    static let protocolVersion = DeviceProtocolCommand(topic: "PROTOCOL_VERSION", operation: .get)
    static func openApp(page: String = "home") -> DeviceProtocolCommand {
        var parameters: [String: DeviceProtocolValue] = [:]
        if let page = normalizedNonEmptyProtocolString(page) {
            parameters["page"] = .string(page)
        }
        return DeviceProtocolCommand(topic: "CTP_CMD_OPENAPP", operation: .post, parameters: parameters)
    }

    static let uuid = DeviceProtocolCommand(topic: "UUID", operation: .get)
    static let firmwareVersion = DeviceProtocolCommand(topic: "FW_VERSION", operation: .get)
    static let deviceInfo = DeviceProtocolCommand(topic: "DEVICE_INFO", operation: .get)
    static let realtimeGPSData = DeviceProtocolCommand(topic: "VI_GPS_RTDATA", operation: .get)
    static let sdStatus = DeviceProtocolCommand(topic: "SD_STATUS", operation: .get)
    static let batteryStatus = DeviceProtocolCommand(topic: "BAT_STATUS", operation: .get)
    static let tfCapacity = DeviceProtocolCommand(topic: "TF_CAP", operation: .get)
    static let cameraCapability = DeviceProtocolCommand(topic: "CAMERA_CAPABILITY", operation: .get)

    static func exitApp(reason: String = "user_leave") -> DeviceProtocolCommand {
        var parameters: [String: DeviceProtocolValue] = [:]
        if let reason = normalizedNonEmptyProtocolString(reason) {
            parameters["reason"] = .string(reason)
        }
        return DeviceProtocolCommand(topic: "CTP_CMD_EXITAPP", operation: .post, parameters: parameters)
    }

    static func heartbeat(seq: Int? = nil, clientTime: String? = nil) -> DeviceProtocolCommand {
        var parameters: [String: DeviceProtocolValue] = [:]
        if let seq, seq > 0 {
            parameters["seq"] = .int(seq)
        }
        if let clientTime = normalizedProtocolTimestamp(clientTime) {
            parameters["client_time"] = .string(clientTime)
        }
        return DeviceProtocolCommand(topic: "HEARTBEAT", operation: .post, parameters: parameters)
    }

    private static func normalizedNonEmptyProtocolString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedProtocolTimestamp(_ value: String?) -> String? {
        guard let rawValue = value,
              let value = normalizedNonEmptyProtocolString(rawValue) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.isLenient = false

        guard let date = formatter.date(from: value),
              formatter.string(from: date) == value else {
            return nil
        }
        return value
    }

    static func stateSync(scope: DeviceStateSyncScope) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "STATE_SYNC",
            operation: .get,
            parameters: ["scope": .string(scope.rawValue)]
        )
    }

    static func mediaIndex(query: DeviceMediaIndexQuery) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "MEDIA_INDEX",
            operation: .get,
            parameters: [
                "media_type": .string(query.mediaType.rawValue),
                "group_by": .string(query.groupBy.rawValue),
                "event_only": .int(query.eventOnly ? 1 : 0),
                "page_no": .int(query.pageNo),
                "page_size": .int(query.pageSize)
            ]
        )
    }

    static func recentEvents(query: DeviceRecentEventsQuery) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "RECENT_EVENTS",
            operation: .get,
            parameters: [
                "limit": .int(query.limit),
                "event_type": .string(query.eventType),
                "include_locked_only": .int(query.includeLockedOnly ? 1 : 0)
            ]
        )
    }

    static func fileList(query: DeviceFileListQuery) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_LIST",
            operation: .get,
            parameters: [
                "type": .string(query.type.rawValue),
                "page": .int(query.page),
                "page_size": .int(query.pageSize),
                "sort_by": .string(query.sortBy),
                "sort_order": .string(query.sortOrder)
            ]
        )
    }

    static func fileInfo(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_INFO",
            operation: .get,
            parameters: ["path": .string(path)]
        )
    }

    static func deleteFile(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_DELETE",
            operation: .post,
            parameters: ["path": .string(path)]
        )
    }

    static func setFileLocked(path: String, locked: Bool = true) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_LOCK",
            operation: .post,
            parameters: [
                "file": .string(path),
                "status": .int(locked ? 1 : 0)
            ]
        )
    }

    static func filePlaybackResource(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FILE_DOWNLOAD_URL",
            operation: .get,
            parameters: ["path": .string(path)]
        )
    }

    private static let thumbnailListPathLimit = 20

    static func thumbnailList(paths: [String]) -> DeviceProtocolCommand {
        let limitedPaths = paths.prefix(Self.thumbnailListPathLimit)
        return DeviceProtocolCommand(
            topic: "THUMB_LIST",
            operation: .get,
            parameters: ["paths": .array(limitedPaths.map { .string($0) })]
        )
    }

    static func thumbnail(path: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "THUMB_GET",
            operation: .get,
            parameters: ["path": .string(path)]
        )
    }

    static let recordingState = DeviceProtocolCommand(topic: "VIDEO_CTRL", operation: .get)

    static let recordingConfiguration = DeviceProtocolCommand(topic: "RECORDING_CONFIG", operation: .get)
    static let safetyConfiguration = DeviceProtocolCommand(topic: "SAFETY_CONFIG", operation: .get)
    static let storagePolicyConfiguration = DeviceProtocolCommand(topic: "STORAGE_POLICY_CONFIG", operation: .get)
    static let systemPreferencesConfiguration = DeviceProtocolCommand(topic: "SYSTEM_PREFERENCES_CONFIG", operation: .get)
    static let watermarkConfiguration = DeviceProtocolCommand(topic: "WATERMARK_CONFIG", operation: .get)

    static func updateRecordingConfiguration(parameters: [String: DeviceProtocolValue]) -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "RECORDING_CONFIG", operation: .post, parameters: parameters)
    }

    static func updateSafetyConfiguration(parameters: [String: DeviceProtocolValue]) -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "SAFETY_CONFIG", operation: .post, parameters: parameters)
    }

    static func updateStoragePolicyConfiguration(parameters: [String: DeviceProtocolValue]) -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "STORAGE_POLICY_CONFIG", operation: .post, parameters: parameters)
    }

    static func updateSystemPreferencesConfiguration(parameters: [String: DeviceProtocolValue]) -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "SYSTEM_PREFERENCES_CONFIG", operation: .post, parameters: parameters)
    }

    static func updateWatermarkConfiguration(parameters: [String: DeviceProtocolValue]) -> DeviceProtocolCommand {
        DeviceProtocolCommand(topic: "WATERMARK_CONFIG", operation: .post, parameters: parameters)
    }

    static let accessPointIdentity = DeviceProtocolCommand(topic: "AP_SSID_INFO", operation: .get)

    static func updateAccessPointIdentity(ssid: String, password: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "AP_SSID_INFO",
            operation: .post,
            parameters: [
                "ssid": .string(ssid),
                "pwd": .string(password),
                "status": .int(1)
            ]
        )
    }

    static func setRecording(enabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_CTRL",
            operation: .post,
            parameters: ["status": .int(enabled ? 1 : 0)]
        )
    }

    static func snapshotControl(mode: DeviceSnapshotMode = .preview) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SNAPSHOT_CTRL",
            operation: .post,
            parameters: ["mode": .string(mode.rawValue)]
        )
    }

    static func snapshotData(snapshotID: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SNAPSHOT_DATA",
            operation: .get,
            parameters: ["snapshot_id": .string(snapshotID)]
        )
    }

    static func syncDateTime(date: String, timeZoneOffsetMinutes: Int) -> DeviceProtocolCommand {
        let normalizedDate = normalizedProtocolTimestamp(date) ?? date
        return DeviceProtocolCommand(
            topic: "DATE_TIME",
            operation: .post,
            parameters: [
                "date": .string(normalizedDate),
                "tz_offset_min": .int(timeZoneOffsetMinutes)
            ]
        )
    }

    static let hourType = DeviceProtocolCommand(topic: "HOUR_TYPE", operation: .get)

    static func updateHourType(_ type: DeviceHourType) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "HOUR_TYPE",
            operation: .post,
            parameters: ["type": .int(type.rawValue)]
        )
    }

    static let videoSize = DeviceProtocolCommand(topic: "VIDEO_SIZE", operation: .get)

    static func updateVideoSize(
        supportedResolutions: [String],
        selectedIndex: Int
    ) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_SIZE",
            operation: .post,
            parameters: [
                "str": .string(supportedResolutions.joined(separator: ";")),
                "val": .int(selectedIndex)
            ]
        )
    }

    static let videoLoop = DeviceProtocolCommand(topic: "VIDEO_LOOP", operation: .get)

    static func updateVideoLoop(_ cycle: DeviceVideoLoopCycle) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_LOOP",
            operation: .post,
            parameters: ["cyc": .int(cycle.rawValue)]
        )
    }

    static let videoMicrophone = DeviceProtocolCommand(topic: "VIDEO_MIC", operation: .get)

    static func updateVideoMicrophone(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_MIC",
            operation: .post,
            parameters: ["mic": .int(isEnabled ? 1 : 0)]
        )
    }

    static let videoWideDynamicRange = DeviceProtocolCommand(topic: "VIDEO_WDR", operation: .get)

    static func updateVideoWideDynamicRange(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_WDR",
            operation: .post,
            parameters: ["wdr": .int(isEnabled ? 1 : 0)]
        )
    }

    static let videoExposure = DeviceProtocolCommand(topic: "VIDEO_EXP", operation: .get)

    static func updateVideoExposure(_ level: DeviceVideoExposureLevel) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_EXP",
            operation: .post,
            parameters: ["exp": .int(level.rawValue)]
        )
    }

    static let collisionSensitivity = DeviceProtocolCommand(topic: "GRA_SEN", operation: .get)

    static func updateCollisionSensitivity(_ sensitivity: DeviceCollisionSensitivity) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "GRA_SEN",
            operation: .post,
            parameters: ["gra": .int(sensitivity.rawValue)]
        )
    }

    static let motionDetection = DeviceProtocolCommand(topic: "MOVE_CHECK", operation: .get)

    static func updateMotionDetection(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "MOVE_CHECK",
            operation: .post,
            parameters: ["mot": .int(isEnabled ? 1 : 0)]
        )
    }

    static let parkingMonitorMode = DeviceProtocolCommand(topic: "MONITOR_MODE", operation: .get)

    static func updateParkingMonitorMode(_ mode: DeviceParkingMonitorMode) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "MONITOR_MODE",
            operation: .post,
            parameters: ["mode": .int(mode.rawValue)]
        )
    }

    static let parkingMonitorDuration = DeviceProtocolCommand(topic: "MONITOR_TIME", operation: .get)

    static func updateParkingMonitorDuration(_ duration: DeviceParkingMonitorDuration) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "MONITOR_TIME",
            operation: .post,
            parameters: ["gaplen": .int(duration.rawValue)]
        )
    }

    static let voltageProtection = DeviceProtocolCommand(topic: "VOLTAGE_PRO", operation: .get)

    static func updateVoltageProtection(_ threshold: DeviceVoltageProtectionThreshold) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VOLTAGE_PRO",
            operation: .post,
            parameters: ["vpr": .int(threshold.rawValue)]
        )
    }

    static let videoDateWatermark = DeviceProtocolCommand(topic: "VIDEO_DATE", operation: .get)

    static func updateVideoDateWatermark(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_DATE",
            operation: .post,
            parameters: ["dat": .int(isEnabled ? 1 : 0)]
        )
    }

    static let horizontalMirror = DeviceProtocolCommand(topic: "MIRROR_HOR", operation: .get)

    static func updateHorizontalMirror(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "MIRROR_HOR",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let verticalFlip = DeviceProtocolCommand(topic: "FLIP_VER", operation: .get)

    static func updateVerticalFlip(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "FLIP_VER",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let autoShutdown = DeviceProtocolCommand(topic: "AUTO_SHUTDOWN", operation: .get)

    static func updateAutoShutdown(_ delay: DeviceAutoShutdownDelay) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "AUTO_SHUTDOWN",
            operation: .post,
            parameters: ["aff": .int(delay.rawValue)]
        )
    }

    static let screenProtection = DeviceProtocolCommand(topic: "SCREEN_PRO", operation: .get)

    static func updateScreenProtection(_ delay: DeviceScreenProtectionDelay) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SCREEN_PRO",
            operation: .post,
            parameters: ["pro": .int(delay.rawValue)]
        )
    }

    static let videoParameter = DeviceProtocolCommand(topic: "VIDEO_PARAM", operation: .get)

    static func updateVideoParameter(
        width: Int,
        height: Int,
        encodingFormat: DeviceVideoEncodingFormat
    ) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_PARAM",
            operation: .post,
            parameters: [
                "w": .int(width),
                "h": .int(height),
                "format": .int(encodingFormat.rawValue)
            ]
        )
    }

    static let photoResolution = DeviceProtocolCommand(topic: "PHOTO_RESO", operation: .get)

    static func updatePhotoResolution(_ resolution: String) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "PHOTO_RESO",
            operation: .post,
            parameters: ["reso": .string(resolution)]
        )
    }

    static let photoQuality = DeviceProtocolCommand(topic: "PHOTO_QUALITY", operation: .get)

    static func updatePhotoQuality(_ quality: DevicePhotoQuality) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "PHOTO_QUALITY",
            operation: .post,
            parameters: ["quality": .string(quality.rawValue)]
        )
    }

    static let photoDateWatermark = DeviceProtocolCommand(topic: "PHOTO_DATE", operation: .get)

    static func updatePhotoDateWatermark(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "PHOTO_DATE",
            operation: .post,
            parameters: ["date": .int(isEnabled ? 1 : 0)]
        )
    }

    static let tvMode = DeviceProtocolCommand(topic: "TV_MODE", operation: .get)

    static func updateTVMode(_ mode: DeviceTVMode) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "TV_MODE",
            operation: .post,
            parameters: ["mode": .string(mode.rawValue)]
        )
    }

    static let parkingGuard = DeviceProtocolCommand(topic: "VIDEO_PAR_CAR", operation: .get)

    static func updateParkingGuard(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_PAR_CAR",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let parkingCollisionSensitivity = DeviceProtocolCommand(topic: "VIDEO_PAR_VSIX", operation: .get)

    static func updateParkingCollisionSensitivity(
        _ sensitivity: DeviceParkingCollisionSensitivity
    ) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_PAR_VSIX",
            operation: .post,
            parameters: ["level": .int(sensitivity.rawValue)]
        )
    }

    static let intervalRecording = DeviceProtocolCommand(topic: "VIDEO_INV", operation: .get)

    static func updateIntervalRecording(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_INV",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let gpsTimeSync = DeviceProtocolCommand(topic: "VIDEO_SYNC", operation: .get)

    static func updateGPSTimeSync(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_SYNC",
            operation: .post,
            parameters: ["sync": .int(isEnabled ? 1 : 0)]
        )
    }

    static let drivingRestReminder = DeviceProtocolCommand(topic: "VIDEO_RDER", operation: .get)

    static func updateDrivingRestReminder(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "VIDEO_RDER",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let lightFrequency = DeviceProtocolCommand(topic: "LIGHT_FRE", operation: .get)

    static func updateLightFrequency(_ frequency: DeviceLightFrequency) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "LIGHT_FRE",
            operation: .post,
            parameters: ["freq": .string(frequency.rawValue)]
        )
    }

    static let speakerVolume = DeviceProtocolCommand(topic: "SPEAKER_VOLUME", operation: .get)

    static func updateSpeakerVolume(_ volume: Int) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SPEAKER_VOLUME",
            operation: .post,
            parameters: ["volume": .int(volume)]
        )
    }

    static let speech = DeviceProtocolCommand(topic: "SPEECH", operation: .get)

    static func updateSpeech(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "SPEECH",
            operation: .post,
            parameters: ["speech": .int(isEnabled ? 1 : 0)]
        )
    }

    static let keyVoice = DeviceProtocolCommand(topic: "KEY_VOICE", operation: .get)

    static func updateKeyVoice(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "KEY_VOICE",
            operation: .post,
            parameters: ["voice": .int(isEnabled ? 1 : 0)]
        )
    }

    static let antiTremor = DeviceProtocolCommand(topic: "ANTI_TREMOR", operation: .get)

    static func updateAntiTremor(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "ANTI_TREMOR",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let electronicDogVoice = DeviceProtocolCommand(topic: "EDOG_VOICE", operation: .get)

    static func updateElectronicDogVoice(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "EDOG_VOICE",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let infraredLight = DeviceProtocolCommand(topic: "IR_SWITCH", operation: .get)

    static func updateInfraredLight(isEnabled: Bool) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "IR_SWITCH",
            operation: .post,
            parameters: ["status": .int(isEnabled ? 1 : 0)]
        )
    }

    static let formatStorage = DeviceProtocolCommand(topic: "FORMAT", operation: .post)

    static let restoreDefaultConfiguration = DeviceProtocolCommand(
        topic: "SYSTEM_DEFAULT",
        operation: .post,
        parameters: ["def": .int(1)]
    )

    static func firmwareUpgradeCheck(candidate: DeviceFirmwareUpgradeCandidate) -> DeviceProtocolCommand {
        var parameters: [String: DeviceProtocolValue] = [
            "latest_version": .string(candidate.latestVersion),
            "package_size": .int(candidate.packageSize),
            "checksum": .string(candidate.checksum),
            "rollback_index": .int(candidate.rollbackIndex),
            "signature_alg": .string(candidate.signatureAlgorithm),
            "signature": .string(candidate.signature)
        ]
        if candidate.releaseNotes.isEmpty == false {
            parameters["release_notes"] = .array(candidate.releaseNotes.map { .string($0) })
        }

        return DeviceProtocolCommand(
            topic: "UPGRADE_CHECK",
            operation: .post,
            parameters: parameters
        )
    }

    static func startFirmwareUpgrade(package: DeviceFirmwareUpgradePackage) -> DeviceProtocolCommand {
        DeviceProtocolCommand(
            topic: "UPGRADE_CTRL",
            operation: .post,
            parameters: [
                "action": .string("start"),
                "target_version": .string(package.targetVersion),
                "package_url": .string(package.packageURL),
                "package_size": .int(package.packageSize),
                "checksum": .string(package.checksum),
                "rollback_index": .int(package.rollbackIndex),
                "signature_alg": .string(package.signatureAlgorithm),
                "signature": .string(package.signature)
            ]
        )
    }
}

struct DeviceProtocolHandshakePlan {
    let appVersion: String
    let commandTimeout: TimeInterval

    init(appVersion: String, commandTimeout: TimeInterval = 10) {
        self.appVersion = appVersion
        self.commandTimeout = commandTimeout
    }

    var commands: [DeviceProtocolCommand] {
        let baseCommands: [DeviceProtocolCommand] = [
            .appAccess(appVersion: appVersion),
            .openApp(),
            .protocolVersion,
            .uuid,
            .firmwareVersion,
            .sdStatus,
            .batteryStatus,
            .tfCapacity,
            .cameraCapability
        ]

        return baseCommands.map { $0.withTimeout(commandTimeout) }
    }
}
