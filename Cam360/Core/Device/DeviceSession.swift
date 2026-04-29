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

    func fetchFileInfo(
        path: String,
        completion: @escaping (Result<DeviceFileInfo, DeviceSessionReadOnlyError>) -> Void
    ) {
        performReadOnlyCommand(.fileInfo(path: path), completion: completion) { message in
            try DeviceFileResponseParser.fileInfo(from: message.parameters)
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

    func send(_ event: DeviceSessionEvent) {
        let shouldDisconnectProtocol = shouldDisconnectProtocol(for: event)
        if shouldDisconnectProtocol {
            invalidateProtocolHandshake()
        }

        rememberRecoveryStateIfNeeded(for: event)

        let nextState = transition(from: state, event: event)
        let shouldInvalidateReadOnlyCommands = shouldInvalidateReadOnlyCommands(from: state, to: nextState)
        if nextState != state {
            state = nextState
        }

        updateDerivedState(for: nextState)

        if shouldInvalidateReadOnlyCommands {
            invalidateReadOnlyCommands()
        }

        if shouldDisconnectProtocol {
            protocolClient?.disconnect()
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

        case (.ready, .disconnect), (.busy, .disconnect), (.failed, .disconnect), (.recovering, .disconnect):
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
        guard state.canSendReadOnlyCommand else {
            completion(.failure(.sessionNotReady))
            return
        }

        guard let protocolClient else {
            completion(.failure(.protocolClientUnavailable))
            return
        }

        let generation = readOnlyCommandGeneration
        protocolClient.send(command) { [weak self] result in
            guard let self else {
                return
            }

            guard self.isCurrentReadOnlyCommand(generation) else {
                completion(.failure(.staleSession))
                return
            }

            switch result {
            case .success(let message):
                do {
                    completion(.success(try parse(message)))
                } catch let error as DeviceSessionReadOnlyError {
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

    private func nextHandshakeGeneration() -> Int {
        handshakeGeneration += 1
        return handshakeGeneration
    }

    private func invalidateProtocolHandshake() {
        handshakeGeneration += 1
    }

    private func invalidateReadOnlyCommands() {
        readOnlyCommandGeneration += 1
    }

    private func isCurrentHandshake(_ generation: Int) -> Bool {
        if case .handshaking = state {
            return generation == handshakeGeneration
        }
        return false
    }

    private func isCurrentReadOnlyCommand(_ generation: Int) -> Bool {
        state.canSendReadOnlyCommand && generation == readOnlyCommandGeneration
    }

    private func shouldInvalidateReadOnlyCommands(
        from currentState: DeviceSessionState,
        to nextState: DeviceSessionState
    ) -> Bool {
        currentState.canSendReadOnlyCommand && nextState.canSendReadOnlyCommand == false
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
        switch error {
        case .transportDisconnected:
            return "控制通道已断开"
        case .requestTimedOut(let topic):
            return "请求超时: \(topic)"
        case .deviceError(let errno, let topic, _):
            return "设备错误 errno \(errno): \(topic)"
        case .transportFailed(let message):
            return "传输失败: \(message)"
        case .invalidFrame:
            return "协议帧无效"
        case .encodeFailed:
            return "协议编码失败"
        case .decodeFailed:
            return "协议解码失败"
        case .responseWithoutRequest(let replyTo):
            return "未匹配的设备响应: \(replyTo)"
        }
    }

    private static func handshakeFailureReason(for error: DeviceProtocolError) -> String {
        protocolFailureReason(for: error)
    }
}
