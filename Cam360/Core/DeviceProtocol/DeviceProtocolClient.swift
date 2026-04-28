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

    private let transport: DeviceProtocolTransport
    private let codec: DeviceProtocolCodec
    private let callbackQueue: DispatchQueue
    private let stateQueue = DispatchQueue(label: "com.cam360.device-protocol-client")
    private var frameBuffer = DeviceProtocolFrameBuffer()
    private var pendingRequests: [String: PendingRequest] = [:]
    private var nextMessageIndex = 0

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
        completion: @escaping (Result<[DeviceProtocolMessage], DeviceProtocolError>) -> Void
    ) {
        sendHandshakeCommands(
            DeviceProtocolHandshakePlan(appVersion: appVersion).commands,
            responses: [],
            completion: completion
        )
    }

    private func sendHandshakeCommands(
        _ commands: [DeviceProtocolCommand],
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
                self?.sendHandshakeCommands(
                    Array(commands.dropFirst()),
                    responses: responses + [response],
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func handleIncomingData(_ data: Data) {
        stateQueue.async { [weak self] in
            guard let self else {
                return
            }

            let frameResults = self.frameBuffer.append(data)

            for frameResult in frameResults {
                switch frameResult {
                case .success(let message):
                    self.handleIncomingMessage(message)
                case .failure:
                    continue
                }
            }
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
            completePendingRequest(messageID: replyTo, result: .success(message))
        }
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
            self.frameBuffer.clear()

            self.callbackQueue.async {
                pendingRequests.values.forEach { request in
                    request.timeoutWorkItem.cancel()
                    request.completion(.failure(.transportDisconnected))
                }
            }
        }
    }
}

private struct PendingRequest {
    let topic: String
    let timeoutWorkItem: DispatchWorkItem
    let completion: (Result<DeviceProtocolMessage, DeviceProtocolError>) -> Void
}
