import Foundation
import Combine

protocol DeviceSessionProtocolClient: AnyObject {
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

    private let protocolClient: DeviceSessionProtocolClient?
    private let appVersion: String
    private let deviceName: String
    private let handshakeCommandTimeout: TimeInterval
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

        self.protocolClient?.onDisconnect = { [weak self] error in
            self?.handleProtocolDisconnect(error)
        }
    }

    func startProtocolHandshake() {
        guard case .handshaking = state else {
            return
        }

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
        performReadOnlyCommand(.fileInfo(path: path), completion: completion) { message in
            try DeviceFileResponseParser.fileInfo(from: message.parameters)
        }
    }

    func deleteFile(
        path: String,
        completion: @escaping (Result<DeviceFileDeletionResult, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.deleteFile(path: path), completion: completion) { message in
            try DeviceFileResponseParser.fileDeletionResult(from: message.parameters)
        }
    }

    func setFileLocked(
        path: String,
        locked: Bool = true,
        completion: @escaping (Result<DeviceFileLockResult, DeviceSessionCommandError>) -> Void
    ) {
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

    func fetchPlaybackResource(
        path: String,
        completion: @escaping (Result<DeviceFilePlaybackResource, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.filePlaybackResource(path: path), completion: completion) { message in
            try DeviceFileResponseParser.playbackResource(from: message.parameters)
        }
    }

    func fetchThumbnails(
        paths: [String],
        completion: @escaping (Result<[DeviceFileThumbnail], DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.thumbnailList(paths: paths), completion: completion) { message in
            try DeviceFileResponseParser.thumbnails(from: message.parameters)
        }
    }

    func fetchThumbnail(
        path: String,
        completion: @escaping (Result<DeviceFileThumbnail, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.thumbnail(path: path), completion: completion) { message in
            try DeviceFileResponseParser.thumbnail(from: message.parameters)
        }
    }

    func fetchRecordingState(
        completion: @escaping (Result<DeviceRecordingState, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.recordingState, completion: completion) { message in
            try DeviceFileResponseParser.recordingState(from: message.parameters)
        }
    }

    func setRecording(
        enabled: Bool,
        completion: @escaping (Result<DeviceRecordingState, DeviceSessionCommandError>) -> Void
    ) {
        performControlCommand(.setRecording(enabled: enabled), completion: completion) { message in
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
            let recoveredState = previousStateBeforeRecovery ?? .idle
            previousStateBeforeRecovery = nil
            return recoveredState

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
            send(.handshakeSucceeded(Self.deviceInfo(from: responses, fallbackName: deviceName)))
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
        let id = responsesByTopic["UUID"]?.parameters["uuid"]?.stringValue ?? "unknown-device"
        let firmwareVersion = responsesByTopic["FW_VERSION"]?.parameters["ver"]?.stringValue ?? "unknown"

        return DeviceInfo(
            id: id,
            name: fallbackName,
            firmwareVersion: firmwareVersion,
            capabilities: capabilities(from: responsesByTopic["CAMERA_CAPABILITY"]?.parameters["capabilities"])
        )
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

private protocol DeviceSessionCommandFailure: Error {
    static var sessionNotReady: Self { get }
    static var protocolClientUnavailable: Self { get }
    static var staleSession: Self { get }

    static func invalidResponse(_ reason: String) -> Self
    static func protocolFailure(_ error: DeviceProtocolError) -> Self
}

extension DeviceSessionReadOnlyError: DeviceSessionCommandFailure {}
extension DeviceSessionCommandError: DeviceSessionCommandFailure {}
