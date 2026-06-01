import Foundation
import Combine

protocol DeviceSessionProtocolClient: AnyObject {
    var onEvent: ((DeviceProtocolMessage) -> Void)? { get set }
    var onDisconnect: ((DeviceProtocolError?) -> Void)? { get set }

    func connect(completion: @escaping (Result<Void, DeviceProtocolError>) -> Void)
    func startHandshake(
        appVersion: String,
        commandTimeout: TimeInterval,
        completion: @escaping (Result<[DeviceProtocolMessage], DeviceProtocolError>) -> Void
    )
    func send(
        _ command: DeviceProtocolCommand,
        completion: @escaping (Result<DeviceProtocolMessage, DeviceProtocolError>) -> Void
    )
    func disconnect()
}

extension DeviceProtocolClient: DeviceSessionProtocolClient {}

final class DeviceSession: ObservableObject {
    @Published private(set) var state: DeviceSessionState = .idle
    @Published private(set) var currentOperation: Operation?
    @Published private(set) var deviceStatus = DeviceSessionStatus()

    private let protocolClient: DeviceSessionProtocolClient?
    private let appVersion: String
    private let deviceName: String
    private let handshakeCommandTimeout: TimeInterval
    private var heartbeatConfiguration = DeviceSessionHeartbeatConfiguration.default
    private var heartbeatSequence = 0
    private var missedHeartbeatACKCount = 0
    private var heartbeatGeneration = 0
    private var heartbeatWorkItem: DispatchWorkItem?
    private var heartbeatTimeoutWorkItem: DispatchWorkItem?
    private var isHeartbeatAwaitingResponse = false
    private var protocolCapabilities = DeviceSessionProtocolCapabilities.unsupported
    private var previousStateBeforeRecovery: DeviceSessionState?
    private var handshakeGeneration = 0
    private var readOnlyCommandGeneration = 0
    private var controlCommandGeneration = 0

    init(
        protocolClient: DeviceSessionProtocolClient? = nil,
        appVersion: String = "1.0",
        deviceName: String = "Cam360 Device",
        handshakeCommandTimeout: TimeInterval = 10
    ) {
        self.protocolClient = protocolClient
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.handshakeCommandTimeout = handshakeCommandTimeout

        self.protocolClient?.onEvent = { [weak self] message in
            self?.handleProtocolEvent(message)
        }
        self.protocolClient?.onDisconnect = { [weak self] error in
            self?.handleProtocolDisconnect(error)
        }
    }

    func startProtocolHandshake() {
        guard case .handshaking = state else {
            return
        }

        protocolCapabilities = .unsupported

        guard let protocolClient else {
            send(.handshakeFailed(reason: "控制通道未配置"))
            return
        }

        let generation = nextHandshakeGeneration()
        send(.startHandshake)

        protocolClient.connect { [weak self] result in
            self?.handleProtocolConnect(result, generation: generation)
        }
    }

    func fetchFileList(
        query: DeviceFileListQuery = DeviceFileListQuery(),
        completion: @escaping (Result<DeviceFileListPage, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.fileList(query: query), completion: completion) { message in
            try DeviceFileResponseParser.fileListPage(from: message.parameters)
        }
    }

    func fetchDeviceBasicInfo(
        completion: @escaping (Result<DeviceBasicInfo, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.deviceInfo, completion: completion) { message in
            try DeviceFileResponseParser.deviceBasicInfo(from: message.parameters)
        }
    }

    func fetchRealtimeGPSData(
        completion: @escaping (Result<DeviceRealtimeGPSData, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.realtimeGPSData, completion: completion) { message in
            try DeviceFileResponseParser.realtimeGPSData(from: message.parameters)
        }
    }

    func fetchStateSync(
        scope: DeviceStateSyncScope,
        completion: @escaping (Result<DeviceStateSyncSnapshot, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.stateSync(scope: scope), completion: completion) { message in
            try DeviceAggregateResponseParser.stateSync(from: message.parameters)
        }
    }

    func fetchRecentEvents(
        query: DeviceRecentEventsQuery = DeviceRecentEventsQuery(),
        completion: @escaping (Result<DeviceRecentEventsPage, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.recentEvents(query: query), completion: completion) { message in
            try DeviceAggregateResponseParser.recentEvents(from: message.parameters)
        }
    }

    func fetchMediaIndex(
        query: DeviceMediaIndexQuery = DeviceMediaIndexQuery(),
        completion: @escaping (Result<DeviceMediaIndexResult, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.mediaIndex(query: query), completion: completion) { message in
            try DeviceAggregateResponseParser.mediaIndex(from: message.parameters)
        }
    }

    func fetchFileInfo(
        path: String,
        completion: @escaping (Result<DeviceFileInfo, DeviceSessionReadOnlyError>) -> Void
    ) {
        guard Self.isNonEmptyProtocolString(path) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "FILE_INFO", parameters: [:]))))
            return
        }

        performReadOnlyCommand(.fileInfo(path: path), completion: completion) { message in
            try DeviceFileResponseParser.fileInfo(from: message.parameters)
        }
    }

    func deleteFile(
        path: String,
        completion: @escaping (Result<DeviceFileDeletionResult, DeviceSessionCommandError>) -> Void
    ) {
        guard Self.isNonEmptyProtocolString(path) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "FILE_DELETE", parameters: [:]))))
            return
        }

        performControlCommand(.deleteFile(path: path), completion: completion) { message in
            try DeviceFileResponseParser.fileDeletionResult(from: message.parameters)
        }
    }

    func setFileLocked(
        path: String,
        locked: Bool = true,
        completion: @escaping (Result<DeviceFileLockResult, DeviceSessionCommandError>) -> Void
    ) {
        guard Self.isNonEmptyProtocolString(path) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "FILE_LOCK", parameters: [:]))))
            return
        }

        performControlCommand(.setFileLocked(path: path, locked: locked), completion: completion) { message in
            try DeviceFileResponseParser.fileLockResult(from: message.parameters)
        }
    }

    func fetchAccessPointIdentity(
        completion: @escaping (Result<DeviceAccessPointIdentity, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.accessPointIdentity, completion: completion) { message in
            try DeviceFileResponseParser.accessPointIdentity(from: message.parameters)
        }
    }

    func updateAccessPointIdentity(
        ssid: String,
        password: String,
        completion: @escaping (Result<DeviceAccessPointIdentity, DeviceSessionCommandError>) -> Void
    ) {
        guard Self.isValidAccessPointIdentity(ssid: ssid, password: password) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "AP_SSID_INFO", parameters: [:]))))
            return
        }

        performControlCommand(
            .updateAccessPointIdentity(ssid: ssid, password: password),
            completion: completion
        ) { message in
            try DeviceFileResponseParser.accessPointIdentity(from: message.parameters)
        }
    }

    func formatStorage(
        completion: @escaping (Result<DeviceStorageFormatResult, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.formatStorage, completion: completion) { message in
            try DeviceFileResponseParser.storageFormatResult(from: message.parameters)
        }
    }

    func restoreDefaultConfiguration(
        completion: @escaping (Result<DeviceSystemDefaultResult, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.restoreDefaultConfiguration, completion: completion) { message in
            try DeviceFileResponseParser.systemDefaultResult(from: message.parameters)
        }
    }

    func syncDateTime(
        date: String,
        timeZoneOffsetMinutes: Int,
        completion: @escaping (Result<DeviceDateTimeSyncResult, DeviceSessionCommandError>) -> Void
    ) {
        guard let normalizedDate = DeviceProtocolCommand.normalizedProtocolTimestamp(date) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "DATE_TIME", parameters: [:]))))
            return
        }

        performControlCommand(
            .syncDateTime(date: normalizedDate, timeZoneOffsetMinutes: timeZoneOffsetMinutes),
            completion: completion
        ) { message in
            try DeviceFileResponseParser.dateTimeSyncResult(from: message.parameters)
        }
    }

    func fetchHourType(
        completion: @escaping (Result<DeviceHourTypeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.hourType, completion: completion) { message in
            try DeviceFileResponseParser.hourTypeSetting(from: message.parameters)
        }
    }

    func updateHourType(
        _ type: DeviceHourType,
        completion: @escaping (Result<DeviceHourTypeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateHourType(type), completion: completion) { message in
            try DeviceFileResponseParser.hourTypeSetting(from: message.parameters)
        }
    }

    func fetchVideoSize(
        completion: @escaping (Result<DeviceVideoSizeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoSize, completion: completion) { message in
            try DeviceFileResponseParser.videoSizeSetting(from: message.parameters)
        }
    }

    func updateVideoSize(
        supportedResolutions: [String],
        selectedIndex: Int,
        completion: @escaping (Result<DeviceVideoSizeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(
            .updateVideoSize(supportedResolutions: supportedResolutions, selectedIndex: selectedIndex),
            completion: completion
        ) { message in
            try DeviceFileResponseParser.videoSizeSetting(from: message.parameters)
        }
    }

    func fetchVideoLoop(
        completion: @escaping (Result<DeviceVideoLoopSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoLoop, completion: completion) { message in
            try DeviceFileResponseParser.videoLoopSetting(from: message.parameters)
        }
    }

    func updateVideoLoop(
        _ cycle: DeviceVideoLoopCycle,
        completion: @escaping (Result<DeviceVideoLoopSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVideoLoop(cycle), completion: completion) { message in
            try DeviceFileResponseParser.videoLoopSetting(from: message.parameters)
        }
    }

    func fetchVideoMicrophone(
        completion: @escaping (Result<DeviceVideoMicrophoneSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoMicrophone, completion: completion) { message in
            try DeviceFileResponseParser.videoMicrophoneSetting(from: message.parameters)
        }
    }

    func updateVideoMicrophone(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceVideoMicrophoneSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVideoMicrophone(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.videoMicrophoneSetting(from: message.parameters)
        }
    }

    func fetchVideoWideDynamicRange(
        completion: @escaping (Result<DeviceVideoWideDynamicRangeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoWideDynamicRange, completion: completion) { message in
            try DeviceFileResponseParser.videoWideDynamicRangeSetting(from: message.parameters)
        }
    }

    func updateVideoWideDynamicRange(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceVideoWideDynamicRangeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVideoWideDynamicRange(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.videoWideDynamicRangeSetting(from: message.parameters)
        }
    }

    func fetchVideoExposure(
        completion: @escaping (Result<DeviceVideoExposureSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoExposure, completion: completion) { message in
            try DeviceFileResponseParser.videoExposureSetting(from: message.parameters)
        }
    }

    func updateVideoExposure(
        _ level: DeviceVideoExposureLevel,
        completion: @escaping (Result<DeviceVideoExposureSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVideoExposure(level), completion: completion) { message in
            try DeviceFileResponseParser.videoExposureSetting(from: message.parameters)
        }
    }

    func fetchCollisionSensitivity(
        completion: @escaping (Result<DeviceCollisionSensitivitySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.collisionSensitivity, completion: completion) { message in
            try DeviceFileResponseParser.collisionSensitivitySetting(from: message.parameters)
        }
    }

    func updateCollisionSensitivity(
        _ sensitivity: DeviceCollisionSensitivity,
        completion: @escaping (Result<DeviceCollisionSensitivitySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateCollisionSensitivity(sensitivity), completion: completion) { message in
            try DeviceFileResponseParser.collisionSensitivitySetting(from: message.parameters)
        }
    }

    func fetchMotionDetection(
        completion: @escaping (Result<DeviceMotionDetectionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.motionDetection, completion: completion) { message in
            try DeviceFileResponseParser.motionDetectionSetting(from: message.parameters)
        }
    }

    func updateMotionDetection(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceMotionDetectionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateMotionDetection(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.motionDetectionSetting(from: message.parameters)
        }
    }

    func fetchParkingMonitorMode(
        completion: @escaping (Result<DeviceParkingMonitorModeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.parkingMonitorMode, completion: completion) { message in
            try DeviceFileResponseParser.parkingMonitorModeSetting(from: message.parameters)
        }
    }

    func updateParkingMonitorMode(
        _ mode: DeviceParkingMonitorMode,
        completion: @escaping (Result<DeviceParkingMonitorModeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateParkingMonitorMode(mode), completion: completion) { message in
            try DeviceFileResponseParser.parkingMonitorModeSetting(from: message.parameters)
        }
    }

    func fetchParkingMonitorDuration(
        completion: @escaping (Result<DeviceParkingMonitorDurationSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.parkingMonitorDuration, completion: completion) { message in
            try DeviceFileResponseParser.parkingMonitorDurationSetting(from: message.parameters)
        }
    }

    func updateParkingMonitorDuration(
        _ duration: DeviceParkingMonitorDuration,
        completion: @escaping (Result<DeviceParkingMonitorDurationSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateParkingMonitorDuration(duration), completion: completion) { message in
            try DeviceFileResponseParser.parkingMonitorDurationSetting(from: message.parameters)
        }
    }

    func fetchVoltageProtection(
        completion: @escaping (Result<DeviceVoltageProtectionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.voltageProtection, completion: completion) { message in
            try DeviceFileResponseParser.voltageProtectionSetting(from: message.parameters)
        }
    }

    func updateVoltageProtection(
        _ threshold: DeviceVoltageProtectionThreshold,
        completion: @escaping (Result<DeviceVoltageProtectionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVoltageProtection(threshold), completion: completion) { message in
            try DeviceFileResponseParser.voltageProtectionSetting(from: message.parameters)
        }
    }

    func fetchVideoDateWatermark(
        completion: @escaping (Result<DeviceVideoDateWatermarkSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoDateWatermark, completion: completion) { message in
            try DeviceFileResponseParser.videoDateWatermarkSetting(from: message.parameters)
        }
    }

    func updateVideoDateWatermark(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceVideoDateWatermarkSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVideoDateWatermark(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.videoDateWatermarkSetting(from: message.parameters)
        }
    }

    func fetchHorizontalMirror(
        completion: @escaping (Result<DeviceHorizontalMirrorSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.horizontalMirror, completion: completion) { message in
            try DeviceFileResponseParser.horizontalMirrorSetting(from: message.parameters)
        }
    }

    func updateHorizontalMirror(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceHorizontalMirrorSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateHorizontalMirror(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.horizontalMirrorSetting(from: message.parameters)
        }
    }

    func fetchVerticalFlip(
        completion: @escaping (Result<DeviceVerticalFlipSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.verticalFlip, completion: completion) { message in
            try DeviceFileResponseParser.verticalFlipSetting(from: message.parameters)
        }
    }

    func updateVerticalFlip(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceVerticalFlipSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateVerticalFlip(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.verticalFlipSetting(from: message.parameters)
        }
    }

    func fetchAutoShutdown(
        completion: @escaping (Result<DeviceAutoShutdownSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.autoShutdown, completion: completion) { message in
            try DeviceFileResponseParser.autoShutdownSetting(from: message.parameters)
        }
    }

    func updateAutoShutdown(
        _ delay: DeviceAutoShutdownDelay,
        completion: @escaping (Result<DeviceAutoShutdownSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateAutoShutdown(delay), completion: completion) { message in
            try DeviceFileResponseParser.autoShutdownSetting(from: message.parameters)
        }
    }

    func fetchScreenProtection(
        completion: @escaping (Result<DeviceScreenProtectionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.screenProtection, completion: completion) { message in
            try DeviceFileResponseParser.screenProtectionSetting(from: message.parameters)
        }
    }

    func updateScreenProtection(
        _ delay: DeviceScreenProtectionDelay,
        completion: @escaping (Result<DeviceScreenProtectionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateScreenProtection(delay), completion: completion) { message in
            try DeviceFileResponseParser.screenProtectionSetting(from: message.parameters)
        }
    }

    func fetchVideoParameter(
        completion: @escaping (Result<DeviceVideoParameterSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.videoParameter, completion: completion) { message in
            try DeviceFileResponseParser.videoParameterSetting(from: message.parameters)
        }
    }

    func updateVideoParameter(
        width: Int,
        height: Int,
        encodingFormat: DeviceVideoEncodingFormat,
        completion: @escaping (Result<DeviceVideoParameterSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(
            .updateVideoParameter(
                width: width,
                height: height,
                encodingFormat: encodingFormat
            ),
            completion: completion
        ) { message in
            try DeviceFileResponseParser.videoParameterSetting(from: message.parameters)
        }
    }

    func fetchPhotoResolution(
        completion: @escaping (Result<DevicePhotoResolutionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.photoResolution, completion: completion) { message in
            try DeviceFileResponseParser.photoResolutionSetting(from: message.parameters)
        }
    }

    func updatePhotoResolution(
        _ resolution: String,
        completion: @escaping (Result<DevicePhotoResolutionSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updatePhotoResolution(resolution), completion: completion) { message in
            try DeviceFileResponseParser.photoResolutionSetting(from: message.parameters)
        }
    }

    func fetchPhotoQuality(
        completion: @escaping (Result<DevicePhotoQualitySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.photoQuality, completion: completion) { message in
            try DeviceFileResponseParser.photoQualitySetting(from: message.parameters)
        }
    }

    func updatePhotoQuality(
        _ quality: DevicePhotoQuality,
        completion: @escaping (Result<DevicePhotoQualitySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updatePhotoQuality(quality), completion: completion) { message in
            try DeviceFileResponseParser.photoQualitySetting(from: message.parameters)
        }
    }

    func fetchPhotoDateWatermark(
        completion: @escaping (Result<DevicePhotoDateWatermarkSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.photoDateWatermark, completion: completion) { message in
            try DeviceFileResponseParser.photoDateWatermarkSetting(from: message.parameters)
        }
    }

    func updatePhotoDateWatermark(
        isEnabled: Bool,
        completion: @escaping (Result<DevicePhotoDateWatermarkSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updatePhotoDateWatermark(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.photoDateWatermarkSetting(from: message.parameters)
        }
    }

    func fetchTVMode(
        completion: @escaping (Result<DeviceTVModeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.tvMode, completion: completion) { message in
            try DeviceFileResponseParser.tvModeSetting(from: message.parameters)
        }
    }

    func updateTVMode(
        _ mode: DeviceTVMode,
        completion: @escaping (Result<DeviceTVModeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateTVMode(mode), completion: completion) { message in
            try DeviceFileResponseParser.tvModeSetting(from: message.parameters)
        }
    }

    func fetchParkingGuard(
        completion: @escaping (Result<DeviceParkingGuardSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.parkingGuard, completion: completion) { message in
            try DeviceFileResponseParser.parkingGuardSetting(from: message.parameters)
        }
    }

    func updateParkingGuard(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceParkingGuardSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateParkingGuard(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.parkingGuardSetting(from: message.parameters)
        }
    }

    func fetchParkingCollisionSensitivity(
        completion: @escaping (Result<DeviceParkingCollisionSensitivitySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.parkingCollisionSensitivity, completion: completion) { message in
            try DeviceFileResponseParser.parkingCollisionSensitivitySetting(from: message.parameters)
        }
    }

    func updateParkingCollisionSensitivity(
        _ sensitivity: DeviceParkingCollisionSensitivity,
        completion: @escaping (Result<DeviceParkingCollisionSensitivitySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateParkingCollisionSensitivity(sensitivity), completion: completion) { message in
            try DeviceFileResponseParser.parkingCollisionSensitivitySetting(from: message.parameters)
        }
    }

    func fetchIntervalRecording(
        completion: @escaping (Result<DeviceIntervalRecordingSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.intervalRecording, completion: completion) { message in
            try DeviceFileResponseParser.intervalRecordingSetting(from: message.parameters)
        }
    }

    func updateIntervalRecording(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceIntervalRecordingSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateIntervalRecording(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.intervalRecordingSetting(from: message.parameters)
        }
    }

    func fetchGPSTimeSync(
        completion: @escaping (Result<DeviceGPSTimeSyncSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.gpsTimeSync, completion: completion) { message in
            try DeviceFileResponseParser.gpsTimeSyncSetting(from: message.parameters)
        }
    }

    func updateGPSTimeSync(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceGPSTimeSyncSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateGPSTimeSync(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.gpsTimeSyncSetting(from: message.parameters)
        }
    }

    func fetchDrivingRestReminder(
        completion: @escaping (Result<DeviceDrivingRestReminderSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.drivingRestReminder, completion: completion) { message in
            try DeviceFileResponseParser.drivingRestReminderSetting(from: message.parameters)
        }
    }

    func updateDrivingRestReminder(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceDrivingRestReminderSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateDrivingRestReminder(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.drivingRestReminderSetting(from: message.parameters)
        }
    }

    func fetchLightFrequency(
        completion: @escaping (Result<DeviceLightFrequencySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.lightFrequency, completion: completion) { message in
            try DeviceFileResponseParser.lightFrequencySetting(from: message.parameters)
        }
    }

    func updateLightFrequency(
        _ frequency: DeviceLightFrequency,
        completion: @escaping (Result<DeviceLightFrequencySetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateLightFrequency(frequency), completion: completion) { message in
            try DeviceFileResponseParser.lightFrequencySetting(from: message.parameters)
        }
    }

    func fetchSpeakerVolume(
        completion: @escaping (Result<DeviceSpeakerVolumeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.speakerVolume, completion: completion) { message in
            try DeviceFileResponseParser.speakerVolumeSetting(from: message.parameters)
        }
    }

    func updateSpeakerVolume(
        _ volume: Int,
        completion: @escaping (Result<DeviceSpeakerVolumeSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateSpeakerVolume(volume), completion: completion) { message in
            try DeviceFileResponseParser.speakerVolumeSetting(from: message.parameters)
        }
    }

    func fetchSpeech(
        completion: @escaping (Result<DeviceSpeechSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.speech, completion: completion) { message in
            try DeviceFileResponseParser.speechSetting(from: message.parameters)
        }
    }

    func updateSpeech(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceSpeechSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateSpeech(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.speechSetting(from: message.parameters)
        }
    }

    func fetchKeyVoice(
        completion: @escaping (Result<DeviceKeyVoiceSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.keyVoice, completion: completion) { message in
            try DeviceFileResponseParser.keyVoiceSetting(from: message.parameters)
        }
    }

    func updateKeyVoice(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceKeyVoiceSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateKeyVoice(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.keyVoiceSetting(from: message.parameters)
        }
    }

    func fetchAntiTremor(
        completion: @escaping (Result<DeviceAntiTremorSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.antiTremor, completion: completion) { message in
            try DeviceFileResponseParser.antiTremorSetting(from: message.parameters)
        }
    }

    func updateAntiTremor(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceAntiTremorSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateAntiTremor(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.antiTremorSetting(from: message.parameters)
        }
    }

    func fetchElectronicDogVoice(
        completion: @escaping (Result<DeviceElectronicDogVoiceSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.electronicDogVoice, completion: completion) { message in
            try DeviceFileResponseParser.electronicDogVoiceSetting(from: message.parameters)
        }
    }

    func updateElectronicDogVoice(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceElectronicDogVoiceSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateElectronicDogVoice(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.electronicDogVoiceSetting(from: message.parameters)
        }
    }

    func fetchInfraredLight(
        completion: @escaping (Result<DeviceInfraredLightSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.infraredLight, completion: completion) { message in
            try DeviceFileResponseParser.infraredLightSetting(from: message.parameters)
        }
    }

    func updateInfraredLight(
        isEnabled: Bool,
        completion: @escaping (Result<DeviceInfraredLightSetting, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateInfraredLight(isEnabled: isEnabled), completion: completion) { message in
            try DeviceFileResponseParser.infraredLightSetting(from: message.parameters)
        }
    }

    func checkFirmwareUpgrade(
        candidate: DeviceFirmwareUpgradeCandidate,
        completion: @escaping (Result<DeviceFirmwareUpgradeCheckResult, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.firmwareUpgradeCheck(candidate: candidate), completion: completion) { message in
            try DeviceFileResponseParser.firmwareUpgradeCheckResult(from: message.parameters)
        }
    }

    func startFirmwareUpgrade(
        package: DeviceFirmwareUpgradePackage,
        completion: @escaping (Result<DeviceFirmwareUpgradeStartResult, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.startFirmwareUpgrade(package: package), completion: completion) { message in
            try DeviceFileResponseParser.firmwareUpgradeStartResult(from: message.parameters)
        }
    }

    func fetchPlaybackResource(
        path: String,
        completion: @escaping (Result<DeviceFilePlaybackResource, DeviceSessionReadOnlyError>) -> Void
    ) {
        guard Self.isNonEmptyProtocolString(path) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "FILE_DOWNLOAD_URL", parameters: [:]))))
            return
        }

        performReadOnlyCommand(.filePlaybackResource(path: path), completion: completion) { message in
            try DeviceFileResponseParser.playbackResource(from: message.parameters)
        }
    }

    func fetchThumbnails(
        paths: [String],
        completion: @escaping (Result<[DeviceFileThumbnail], DeviceSessionReadOnlyError>) -> Void
    ) {
        guard paths.isEmpty == false, paths.allSatisfy(Self.isNonEmptyProtocolString) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "THUMB_LIST", parameters: [:]))))
            return
        }

        performReadOnlyCommand(.thumbnailList(paths: paths), completion: completion) { message in
            try DeviceFileResponseParser.thumbnails(from: message.parameters)
        }
    }

    func fetchThumbnail(
        path: String,
        completion: @escaping (Result<DeviceFileThumbnail, DeviceSessionReadOnlyError>) -> Void
    ) {
        guard Self.isNonEmptyProtocolString(path) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: "THUMB_GET", parameters: [:]))))
            return
        }

        performReadOnlyCommand(.thumbnail(path: path), completion: completion) { message in
            try DeviceFileResponseParser.thumbnail(from: message.parameters)
        }
    }

    func fetchSDCardStatus(
        completion: @escaping (Result<Int, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.sdStatus) { [weak self] result in
            self?.completeSDCardStatus(result, completion: completion)
        } parse: { message in
            try DeviceFileResponseParser.sdCardStatus(from: message.parameters)
        }
    }

    func fetchBatteryStatus(
        completion: @escaping (Result<Int, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.batteryStatus) { [weak self] result in
            self?.completeBatteryStatus(result, completion: completion)
        } parse: { message in
            try DeviceFileResponseParser.batteryStatus(from: message.parameters)
        }
    }

    func fetchStorageCapacity(
        completion: @escaping (Result<DeviceStorageCapacity, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.tfCapacity) { [weak self] result in
            self?.completeStorageCapacity(result, completion: completion)
        } parse: { message in
            try DeviceFileResponseParser.storageCapacity(from: message.parameters)
        }
    }

    func fetchRecordingState(
        completion: @escaping (Result<DeviceRecordingState, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.recordingState) { [weak self] result in
            self?.completeRecordingStateCommand(result, completion: completion)
        } parse: { message in
            try DeviceFileResponseParser.recordingState(from: message.parameters)
        }
    }

    func setRecording(
        enabled: Bool,
        completion: @escaping (Result<DeviceRecordingState, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.setRecording(enabled: enabled)) { [weak self] result in
            self?.completeRecordingStateCommand(result, completion: completion)
        } parse: { message in
            try DeviceFileResponseParser.recordingState(from: message.parameters)
        }
    }

    func fetchRecordingConfiguration(
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.recordingConfiguration, completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func updateRecordingConfiguration(
        parameters: [String: DeviceProtocolValue],
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        guard Self.canPostAggregateConfiguration(parameters, topic: "RECORDING_CONFIG", completion: completion) else {
            return
        }

        performControlCommand(.updateRecordingConfiguration(parameters: parameters), completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func fetchSafetyConfiguration(
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.safetyConfiguration, completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func updateSafetyConfiguration(
        parameters: [String: DeviceProtocolValue],
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        guard Self.canPostAggregateConfiguration(parameters, topic: "SAFETY_CONFIG", completion: completion) else {
            return
        }

        performControlCommand(.updateSafetyConfiguration(parameters: parameters), completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func fetchStoragePolicyConfiguration(
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.storagePolicyConfiguration, completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func updateStoragePolicyConfiguration(
        parameters: [String: DeviceProtocolValue],
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        guard Self.canPostAggregateConfiguration(parameters, topic: "STORAGE_POLICY_CONFIG", completion: completion) else {
            return
        }

        performControlCommand(.updateStoragePolicyConfiguration(parameters: parameters), completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func fetchSystemPreferencesConfiguration(
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.systemPreferencesConfiguration, completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func updateSystemPreferencesConfiguration(
        parameters: [String: DeviceProtocolValue],
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        guard Self.canPostAggregateConfiguration(parameters, topic: "SYSTEM_PREFERENCES_CONFIG", completion: completion) else {
            return
        }

        performControlCommand(.updateSystemPreferencesConfiguration(parameters: parameters), completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func fetchWatermarkConfiguration(
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.watermarkConfiguration, completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    func updateWatermarkConfiguration(
        parameters: [String: DeviceProtocolValue],
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.updateWatermarkConfiguration(parameters: parameters), completion: completion) { message in
            DeviceAggregateResponseParser.configurationPayload(from: message.parameters)
        }
    }

    private static func canPostAggregateConfiguration(
        _ parameters: [String: DeviceProtocolValue],
        topic: String,
        completion: @escaping (Result<[String: DeviceProtocolValue], DeviceSessionCommandError>) -> Void
    ) -> Bool {
        guard parameters.isEmpty == false else {
            completion(.failure(.protocolFailure(.deviceError(errno: -2, topic: topic, parameters: [:]))))
            return false
        }
        return true
    }

    func captureSnapshot(
        mode: DeviceSnapshotMode = .preview,
        completion: @escaping (Result<DeviceSnapshotResource, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.snapshotControl(mode: mode)) { [weak self] result in
            switch result {
            case .success(let snapshotID):
                self?.performControlCommand(.snapshotData(snapshotID: snapshotID), completion: completion) { message in
                    try DeviceFileResponseParser.snapshotResource(from: message.parameters)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        } parse: { message in
            try DeviceFileResponseParser.snapshotID(from: message.parameters)
        }
    }

    func send(_ event: DeviceSessionEvent) {
        if Thread.isMainThread {
            applyTransition(event)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyTransition(event)
            }
        }
    }

    private func applyTransition(_ event: DeviceSessionEvent) {
        let shouldDisconnectProtocol = shouldDisconnectProtocol(for: event)
        let shouldSendExitApp = shouldSendExitAppBeforeDisconnect(from: state, event: event)
        if shouldDisconnectProtocol {
            invalidateProtocolHandshake()
            stopHeartbeat()
        }

        rememberRecoveryStateIfNeeded(for: event)

        let nextState = transition(from: state, event: event)
        let shouldInvalidateCommands = shouldInvalidateCommands(from: state, to: nextState)
        if nextState != state {
            state = nextState
        }

        updateDerivedState(for: nextState)

        if shouldInvalidateCommands {
            invalidateCommands()
        }

        if shouldRunHeartbeat(in: nextState) == false {
            stopHeartbeat()
        }

        if shouldStartProtocolHandshake(after: event, in: nextState) {
            startProtocolHandshake()
        }

        if shouldDisconnectProtocol {
            disconnectProtocol(sendExitApp: shouldSendExitApp)
        }
    }

    private func transition(from state: DeviceSessionState, event: DeviceSessionEvent) -> DeviceSessionState {
        switch (state, event) {
        case (.idle, .startAPConnection):
            return .apConnecting

        case (.apConnecting, .apConnectionSucceeded):
            return .handshaking

        case (.apConnecting, .apConnectionFailed(let reason)):
            return .failed(.apConnectionFailed(reason: reason))

        case (.handshaking, .startHandshake):
            return .handshaking

        case (.handshaking, .handshakeSucceeded(let deviceInfo)):
            return .ready(deviceInfo)

        case (.handshaking, .handshakeFailed(let reason)):
            return .failed(.handshakeFailed(reason: reason))

        case (.ready(let deviceInfo), .startOperation(let operation)):
            return .busy(operation: operation, deviceInfo: deviceInfo)

        case (.busy(operation: _, deviceInfo: let deviceInfo), .operationCompleted):
            return .ready(deviceInfo)

        case (.busy, .operationFailed(let error)):
            return .failed(error)

        case (_, .connectionLost):
            return .failed(.connectionLost)

        case (.failed, .startRecovery):
            return .recovering(previousState: previousStateBeforeRecovery ?? .idle)

        case (.recovering, .recoverySucceeded):
            previousStateBeforeRecovery = nil
            return .handshaking

        case (.recovering, .recoveryFailed(let error)):
            return .failed(error)

        case (.handshaking, .disconnect), (.ready, .disconnect), (.busy, .disconnect), (.failed, .disconnect), (.recovering, .disconnect):
            return .disconnected

        case (_, .reset):
            previousStateBeforeRecovery = nil
            return .idle

        default:
            return state
        }
    }

    private func rememberRecoveryStateIfNeeded(for event: DeviceSessionEvent) {
        switch event {
        case .connectionLost, .operationFailed:
            previousStateBeforeRecovery = recoverableState(from: state)
        case .startAPConnection, .reset, .disconnect:
            previousStateBeforeRecovery = nil
        default:
            break
        }
    }

    private func recoverableState(from state: DeviceSessionState) -> DeviceSessionState? {
        switch state {
        case .ready(let deviceInfo):
            return .ready(deviceInfo)
        case .busy(operation: _, deviceInfo: let deviceInfo):
            return .ready(deviceInfo)
        case .recovering(let previousState):
            return previousState
        default:
            return nil
        }
    }

    private func updateDerivedState(for state: DeviceSessionState) {
        switch state {
        case .busy(operation: let operation, deviceInfo: _):
            currentOperation = operation
        default:
            currentOperation = nil
        }
    }

    private func performReadOnlyCommand<T>(
        _ command: DeviceProtocolCommand,
        completion: @escaping (Result<T, DeviceSessionReadOnlyError>) -> Void,
        parse: @escaping (DeviceProtocolMessage) throws -> T
    ) {
        performDeviceCommand(
            command,
            scope: .readOnly,
            completion: completion,
            parse: parse
        )
    }

    private func performControlCommand<T>(
        _ command: DeviceProtocolCommand,
        completion: @escaping (Result<T, DeviceSessionCommandError>) -> Void,
        parse: @escaping (DeviceProtocolMessage) throws -> T
    ) {
        performDeviceCommand(
            command,
            scope: .control,
            completion: completion,
            parse: parse
        )
    }

    private static func isValidAccessPointIdentity(ssid: String, password: String) -> Bool {
        ssid.isEmpty == false &&
            ssid.lengthOfBytes(using: .utf8) <= 32 &&
            (8...63).contains(password.count) &&
            password.unicodeScalars.allSatisfy { (0x20...0x7E).contains($0.value) }
    }

    nonisolated private static func isNonEmptyProtocolString(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func performDeviceCommand<T, Failure: DeviceSessionCommandFailure>(
        _ command: DeviceProtocolCommand,
        scope: DeviceSessionCommandScope,
        completion: @escaping (Result<T, Failure>) -> Void,
        parse: @escaping (DeviceProtocolMessage) throws -> T
    ) {
        guard state.canSendDeviceCommand else {
            completion(.failure(.sessionNotReady))
            return
        }

        guard protocolCapabilities.supports(command) else {
            completion(.failure(.protocolFailure(.deviceError(errno: -5, topic: command.topic, parameters: [:]))))
            return
        }

        guard let protocolClient else {
            completion(.failure(.protocolClientUnavailable))
            return
        }

        let generation = commandGeneration(for: scope)
        protocolClient.send(command) { [weak self] result in
            guard let self else {
                return
            }

            guard self.isCurrentCommand(generation, scope: scope) else {
                completion(.failure(.staleSession))
                return
            }

            switch result {
            case .success(let message):
                do {
                    completion(.success(try parse(message)))
                } catch let error as Failure {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.invalidResponse(error.localizedDescription)))
                }
            case .failure(let error):
                completion(.failure(.protocolFailure(error)))
            }
        }
    }

    private func handleProtocolConnect(
        _ result: Result<Void, DeviceProtocolError>,
        generation: Int
    ) {
        guard isCurrentHandshake(generation) else {
            return
        }

        switch result {
        case .success:
            protocolClient?.startHandshake(
                appVersion: appVersion,
                commandTimeout: handshakeCommandTimeout
            ) { [weak self] result in
                self?.handleProtocolHandshake(result, generation: generation)
            }
        case .failure(let error):
            send(.handshakeFailed(reason: Self.handshakeFailureReason(for: error)))
        }
    }

    private func handleProtocolHandshake(
        _ result: Result<[DeviceProtocolMessage], DeviceProtocolError>,
        generation: Int
    ) {
        guard isCurrentHandshake(generation) else {
            return
        }

        switch result {
        case .success(let responses):
            if let failureReason = Self.handshakeValidationFailureReason(from: responses) {
                send(.handshakeFailed(reason: failureReason))
                stopHeartbeat()
                return
            }
            let protocolCapabilities = Self.protocolCapabilities(from: responses)
            self.protocolCapabilities = protocolCapabilities
            applyHandshakeStatus(from: responses)
            send(.handshakeSucceeded(Self.deviceInfo(from: responses, fallbackName: deviceName)))
            if protocolCapabilities.supportsHeartbeat {
                startHeartbeat(Self.heartbeatConfiguration(from: responses))
            } else {
                stopHeartbeat()
            }
        case .failure(let error):
            send(.handshakeFailed(reason: Self.handshakeFailureReason(for: error)))
        }
    }

    private func handleProtocolDisconnect(_: DeviceProtocolError?) {
        switch state {
        case .handshaking, .ready, .busy, .recovering:
            invalidateProtocolHandshake()
            send(.connectionLost)
        default:
            break
        }
    }

    private func handleProtocolEvent(_ message: DeviceProtocolMessage) {
        if Thread.isMainThread {
            applyProtocolEvent(message)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyProtocolEvent(message)
            }
        }
    }

    private func applyProtocolEvent(_ message: DeviceProtocolMessage) {
        guard message.notifyType == .event else {
            return
        }

        var nextStatus = deviceStatus
        switch message.topic {
        case "SD_STATUS":
            guard message.errno ?? 0 == 0,
                  let online = try? DeviceFileResponseParser.sdCardStatus(from: message.parameters) else {
                return
            }
            nextStatus.sdCardOnline = online
        case "BAT_STATUS":
            guard message.errno ?? 0 == 0,
                  let level = try? DeviceFileResponseParser.batteryStatus(from: message.parameters) else {
                return
            }
            nextStatus.batteryLevel = level
        case "VIDEO_CTRL":
            guard message.errno ?? 0 == 0,
                  let recordingState = try? DeviceFileResponseParser.recordingState(from: message.parameters) else {
                return
            }
            nextStatus.recordingState = recordingState
        case "FORMAT_PROGRESS", "UPGRADE_PROGRESS", "DOWNLOAD_PROGRESS":
            guard let progressEvent = Self.progressEvent(from: message) else {
                return
            }
            nextStatus.progressEvents[Self.progressEventKey(for: progressEvent)] = progressEvent
            nextStatus.latestProgressEvent = progressEvent
        default:
            return
        }

        deviceStatus = nextStatus
    }

    private static func progressEventKey(for event: DeviceProgressEvent) -> String {
        "\(event.topic)#\(event.taskID)"
    }

    private func completeRecordingStateCommand(
        _ result: Result<DeviceRecordingState, DeviceSessionCommandError>,
        completion: @escaping (Result<DeviceRecordingState, DeviceSessionCommandError>) -> Void
    ) {
        if case .success(let recordingState) = result {
            applyRecordingState(recordingState)
        }
        completion(result)
    }

    private func completeSDCardStatus(
        _ result: Result<Int, DeviceSessionReadOnlyError>,
        completion: @escaping (Result<Int, DeviceSessionReadOnlyError>) -> Void
    ) {
        if case .success(let online) = result {
            applySDCardStatus(online)
        }
        completion(result)
    }

    private func completeBatteryStatus(
        _ result: Result<Int, DeviceSessionReadOnlyError>,
        completion: @escaping (Result<Int, DeviceSessionReadOnlyError>) -> Void
    ) {
        if case .success(let level) = result {
            applyBatteryStatus(level)
        }
        completion(result)
    }

    private func completeStorageCapacity(
        _ result: Result<DeviceStorageCapacity, DeviceSessionReadOnlyError>,
        completion: @escaping (Result<DeviceStorageCapacity, DeviceSessionReadOnlyError>) -> Void
    ) {
        if case .success(let capacity) = result {
            applyStorageCapacity(capacity)
        }
        completion(result)
    }

    private func applyRecordingState(_ recordingState: DeviceRecordingState) {
        if Thread.isMainThread {
            var nextStatus = deviceStatus
            nextStatus.recordingState = recordingState
            deviceStatus = nextStatus
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyRecordingState(recordingState)
            }
        }
    }

    private func applySDCardStatus(_ online: Int) {
        if Thread.isMainThread {
            var nextStatus = deviceStatus
            nextStatus.sdCardOnline = online
            deviceStatus = nextStatus
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applySDCardStatus(online)
            }
        }
    }

    private func applyBatteryStatus(_ level: Int) {
        if Thread.isMainThread {
            var nextStatus = deviceStatus
            nextStatus.batteryLevel = level
            deviceStatus = nextStatus
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyBatteryStatus(level)
            }
        }
    }

    private func applyStorageCapacity(_ capacity: DeviceStorageCapacity) {
        if Thread.isMainThread {
            var nextStatus = deviceStatus
            nextStatus.storageCapacity = capacity
            deviceStatus = nextStatus
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyStorageCapacity(capacity)
            }
        }
    }

    private func shouldDisconnectProtocol(for event: DeviceSessionEvent) -> Bool {
        switch event {
        case .disconnect, .reset:
            return true
        default:
            return false
        }
    }

    private func shouldSendExitAppBeforeDisconnect(
        from state: DeviceSessionState,
        event: DeviceSessionEvent
    ) -> Bool {
        guard shouldDisconnectProtocol(for: event) else {
            return false
        }

        switch state {
        case .ready, .busy:
            return true
        default:
            return false
        }
    }

    private func disconnectProtocol(sendExitApp: Bool) {
        guard sendExitApp, let protocolClient else {
            protocolClient?.disconnect()
            return
        }

        protocolClient.send(.exitApp()) { _ in }
        protocolClient.disconnect()
    }

    private func startHeartbeat(_ configuration: DeviceSessionHeartbeatConfiguration) {
        stopHeartbeat()
        heartbeatConfiguration = configuration
        heartbeatSequence = 0
        missedHeartbeatACKCount = 0
        scheduleNextHeartbeat()
    }

    private func stopHeartbeat() {
        heartbeatGeneration += 1
        heartbeatWorkItem?.cancel()
        heartbeatTimeoutWorkItem?.cancel()
        heartbeatWorkItem = nil
        heartbeatTimeoutWorkItem = nil
        heartbeatSequence = 0
        missedHeartbeatACKCount = 0
        isHeartbeatAwaitingResponse = false
    }

    private func scheduleNextHeartbeat() {
        guard shouldRunHeartbeat(in: state) else {
            return
        }

        heartbeatGeneration += 1
        let generation = heartbeatGeneration
        let workItem = DispatchWorkItem { [weak self] in
            self?.sendHeartbeatIfNeeded(generation: generation)
        }
        heartbeatWorkItem?.cancel()
        heartbeatWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + heartbeatConfiguration.interval, execute: workItem)
    }

    private func sendHeartbeatIfNeeded(generation: Int) {
        guard generation == heartbeatGeneration,
              shouldRunHeartbeat(in: state),
              isHeartbeatAwaitingResponse == false,
              let protocolClient else {
            return
        }

        heartbeatSequence += 1
        isHeartbeatAwaitingResponse = true
        scheduleHeartbeatTimeout(generation: generation)

        let command = DeviceProtocolCommand
            .heartbeat(seq: heartbeatSequence, clientTime: Self.heartbeatClientTime())
            .withTimeout(heartbeatConfiguration.commandTimeout)
        protocolClient.send(command) { [weak self] result in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                self.handleHeartbeatResult(result, generation: generation)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.handleHeartbeatResult(result, generation: generation)
                }
            }
        }
    }

    private func scheduleHeartbeatTimeout(generation: Int) {
        heartbeatTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.heartbeatGeneration,
                  self.isHeartbeatAwaitingResponse else {
                return
            }

            self.handleHeartbeatFailure()
        }
        heartbeatTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + heartbeatConfiguration.timeout, execute: workItem)
    }

    private func handleHeartbeatResult(
        _ result: Result<DeviceProtocolMessage, DeviceProtocolError>,
        generation: Int
    ) {
        guard generation == heartbeatGeneration else {
            return
        }

        heartbeatTimeoutWorkItem?.cancel()
        heartbeatTimeoutWorkItem = nil
        isHeartbeatAwaitingResponse = false

        switch result {
        case .success(let message) where isValidHeartbeatAcknowledgement(message):
            missedHeartbeatACKCount = 0
            scheduleNextHeartbeat()
        default:
            missedHeartbeatACKCount += 1
            if missedHeartbeatACKCount >= 2 {
                handleHeartbeatFailure()
            } else {
                scheduleNextHeartbeat()
            }
        }
    }

    private func isValidHeartbeatAcknowledgement(_ message: DeviceProtocolMessage) -> Bool {
        guard case .bool(true)? = message.parameters["ack"],
              case .int(let seq)? = message.parameters["seq"] else {
            return false
        }

        return seq == heartbeatSequence
    }

    private func handleHeartbeatFailure() {
        guard shouldRunHeartbeat(in: state) else {
            stopHeartbeat()
            return
        }

        stopHeartbeat()
        invalidateProtocolHandshake()
        invalidateCommands()
        protocolClient?.disconnect()
    }

    private func shouldRunHeartbeat(in state: DeviceSessionState) -> Bool {
        switch state {
        case .ready, .busy:
            return true
        default:
            return false
        }
    }

    private func shouldStartProtocolHandshake(after event: DeviceSessionEvent, in state: DeviceSessionState) -> Bool {
        guard case .recoverySucceeded = event, case .handshaking = state else {
            return false
        }
        return protocolClient != nil
    }

    private func nextHandshakeGeneration() -> Int {
        handshakeGeneration += 1
        return handshakeGeneration
    }

    private func invalidateProtocolHandshake() {
        handshakeGeneration += 1
    }

    private func invalidateCommands() {
        readOnlyCommandGeneration += 1
        controlCommandGeneration += 1
    }

    private func isCurrentHandshake(_ generation: Int) -> Bool {
        if case .handshaking = state {
            return generation == handshakeGeneration
        }
        return false
    }

    private func commandGeneration(for scope: DeviceSessionCommandScope) -> Int {
        switch scope {
        case .readOnly:
            return readOnlyCommandGeneration
        case .control:
            return controlCommandGeneration
        }
    }

    private func isCurrentCommand(_ generation: Int, scope: DeviceSessionCommandScope) -> Bool {
        state.canSendDeviceCommand && generation == commandGeneration(for: scope)
    }

    private func shouldInvalidateCommands(
        from currentState: DeviceSessionState,
        to nextState: DeviceSessionState
    ) -> Bool {
        currentState.canSendDeviceCommand && nextState.canSendDeviceCommand == false
    }

    private static func deviceInfo(
        from responses: [DeviceProtocolMessage],
        fallbackName: String
    ) -> DeviceInfo {
        let responsesByTopic = Dictionary(grouping: responses, by: \.topic).compactMapValues(\.last)
        let id = handshakeString(topic: "UUID", key: "uuid", in: responsesByTopic) ?? "unknown-device"
        let firmwareVersion = handshakeString(topic: "FW_VERSION", key: "ver", in: responsesByTopic) ?? "unknown"

        return DeviceInfo(
            id: id,
            name: fallbackName,
            firmwareVersion: firmwareVersion,
            capabilities: capabilities(from: responsesByTopic["CAMERA_CAPABILITY"]?.parameters["capabilities"])
        )
    }

    private static func handshakeValidationFailureReason(from responses: [DeviceProtocolMessage]) -> String? {
        let responsesByTopic = Dictionary(grouping: responses, by: \.topic).compactMapValues(\.last)
        if handshakeString(topic: "UUID", key: "uuid", in: responsesByTopic) == nil {
            return "UUID.uuid 缺失"
        }
        if handshakeString(topic: "FW_VERSION", key: "ver", in: responsesByTopic) == nil {
            return "FW_VERSION.ver 缺失"
        }
        return nil
    }

    private static func handshakeString(
        topic: String,
        key: String,
        in responsesByTopic: [String: DeviceProtocolMessage]
    ) -> String? {
        guard let value = responsesByTopic[topic]?.parameters[key]?.stringValue,
              isNonEmptyProtocolString(value) else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func heartbeatConfiguration(from responses: [DeviceProtocolMessage]) -> DeviceSessionHeartbeatConfiguration {
        let appAccess = responses.first { $0.topic == "APP_ACCESS" }

        return DeviceSessionHeartbeatConfiguration(
            interval: positiveTimeInterval(appAccess?.parameters["heartbeat_interval"]) ?? 30,
            timeout: positiveTimeInterval(appAccess?.parameters["heartbeat_timeout"]) ?? 90
        )
    }

    private func applyHandshakeStatus(from responses: [DeviceProtocolMessage]) {
        let responsesByTopic = Dictionary(grouping: responses, by: \.topic).compactMapValues(\.last)
        var nextStatus = deviceStatus
        if let message = responsesByTopic["SD_STATUS"],
           let online = try? DeviceFileResponseParser.sdCardStatus(from: message.parameters) {
            nextStatus.sdCardOnline = online
        }
        if let message = responsesByTopic["BAT_STATUS"],
           let level = try? DeviceFileResponseParser.batteryStatus(from: message.parameters) {
            nextStatus.batteryLevel = level
        }
        if let message = responsesByTopic["TF_CAP"],
           let capacity = try? DeviceFileResponseParser.storageCapacity(from: message.parameters) {
            nextStatus.storageCapacity = capacity
        }
        deviceStatus = nextStatus
    }

    private static func protocolCapabilities(from responses: [DeviceProtocolMessage]) -> DeviceSessionProtocolCapabilities {
        let responsesByTopic = Dictionary(grouping: responses, by: \.topic).compactMapValues(\.last)
        let protocolVersion = responsesByTopic["PROTOCOL_VERSION"]?.parameters["protocol_ver"]?.stringValue
        let capabilities = objectValue(responsesByTopic["CAMERA_CAPABILITY"]?.parameters["capabilities"])
        let protocolFields = objectValue(capabilities?["protocol"])
        let videoFields = objectValue(capabilities?["video"])
        let photoFields = objectValue(capabilities?["photo"])
        let imageFields = objectValue(capabilities?["image"])
        let audioFields = objectValue(capabilities?["audio"])
        let parkingFields = objectValue(capabilities?["parking"])
        let gpsFields = objectValue(capabilities?["gps"])
        let fileFields = objectValue(capabilities?["file"])
        let systemFields = objectValue(capabilities?["system"])

        return DeviceSessionProtocolCapabilities(
            protocolVersion: protocolVersion,
            protocolFields: protocolFields,
            videoFields: videoFields,
            photoFields: photoFields,
            imageFields: imageFields,
            audioFields: audioFields,
            parkingFields: parkingFields,
            gpsFields: gpsFields,
            fileFields: fileFields,
            systemFields: systemFields
        )
    }

    private static func progressEvent(from message: DeviceProtocolMessage) -> DeviceProgressEvent? {
        guard
            let taskID = nonEmptyProgressString("task_id", in: message.parameters),
            let type = progressEventType(for: message.topic, in: message.parameters),
            let progress = progressEventInt("progress", in: message.parameters),
            (0...100).contains(progress),
            let status = nonEmptyProgressString("status", in: message.parameters)?.lowercased(),
            ["processing", "completed", "failed"].contains(status)
        else {
            return nil
        }

        let path: String?
        let speed: Int?
        let stage: String?

        switch message.topic {
        case "DOWNLOAD_PROGRESS":
            guard
                let downloadPath = nonEmptyProgressString("path", in: message.parameters),
                let downloadSpeed = progressEventInt("speed", in: message.parameters),
                downloadSpeed >= 0
            else {
                return nil
            }
            path = downloadPath
            speed = downloadSpeed
            stage = nil
        case "UPGRADE_PROGRESS":
            guard
                let upgradeStage = nonEmptyProgressString("stage", in: message.parameters)?.lowercased(),
                ["downloading", "installing", "restarting"].contains(upgradeStage)
            else {
                return nil
            }
            path = nil
            speed = nil
            stage = upgradeStage
        case "FORMAT_PROGRESS":
            path = nil
            speed = nil
            stage = nil
        default:
            return nil
        }

        return DeviceProgressEvent(
            topic: message.topic,
            taskID: taskID,
            type: type,
            progress: progress,
            status: status,
            stage: stage,
            path: path,
            speed: speed,
            errno: message.errno
        )
    }

    private static func progressEventType(
        for topic: String,
        in parameters: [String: DeviceProtocolValue]
    ) -> String? {
        guard let type = nonEmptyProgressString("type", in: parameters)?.lowercased() else {
            return nil
        }

        switch topic {
        case "FORMAT_PROGRESS" where type == "format",
            "UPGRADE_PROGRESS" where type == "upgrade",
            "DOWNLOAD_PROGRESS" where type == "transfer":
            return type
        default:
            return nil
        }
    }

    private static func nonEmptyProgressString(
        _ key: String,
        in parameters: [String: DeviceProtocolValue]
    ) -> String? {
        guard let value = parameters.string(key), value.isEmpty == false else {
            return nil
        }
        return value
    }

    private static func progressEventInt(
        _ key: String,
        in parameters: [String: DeviceProtocolValue]
    ) -> Int? {
        guard case .int(let value) = parameters[key] else {
            return nil
        }
        return value
    }

    private static func capabilities(from value: DeviceProtocolValue?) -> Set<DeviceCapability> {
        guard let root = objectValue(value) else {
            return []
        }

        var capabilities: Set<DeviceCapability> = []

        if objectValue(root["video"])?["supported"]?.boolValue == true {
            capabilities.insert(.livePreview)
        }

        if objectValue(root["file"])?["thumbnail"]?.boolValue == true {
            capabilities.insert(.playback)
        }

        if objectValue(root["file"])?["download"]?.boolValue == true {
            capabilities.insert(.download)
        }

        if root["system"] != nil ||
            root["audio"] != nil ||
            root["image"] != nil ||
            root["parking"] != nil {
            capabilities.insert(.settings)
        }

        return capabilities
    }

    private static func objectValue(_ value: DeviceProtocolValue?) -> [String: DeviceProtocolValue]? {
        if case .object(let object)? = value {
            return object
        }
        return nil
    }

    private static func positiveTimeInterval(_ value: DeviceProtocolValue?) -> TimeInterval? {
        if let intValue = value?.intValue, intValue > 0 {
            return TimeInterval(intValue)
        }

        if case .double(let doubleValue)? = value, doubleValue > 0 {
            return doubleValue
        }

        if let stringValue = value?.stringValue,
           let doubleValue = TimeInterval(stringValue),
           doubleValue > 0 {
            return doubleValue
        }

        return nil
    }

    private static func heartbeatClientTime() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }

    static func protocolFailureReason(for error: DeviceProtocolError) -> String {
        DeviceProtocolFailureReason.message(for: error)
    }

    private static func handshakeFailureReason(for error: DeviceProtocolError) -> String {
        protocolFailureReason(for: error)
    }
}

private enum DeviceSessionCommandScope {
    case readOnly
    case control
}

private struct DeviceSessionHeartbeatConfiguration {
    static let `default` = DeviceSessionHeartbeatConfiguration(interval: 30, timeout: 90)

    let interval: TimeInterval
    let timeout: TimeInterval

    var commandTimeout: TimeInterval {
        min(10, max(0.05, interval))
    }
}

private struct DeviceSessionProtocolCapabilities {
    static let unsupported = DeviceSessionProtocolCapabilities(
        supportsHeartbeat: false,
        supportsStateSync: false,
        supportsMediaIndex: false,
        supportsRecentEvents: false,
        supportsAggregateConfig: false,
        supportsThumbnailBase64: false,
        supportsSnapshotBase64: false,
        supportsVideo: false,
        supportedVideoResolutions: [],
        supportedVideoLoopModes: [],
        supportsPhoto: false,
        supportedPhotoResolutions: [],
        supportedPhotoQualities: [],
        supportsVideoWideDynamicRange: false,
        supportsVideoExposure: false,
        supportsHorizontalMirror: false,
        supportsVerticalFlip: false,
        supportedLightFrequencies: [],
        supportedTVModes: [],
        supportsAntiTremor: false,
        supportsInfraredLight: false,
        supportsParking: false,
        supportedParkingModes: [],
        supportedParkingMonitorDurations: [],
        supportedVoltageProtectionIndexes: [],
        supportsParkingGuard: false,
        supportedParkingCollisionSensitivities: [],
        supportsRealtimeGPSData: false,
        supportsGPSVideoOverlay: false,
        supportsFileThumbnail: false,
        supportsFileLock: false,
        supportsFileUnlock: false,
        supportsWifiConfiguration: false,
        supportsWifiSSIDEditing: false,
        supportsWifiPasswordEditing: false,
        supportsFactoryReset: false,
        supportsAutoShutdown: false,
        supportsScreenProtection: false,
        supportedHourTypes: [],
        supportsVideoMicrophone: false,
        supportsSpeakerVolume: false,
        supportsSpeech: false,
        supportsKeyVoice: false
    )

    let supportsHeartbeat: Bool
    private let supportsStateSync: Bool
    private let supportsMediaIndex: Bool
    private let supportsRecentEvents: Bool
    private let supportsAggregateConfig: Bool
    private let supportsThumbnailBase64: Bool
    private let supportsSnapshotBase64: Bool
    private let supportsVideo: Bool
    private let supportedVideoResolutions: Set<String>
    private let supportedVideoLoopModes: Set<Int>
    private let supportsPhoto: Bool
    private let supportedPhotoResolutions: Set<String>
    private let supportedPhotoQualities: Set<String>
    private let supportsVideoWideDynamicRange: Bool
    private let supportsVideoExposure: Bool
    private let supportsHorizontalMirror: Bool
    private let supportsVerticalFlip: Bool
    private let supportedLightFrequencies: Set<String>
    private let supportedTVModes: Set<String>
    private let supportsAntiTremor: Bool
    private let supportsInfraredLight: Bool
    private let supportsParking: Bool
    private let supportedParkingModes: Set<Int>
    private let supportedParkingMonitorDurations: Set<Int>
    private let supportedVoltageProtectionIndexes: Set<Int>
    private let supportsParkingGuard: Bool
    private let supportedParkingCollisionSensitivities: Set<Int>
    private let supportsRealtimeGPSData: Bool
    private let supportsGPSVideoOverlay: Bool
    private let supportsFileThumbnail: Bool
    private let supportsFileLock: Bool
    private let supportsFileUnlock: Bool
    private let supportsWifiConfiguration: Bool
    private let supportsWifiSSIDEditing: Bool
    private let supportsWifiPasswordEditing: Bool
    private let supportsFactoryReset: Bool
    private let supportsAutoShutdown: Bool
    private let supportsScreenProtection: Bool
    private let supportedHourTypes: Set<Int>
    private let supportsVideoMicrophone: Bool
    private let supportsSpeakerVolume: Bool
    private let supportsSpeech: Bool
    private let supportsKeyVoice: Bool

    init(
        protocolVersion: String?,
        protocolFields: [String: DeviceProtocolValue]?,
        videoFields: [String: DeviceProtocolValue]?,
        photoFields: [String: DeviceProtocolValue]?,
        imageFields: [String: DeviceProtocolValue]?,
        audioFields: [String: DeviceProtocolValue]?,
        parkingFields: [String: DeviceProtocolValue]?,
        gpsFields: [String: DeviceProtocolValue]?,
        fileFields: [String: DeviceProtocolValue]?,
        systemFields: [String: DeviceProtocolValue]?
    ) {
        let supportsBaselineProtocol = Self.protocolVersion(protocolVersion, isAtLeast: [1, 2])
        let supportsInlineMediaBase64 = protocolFields?["inline_media_base64"]?.boolValue == true
        supportsHeartbeat = supportsBaselineProtocol
        supportsStateSync = protocolFields?["state_sync_supported"]?.boolValue == true
        supportsMediaIndex = protocolFields?["media_index_supported"]?.boolValue == true
        supportsRecentEvents = protocolFields?["recent_events_supported"]?.boolValue == true
        supportsAggregateConfig = protocolFields?["aggregate_config_supported"]?.boolValue == true
        supportsFileThumbnail = fileFields?["thumbnail"]?.boolValue == true
        supportsThumbnailBase64 = supportsInlineMediaBase64 &&
            supportsFileThumbnail &&
            Self.transportList(fileFields?["thumbnail_transport"], contains: "base64")
        supportsSnapshotBase64 = supportsInlineMediaBase64 &&
            Self.transportList(imageFields?["snapshot_transport"], contains: "base64")
        supportsVideo = videoFields?["supported"]?.boolValue == true
        supportedVideoResolutions = Self.stringList(videoFields?["resolutions"])
        supportedVideoLoopModes = Self.videoLoopModeList(videoFields?["loop_modes"])
        supportsPhoto = photoFields?["supported"]?.boolValue == true
        supportedPhotoResolutions = Self.stringList(photoFields?["resolutions"])
        supportedPhotoQualities = Self.stringList(photoFields?["qualities"])
        supportsVideoWideDynamicRange = imageFields?["wdr"]?.boolValue == true
        supportsVideoExposure = Self.hasArrayValues(imageFields?["exposure_options"])
        supportsHorizontalMirror = imageFields?["mirror"]?.boolValue == true
        supportsVerticalFlip = imageFields?["flip"]?.boolValue == true
        supportedLightFrequencies = Self.stringList(imageFields?["light_frequency"])
        supportedTVModes = Self.stringList(imageFields?["tv_mode"])
        supportsAntiTremor = imageFields?["anti_tremor"]?.boolValue == true
        supportsInfraredLight = imageFields?["ir_switch"]?.boolValue == true
        supportsParking = parkingFields?["supported"]?.boolValue == true
        supportedParkingModes = Self.parkingModeList(parkingFields?["modes"])
        supportedParkingMonitorDurations = Self.intList(parkingFields?["monitor_time_options"])
        supportedVoltageProtectionIndexes = Self.indexList(parkingFields?["voltage_protection"])
        supportsParkingGuard = parkingFields?["guard_switch"]?.boolValue == true
        supportedParkingCollisionSensitivities = Self.intList(parkingFields?["collision_sensitivity"])
        supportsRealtimeGPSData = gpsFields?["supported"]?.boolValue == true &&
            gpsFields?["realtime_data"]?.boolValue == true
        supportsGPSVideoOverlay = gpsFields?["supported"]?.boolValue == true &&
            gpsFields?["video_overlay"]?.boolValue == true
        supportsFileLock = fileFields?["lock"]?.boolValue == true
        supportsFileUnlock = fileFields?["unlock"]?.boolValue == true
        supportsWifiConfiguration = systemFields?["wifi_config"]?.boolValue == true
        supportsWifiSSIDEditing = systemFields?["wifi_ssid_editable"]?.boolValue == true
        supportsWifiPasswordEditing = systemFields?["wifi_pwd_editable"]?.boolValue == true
        supportsFactoryReset = systemFields?["factory_reset"]?.boolValue == true
        supportsAutoShutdown = systemFields?["auto_shutdown"]?.boolValue == true
        supportsScreenProtection = systemFields?["screen_protect"]?.boolValue == true
        supportedHourTypes = Self.intList(systemFields?["hour_type"])
        supportsVideoMicrophone = audioFields?["mic_switchable"]?.boolValue == true
        supportsSpeakerVolume = audioFields?["speaker_volume"]?.boolValue == true
        supportsSpeech = audioFields?["speech"]?.boolValue == true
        supportsKeyVoice = audioFields?["key_voice"]?.boolValue == true
    }

    private init(
        supportsHeartbeat: Bool,
        supportsStateSync: Bool,
        supportsMediaIndex: Bool,
        supportsRecentEvents: Bool,
        supportsAggregateConfig: Bool,
        supportsThumbnailBase64: Bool,
        supportsSnapshotBase64: Bool,
        supportsVideo: Bool,
        supportedVideoResolutions: Set<String>,
        supportedVideoLoopModes: Set<Int>,
        supportsPhoto: Bool,
        supportedPhotoResolutions: Set<String>,
        supportedPhotoQualities: Set<String>,
        supportsVideoWideDynamicRange: Bool,
        supportsVideoExposure: Bool,
        supportsHorizontalMirror: Bool,
        supportsVerticalFlip: Bool,
        supportedLightFrequencies: Set<String>,
        supportedTVModes: Set<String>,
        supportsAntiTremor: Bool,
        supportsInfraredLight: Bool,
        supportsParking: Bool,
        supportedParkingModes: Set<Int>,
        supportedParkingMonitorDurations: Set<Int>,
        supportedVoltageProtectionIndexes: Set<Int>,
        supportsParkingGuard: Bool,
        supportedParkingCollisionSensitivities: Set<Int>,
        supportsRealtimeGPSData: Bool,
        supportsGPSVideoOverlay: Bool,
        supportsFileThumbnail: Bool,
        supportsFileLock: Bool,
        supportsFileUnlock: Bool,
        supportsWifiConfiguration: Bool,
        supportsWifiSSIDEditing: Bool,
        supportsWifiPasswordEditing: Bool,
        supportsFactoryReset: Bool,
        supportsAutoShutdown: Bool,
        supportsScreenProtection: Bool,
        supportedHourTypes: Set<Int>,
        supportsVideoMicrophone: Bool,
        supportsSpeakerVolume: Bool,
        supportsSpeech: Bool,
        supportsKeyVoice: Bool
    ) {
        self.supportsHeartbeat = supportsHeartbeat
        self.supportsStateSync = supportsStateSync
        self.supportsMediaIndex = supportsMediaIndex
        self.supportsRecentEvents = supportsRecentEvents
        self.supportsAggregateConfig = supportsAggregateConfig
        self.supportsThumbnailBase64 = supportsThumbnailBase64
        self.supportsSnapshotBase64 = supportsSnapshotBase64
        self.supportsVideo = supportsVideo
        self.supportedVideoResolutions = supportedVideoResolutions
        self.supportedVideoLoopModes = supportedVideoLoopModes
        self.supportsPhoto = supportsPhoto
        self.supportedPhotoResolutions = supportedPhotoResolutions
        self.supportedPhotoQualities = supportedPhotoQualities
        self.supportsVideoWideDynamicRange = supportsVideoWideDynamicRange
        self.supportsVideoExposure = supportsVideoExposure
        self.supportsHorizontalMirror = supportsHorizontalMirror
        self.supportsVerticalFlip = supportsVerticalFlip
        self.supportedLightFrequencies = supportedLightFrequencies
        self.supportedTVModes = supportedTVModes
        self.supportsAntiTremor = supportsAntiTremor
        self.supportsInfraredLight = supportsInfraredLight
        self.supportsParking = supportsParking
        self.supportedParkingModes = supportedParkingModes
        self.supportedParkingMonitorDurations = supportedParkingMonitorDurations
        self.supportedVoltageProtectionIndexes = supportedVoltageProtectionIndexes
        self.supportsParkingGuard = supportsParkingGuard
        self.supportedParkingCollisionSensitivities = supportedParkingCollisionSensitivities
        self.supportsRealtimeGPSData = supportsRealtimeGPSData
        self.supportsGPSVideoOverlay = supportsGPSVideoOverlay
        self.supportsFileThumbnail = supportsFileThumbnail
        self.supportsFileLock = supportsFileLock
        self.supportsFileUnlock = supportsFileUnlock
        self.supportsWifiConfiguration = supportsWifiConfiguration
        self.supportsWifiSSIDEditing = supportsWifiSSIDEditing
        self.supportsWifiPasswordEditing = supportsWifiPasswordEditing
        self.supportsFactoryReset = supportsFactoryReset
        self.supportsAutoShutdown = supportsAutoShutdown
        self.supportsScreenProtection = supportsScreenProtection
        self.supportedHourTypes = supportedHourTypes
        self.supportsVideoMicrophone = supportsVideoMicrophone
        self.supportsSpeakerVolume = supportsSpeakerVolume
        self.supportsSpeech = supportsSpeech
        self.supportsKeyVoice = supportsKeyVoice
    }

    func supports(_ command: DeviceProtocolCommand) -> Bool {
        switch command.topic {
        case "STATE_SYNC":
            return supportsStateSync
        case "MEDIA_INDEX":
            return supportsMediaIndex
        case "RECENT_EVENTS":
            return supportsRecentEvents
        case "RECORDING_CONFIG",
            "SAFETY_CONFIG",
            "STORAGE_POLICY_CONFIG",
            "SYSTEM_PREFERENCES_CONFIG",
            "WATERMARK_CONFIG":
            return supportsAggregateConfig
        case "THUMB_LIST", "THUMB_GET":
            return supportsThumbnailBase64
        case "SNAPSHOT_CTRL", "SNAPSHOT_DATA":
            return supportsSnapshotBase64
        case "VI_GPS_RTDATA":
            return supportsRealtimeGPSData
        case "VIDEO_SYNC":
            return supportsGPSVideoOverlay
        case "VIDEO_SIZE":
            if command.operation == .get {
                return supportsVideo && supportedVideoResolutions.isEmpty == false
            }
            guard let resolutionList = command.parameters["str"]?.stringValue,
                  let selectedIndex = command.parameters["val"]?.intValue else {
                return false
            }
            let requestedResolutions = Self.semicolonStringList(resolutionList)
            guard requestedResolutions.indices.contains(selectedIndex) else {
                return false
            }
            return supportsVideo && supportedVideoResolutions.contains(requestedResolutions[selectedIndex])
        case "VIDEO_LOOP":
            if command.operation == .get {
                return supportsVideo && supportedVideoLoopModes.isEmpty == false
            }
            guard let cycle = command.parameters["cyc"]?.intValue else {
                return false
            }
            return supportsVideo && supportedVideoLoopModes.contains(cycle)
        case "VIDEO_DATE", "VIDEO_PARAM", "VIDEO_INV", "VIDEO_RDER":
            return supportsVideo
        case "PHOTO_RESO":
            if command.operation == .get {
                return supportsPhoto && supportedPhotoResolutions.isEmpty == false
            }
            guard let resolution = command.parameters["reso"]?.stringValue else {
                return false
            }
            return supportsPhoto && supportedPhotoResolutions.contains(resolution.lowercased())
        case "PHOTO_QUALITY":
            if command.operation == .get {
                return supportsPhoto && supportedPhotoQualities.isEmpty == false
            }
            guard let quality = command.parameters["quality"]?.stringValue else {
                return false
            }
            return supportsPhoto && supportedPhotoQualities.contains(quality.lowercased())
        case "PHOTO_DATE":
            return supportsPhoto
        case "VIDEO_WDR":
            return supportsVideoWideDynamicRange
        case "VIDEO_EXP":
            return supportsVideoExposure
        case "MIRROR_HOR":
            return supportsHorizontalMirror
        case "FLIP_VER":
            return supportsVerticalFlip
        case "LIGHT_FRE":
            if command.operation == .get {
                return supportedLightFrequencies.isEmpty == false
            }
            guard let frequency = command.parameters["freq"]?.stringValue else {
                return false
            }
            return supportedLightFrequencies.contains(frequency.lowercased())
        case "TV_MODE":
            if command.operation == .get {
                return supportedTVModes.isEmpty == false
            }
            guard let mode = command.parameters["mode"]?.stringValue else {
                return false
            }
            return supportedTVModes.contains(mode.lowercased())
        case "ANTI_TREMOR":
            return supportsAntiTremor
        case "IR_SWITCH":
            return supportsInfraredLight
        case "MOVE_CHECK":
            return supportsParking
        case "GRA_SEN", "VIDEO_PAR_VSIX":
            if command.operation == .get {
                return supportsParking && supportedParkingCollisionSensitivities.isEmpty == false
            }
            let parameterName = command.topic == "GRA_SEN" ? "gra" : "level"
            guard let sensitivity = command.parameters[parameterName]?.intValue else {
                return false
            }
            return supportsParking && supportedParkingCollisionSensitivities.contains(sensitivity)
        case "MONITOR_MODE":
            if command.operation == .get {
                return supportsParking && supportedParkingModes.isEmpty == false
            }
            guard let mode = command.parameters["mode"]?.intValue else {
                return false
            }
            return supportsParking && supportedParkingModes.contains(mode)
        case "MONITOR_TIME":
            if command.operation == .get {
                return supportsParking && supportedParkingMonitorDurations.isEmpty == false
            }
            guard let duration = command.parameters["gaplen"]?.intValue else {
                return false
            }
            return supportsParking && supportedParkingMonitorDurations.contains(duration)
        case "VOLTAGE_PRO":
            if command.operation == .get {
                return supportsParking && supportedVoltageProtectionIndexes.isEmpty == false
            }
            guard let threshold = command.parameters["vpr"]?.intValue else {
                return false
            }
            return supportsParking && supportedVoltageProtectionIndexes.contains(threshold)
        case "VIDEO_PAR_CAR":
            return supportsParking && supportsParkingGuard
        case "FILE_LOCK":
            return command.parameters["status"]?.intValue == 0 ? supportsFileUnlock : supportsFileLock
        case "AP_SSID_INFO":
            return command.operation == .get
                ? supportsWifiConfiguration
                : supportsWifiConfiguration && supportsWifiSSIDEditing && supportsWifiPasswordEditing
        case "SYSTEM_DEFAULT":
            return supportsFactoryReset
        case "AUTO_SHUTDOWN":
            return supportsAutoShutdown
        case "SCREEN_PRO":
            return supportsScreenProtection
        case "HOUR_TYPE":
            if command.operation == .get {
                return supportedHourTypes.isEmpty == false
            }
            guard let type = command.parameters["type"]?.intValue else {
                return false
            }
            return supportedHourTypes.contains(type)
        case "VIDEO_MIC":
            return supportsVideoMicrophone
        case "SPEAKER_VOLUME":
            return supportsSpeakerVolume
        case "SPEECH":
            return supportsSpeech
        case "KEY_VOICE":
            return supportsKeyVoice
        default:
            return true
        }
    }

    private static func intList(_ value: DeviceProtocolValue?) -> Set<Int> {
        guard case .array(let values)? = value else {
            return []
        }
        return Set(values.compactMap(\.intValue))
    }

    private static func stringList(_ value: DeviceProtocolValue?) -> Set<String> {
        guard case .array(let values)? = value else {
            return []
        }
        return Set(values.compactMap { $0.stringValue?.lowercased() })
    }

    private static func semicolonStringList(_ value: String) -> [String] {
        value.split(separator: ";").map { String($0).lowercased() }
    }

    private static func hasArrayValues(_ value: DeviceProtocolValue?) -> Bool {
        guard case .array(let values)? = value else {
            return false
        }
        return values.isEmpty == false
    }

    private static func indexList(_ value: DeviceProtocolValue?) -> Set<Int> {
        guard case .array(let values)? = value else {
            return []
        }
        return Set(values.indices)
    }

    private static func parkingModeList(_ value: DeviceProtocolValue?) -> Set<Int> {
        guard case .array(let values)? = value else {
            return []
        }

        return Set(values.compactMap { value in
            if let intValue = value.intValue {
                return intValue
            }
            switch value.stringValue?.lowercased() {
            case "off":
                return 0
            case "timelapse":
                return 1
            case "normal":
                return 2
            default:
                return nil
            }
        })
    }

    private static func videoLoopModeList(_ value: DeviceProtocolValue?) -> Set<Int> {
        guard case .array(let values)? = value else {
            return []
        }

        return Set(values.compactMap { value in
            if let intValue = value.intValue {
                return intValue
            }
            switch value.stringValue?.lowercased() {
            case "off":
                return 0
            case "1min":
                return 1
            case "3min":
                return 2
            case "5min":
                return 3
            case "10min":
                return 4
            default:
                return nil
            }
        })
    }

    private static func transportList(_ value: DeviceProtocolValue?, contains transport: String) -> Bool {
        guard case .array(let values)? = value else {
            return false
        }
        return values.contains { $0.stringValue?.caseInsensitiveCompare(transport) == .orderedSame }
    }

    private static func protocolVersion(_ version: String?, isAtLeast minimumVersion: [Int]) -> Bool {
        guard let version else {
            return false
        }

        let versionNumbers = version.split(separator: ".").map { Int($0) ?? 0 }
        guard versionNumbers.isEmpty == false else {
            return false
        }

        for index in 0..<max(versionNumbers.count, minimumVersion.count) {
            let versionNumber = index < versionNumbers.count ? versionNumbers[index] : 0
            let minimumNumber = index < minimumVersion.count ? minimumVersion[index] : 0
            if versionNumber != minimumNumber {
                return versionNumber > minimumNumber
            }
        }

        return true
    }
}

private protocol DeviceSessionCommandFailure: Error {
    static var sessionNotReady: Self { get }
    static var protocolClientUnavailable: Self { get }
    static var staleSession: Self { get }

    static func invalidResponse(_ reason: String) -> Self
    static func protocolFailure(_ error: DeviceProtocolError) -> Self
}

extension DeviceSessionReadOnlyError: DeviceSessionCommandFailure {}
extension DeviceSessionCommandError: DeviceSessionCommandFailure {}
