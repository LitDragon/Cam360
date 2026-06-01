import Foundation

protocol DeviceProtocolTransport: AnyObject {
    var onReceiveData: ((Data) -> Void)? { get set }
    var onDisconnect: ((Error?) -> Void)? { get set }

    func connect(completion: @escaping (Result<Void, DeviceProtocolError>) -> Void)
    func send(_ data: Data, completion: @escaping (Result<Void, DeviceProtocolError>) -> Void)
    func disconnect()
}

final class DeviceProtocolClient {
    var onEvent: ((DeviceProtocolMessage) -> Void)?
    var onDisconnect: ((DeviceProtocolError?) -> Void)?

    private let transport: DeviceProtocolTransport
    private let codec: DeviceProtocolCodec
    private let callbackQueue: DispatchQueue
    private let partialFrameTimeout: TimeInterval = 5
    private let stateQueue = DispatchQueue(label: "com.cam360.device-protocol-client")
    private var frameBuffer = DeviceProtocolFrameBuffer()
    private var pendingRequests: [String: PendingRequest] = [:]
    private var nextMessageIndex = 0
    private var pendingDisconnectError: DeviceProtocolError?
    private var consecutiveDecodeFailureCount = 0
    private var partialFrameTimeoutGeneration = 0
    private var partialFrameTimeoutWorkItem: DispatchWorkItem?
    private var maximumControlFrameBytes = DeviceProtocolFrameBuffer.maxControlFrameBytes
    private var maximumMediaFrameBytes = DeviceProtocolFrameBuffer.maxMediaFrameBytes

    init(
        transport: DeviceProtocolTransport,
        codec: DeviceProtocolCodec = DeviceProtocolCodec(),
        callbackQueue: DispatchQueue = .main
    ) {
        self.transport = transport
        self.codec = codec
        self.callbackQueue = callbackQueue

        transport.onReceiveData = { [weak self] data in
            self?.handleIncomingData(data)
        }
        transport.onDisconnect = { [weak self] error in
            self?.handleDisconnect(error)
        }
    }

    func connect(completion: @escaping (Result<Void, DeviceProtocolError>) -> Void) {
        transport.connect { [callbackQueue] result in
            callbackQueue.async {
                completion(result)
            }
        }
    }

    func disconnect() {
        stateQueue.async { [weak self] in
            guard let self else {
                return
            }

            let pendingRequests = self.pendingRequests
            self.pendingRequests.removeAll()
            self.cancelPartialFrameTimeout()
            self.consecutiveDecodeFailureCount = 0
            self.frameBuffer.clear()

            self.callbackQueue.async {
                pendingRequests.values.forEach { request in
                    request.timeoutWorkItem.cancel()
                    request.completion(.failure(.transportDisconnected))
                }
            }

            self.transport.disconnect()
        }
    }

    func send(
        _ command: DeviceProtocolCommand,
        completion: @escaping (Result<DeviceProtocolMessage, DeviceProtocolError>) -> Void
    ) {
        stateQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.nextMessageIndex += 1
            let messageID = "ios-\(UUID().uuidString)-\(self.nextMessageIndex)"
            let message = command.message(messageID: messageID)
            let encodedMessage: Data

            do {
                encodedMessage = try self.codec.encode(message)
            } catch let error as DeviceProtocolError {
                self.callbackQueue.async {
                    completion(.failure(error))
                }
                return
            } catch {
                self.callbackQueue.async {
                    completion(.failure(.encodeFailed))
                }
                return
            }

            guard encodedMessage.count <= self.maximumControlFrameBytes else {
                self.callbackQueue.async {
                    completion(.failure(.invalidFrame))
                }
                return
            }

            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                self?.completePendingRequest(
                    messageID: messageID,
                    result: .failure(.requestTimedOut(topic: command.topic))
                )
            }

            self.pendingRequests[messageID] = PendingRequest(
                topic: command.topic,
                timeoutWorkItem: timeoutWorkItem,
                completion: completion
            )
            self.stateQueue.asyncAfter(deadline: .now() + command.timeout, execute: timeoutWorkItem)

            self.transport.send(encodedMessage) { [weak self] result in
                guard case .failure(let error) = result else {
                    return
                }
                self?.completePendingRequest(messageID: messageID, result: .failure(error))
            }
        }
    }

    func startHandshake(
        appVersion: String,
        commandTimeout: TimeInterval = 10,
        completion: @escaping (Result<[DeviceProtocolMessage], DeviceProtocolError>) -> Void
    ) {
        sendHandshakeCommands(
            DeviceProtocolHandshakePlan(appVersion: appVersion, commandTimeout: commandTimeout).commands,
            appVersion: appVersion,
            responses: [],
            completion: completion
        )
    }

    private func sendHandshakeCommands(
        _ commands: [DeviceProtocolCommand],
        appVersion: String,
        responses: [DeviceProtocolMessage],
        completion: @escaping (Result<[DeviceProtocolMessage], DeviceProtocolError>) -> Void
    ) {
        guard let command = commands.first else {
            completion(.success(responses))
            return
        }

        send(command) { [weak self] result in
            switch result {
            case .success(let response):
                if response.topic == "PROTOCOL_VERSION",
                   let minSupportedVersion = response.parameters["min_supported_ver"]?.stringValue,
                   Self.version(appVersion, isLowerThan: minSupportedVersion) {
                    completion(.failure(.unsupportedAppVersion(
                        appVersion: appVersion,
                        minSupportedVersion: minSupportedVersion
                    )))
                    return
                }
                self?.sendHandshakeCommands(
                    Array(commands.dropFirst()),
                    appVersion: appVersion,
                    responses: responses + [response],
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func version(_ version: String, isLowerThan minimumVersion: String) -> Bool {
        let versionNumbers = numericVersionComponents(from: version)
        let minimumNumbers = numericVersionComponents(from: minimumVersion)
        guard versionNumbers.isEmpty == false, minimumNumbers.isEmpty == false else {
            return false
        }

        for index in 0..<max(versionNumbers.count, minimumNumbers.count) {
            let versionNumber = index < versionNumbers.count ? versionNumbers[index] : 0
            let minimumNumber = index < minimumNumbers.count ? minimumNumbers[index] : 0
            if versionNumber != minimumNumber {
                return versionNumber < minimumNumber
            }
        }

        return false
    }

    private static func numericVersionComponents(from version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    private func handleIncomingData(_ data: Data) {
        stateQueue.async { [weak self] in
            guard let self else {
                return
            }

            let frameResults = self.frameBuffer.append(
                data,
                maximumControlFrameBytes: self.maximumControlFrameBytes,
                maximumMediaFrameBytes: self.maximumMediaFrameBytes,
                maximumBufferedFrameBytes: self.maximumBufferedFrameBytes
            )

            for frameResult in frameResults {
                switch frameResult {
                case .success(let message):
                    self.consecutiveDecodeFailureCount = 0
                    self.handleIncomingMessage(message)
                case .failure(.invalidFrame):
                    self.handleFatalFrameError(.invalidFrame)
                    return
                case .failure(.decodeFailed):
                    self.consecutiveDecodeFailureCount += 1
                    if self.consecutiveDecodeFailureCount >= 3 {
                        self.handleFatalFrameError(.decodeFailed)
                        return
                    }
                case .failure:
                    continue
                }
            }

            self.refreshPartialFrameTimeout()
        }
    }

    private func handleIncomingMessage(_ message: DeviceProtocolMessage) {
        if message.isEvent {
            callbackQueue.async { [onEvent] in
                onEvent?(message)
            }
            return
        }

        guard message.isResponse, let replyTo = message.replyTo else {
            return
        }

        if let errno = message.errno, errno != 0 {
            completePendingRequest(
                messageID: replyTo,
                result: .failure(.deviceError(errno: errno, topic: message.topic, parameters: message.parameters))
            )
        } else {
            applyNegotiatedFrameLimitsIfNeeded(from: message)
            completePendingRequest(messageID: replyTo, result: .success(message))
        }
    }

    private var maximumBufferedFrameBytes: Int {
        if pendingRequests.values.contains(where: {
            DeviceProtocolFrameBuffer.allowsExtendedMediaResponseFrame(topic: $0.topic)
        }) {
            return maximumMediaFrameBytes
        }

        return maximumControlFrameBytes
    }

    private func applyNegotiatedFrameLimitsIfNeeded(from message: DeviceProtocolMessage) {
        guard message.topic == "CAMERA_CAPABILITY",
              let protocolFields = message.parameters.object("capabilities")?.object("protocol") else {
            return
        }

        if let maxControlFrameBytes = Self.negotiatedFrameLimit(
            Self.negotiatedFrameLimitValue(protocolFields["max_control_frame_bytes"]),
            defaultLimit: DeviceProtocolFrameBuffer.maxControlFrameBytes
        ) {
            maximumControlFrameBytes = maxControlFrameBytes
        }

        if let maxMediaFrameBytes = Self.negotiatedFrameLimit(
            Self.negotiatedFrameLimitValue(protocolFields["max_media_frame_bytes"]),
            defaultLimit: DeviceProtocolFrameBuffer.maxMediaFrameBytes
        ) {
            maximumMediaFrameBytes = maxMediaFrameBytes
        }
    }

    private static func negotiatedFrameLimitValue(_ value: DeviceProtocolValue?) -> Int? {
        if case .bool? = value {
            return nil
        }

        return value?.intValue
    }

    private static func negotiatedFrameLimit(_ value: Int?, defaultLimit: Int) -> Int? {
        guard let value, value > 0 else {
            return nil
        }

        return min(value, defaultLimit)
    }

    private func completePendingRequest(
        messageID: String,
        result: Result<DeviceProtocolMessage, DeviceProtocolError>
    ) {
        stateQueue.async { [weak self] in
            guard let self, let pendingRequest = self.pendingRequests.removeValue(forKey: messageID) else {
                return
            }

            pendingRequest.timeoutWorkItem.cancel()
            self.callbackQueue.async {
                pendingRequest.completion(result)
            }
        }
    }

    private func handleDisconnect(_ error: Error?) {
        stateQueue.async { [weak self] in
            guard let self else {
                return
            }

            let pendingRequests = self.pendingRequests
            self.pendingRequests.removeAll()
            self.cancelPartialFrameTimeout()
            self.consecutiveDecodeFailureCount = 0
            self.frameBuffer.clear()
            let protocolError = self.pendingDisconnectError
                ?? error.map { DeviceProtocolError.transportFailed($0.localizedDescription) }
            self.pendingDisconnectError = nil

            self.callbackQueue.async {
                self.onDisconnect?(protocolError)
                pendingRequests.values.forEach { request in
                    request.timeoutWorkItem.cancel()
                    request.completion(.failure(.transportDisconnected))
                }
            }
        }
    }

    private func handleFatalFrameError(_ error: DeviceProtocolError) {
        let pendingRequests = self.pendingRequests
        self.pendingRequests.removeAll()
        self.cancelPartialFrameTimeout()
        self.consecutiveDecodeFailureCount = 0
        self.frameBuffer.clear()
        self.pendingDisconnectError = error

        self.callbackQueue.async {
            pendingRequests.values.forEach { request in
                request.timeoutWorkItem.cancel()
                request.completion(.failure(error))
            }
        }

        self.transport.disconnect()
    }

    private func refreshPartialFrameTimeout() {
        cancelPartialFrameTimeout()
        guard frameBuffer.bufferedByteCount > 0 else {
            return
        }

        partialFrameTimeoutGeneration += 1
        let generation = partialFrameTimeoutGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.partialFrameTimeoutGeneration == generation else {
                return
            }
            guard self.frameBuffer.bufferedByteCount > 0 else {
                return
            }

            self.handleFatalFrameError(.invalidFrame)
        }
        partialFrameTimeoutWorkItem = workItem
        stateQueue.asyncAfter(deadline: .now() + partialFrameTimeout, execute: workItem)
    }

    private func cancelPartialFrameTimeout() {
        partialFrameTimeoutWorkItem?.cancel()
        partialFrameTimeoutWorkItem = nil
        partialFrameTimeoutGeneration += 1
    }
}

private struct PendingRequest {
    let topic: String
    let timeoutWorkItem: DispatchWorkItem
    let completion: (Result<DeviceProtocolMessage, DeviceProtocolError>) -> Void
}
