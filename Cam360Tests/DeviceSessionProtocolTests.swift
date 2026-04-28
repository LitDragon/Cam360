import Foundation
import Testing
@testable import Cam360

@MainActor
struct DeviceSessionProtocolTests {
    @Test
    func protocolHandshakeSuccessMovesSessionToReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)

        #expect(await waitForSessionState { session.state.isConnected })
        #expect(
            session.state == .ready(
                DeviceInfo(
                    id: "112233445566778899",
                    name: "Road Camera",
                    firmwareVersion: "v1.0.1",
                    capabilities: [.livePreview, .playback, .download, .settings]
                )
            )
        )
        #expect(transport.sentMessages.map(\.topic) == DeviceProtocolHandshakePlan(appVersion: "1.2.3").commands.map(\.topic))
    }

    @Test
    func protocolHandshakeDeviceErrorMovesSessionToFailed() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request, errno: request.topic == "APP_ACCESS" ? -4 : 0)
        }

        startHandshake(session)

        #expect(await waitForSessionState { failedError(from: session.state) != nil })
        #expect(failedError(from: session.state) == .handshakeFailed(reason: "设备错误 errno -4: APP_ACCESS"))
    }

    @Test
    func protocolHandshakeTimeoutMovesSessionToFailed() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport, handshakeCommandTimeout: 0.05)
        transport.responseProvider = { _ in nil }

        startHandshake(session)

        #expect(await waitForSessionState { failedError(from: session.state) != nil })
        #expect(failedError(from: session.state) == .handshakeFailed(reason: "请求超时: APP_ACCESS"))
    }

    @Test
    func protocolDisconnectDuringHandshakeMovesSessionToConnectionLost() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport, handshakeCommandTimeout: 1)
        transport.responseProvider = { _ in nil }

        startHandshake(session)
        #expect(await waitForSessionState { transport.sentMessages.count == 1 })

        transport.pushDisconnect()

        #expect(await waitForSessionState { failedError(from: session.state) == .connectionLost })
    }

    @Test
    func protocolHandshakeResultAfterResetIsIgnored() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport, handshakeCommandTimeout: 1)
        transport.responseProvider = { _ in nil }

        startHandshake(session)
        #expect(await waitForSessionState { transport.sentMessages.count == 1 })
        guard let request = transport.sentMessages.first else {
            #expect(Bool(false))
            return
        }

        session.send(.reset)
        transport.push(makeHandshakeResponse(request))
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(session.state == .idle)
    }
}

private func makeSession(
    transport: SessionFakeDeviceProtocolTransport,
    handshakeCommandTimeout: TimeInterval = 1
) -> DeviceSession {
    DeviceSession(
        protocolClient: DeviceProtocolClient(transport: transport),
        appVersion: "1.2.3",
        deviceName: "Road Camera",
        handshakeCommandTimeout: handshakeCommandTimeout
    )
}

@MainActor
private func startHandshake(_ session: DeviceSession) {
    session.send(.startAPConnection(ssid: "Cam360_AP"))
    session.send(.apConnectionSucceeded)
    session.startProtocolHandshake()
}

private func makeHandshakeResponse(
    _ request: DeviceProtocolMessage,
    errno: Int = 0
) -> DeviceProtocolMessage {
    DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: errno,
        parameters: responseParameters(for: request.topic)
    )
}

private func responseParameters(for topic: String) -> [String: DeviceProtocolValue] {
    switch topic {
    case "UUID":
        return ["uuid": "112233445566778899"]
    case "FW_VERSION":
        return ["ver": "v1.0.1"]
    case "CAMERA_CAPABILITY":
        return [
            "capabilities": .object([
                "video": .object(["supported": true]),
                "file": .object(["thumbnail": true, "download": true]),
                "system": .object(["wifi_config": true])
            ])
        ]
    default:
        return [:]
    }
}

private func failedError(from state: DeviceSessionState) -> DeviceError? {
    if case .failed(let error) = state {
        return error
    }
    return nil
}

@MainActor
private func waitForSessionState(
    timeout: TimeInterval = 1,
    condition: @escaping @MainActor () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    return condition()
}

private final class SessionFakeDeviceProtocolTransport: DeviceProtocolTransport {
    var onReceiveData: ((Data) -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var responseProvider: ((DeviceProtocolMessage) -> DeviceProtocolMessage?)?
    private(set) var sentMessages: [DeviceProtocolMessage] = []

    private let codec = DeviceProtocolCodec()

    func connect(completion: @escaping (Result<Void, DeviceProtocolError>) -> Void) {
        completion(.success(()))
    }

    func send(_ data: Data, completion: @escaping (Result<Void, DeviceProtocolError>) -> Void) {
        do {
            let request = try codec.decode(data)
            sentMessages.append(request)
            completion(.success(()))

            if let response = responseProvider?(request) {
                push(response)
            }
        } catch let error as DeviceProtocolError {
            completion(.failure(error))
        } catch {
            completion(.failure(.decodeFailed))
        }
    }

    func disconnect() {
        onDisconnect?(nil)
    }

    func pushDisconnect() {
        onDisconnect?(nil)
    }

    func push(_ message: DeviceProtocolMessage) {
        guard let data = try? codec.encode(message) else {
            return
        }

        onReceiveData?(data)
    }
}
