import Foundation
import Testing
@testable import Cam360

struct DeviceProtocolTests {
    @Test
    func codecDecodesResponseWithLegacyNumericStrings() throws {
        let rawMessage = """
        {"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":"app-1","errno":"0","param":{"level":"1"}}
        """

        let message = try DeviceProtocolCodec().decode(Data(rawMessage.utf8))

        #expect(message.topic == "BAT_STATUS")
        #expect(message.operation == .notify)
        #expect(message.notifyType == .response)
        #expect(message.replyTo == "app-1")
        #expect(message.errno == 0)
        #expect(message.parameters["level"]?.intValue == 1)
        #expect(message.parameters["level"]?.boolValue == true)
    }

    @Test
    func frameBufferReturnsCompleteMessagesFromSplitAndCoalescedFrames() throws {
        let codec = DeviceProtocolCodec()
        let first = DeviceProtocolMessage(
            topic: "SD_STATUS",
            operation: .notify,
            messageID: "evt-1",
            notifyType: .event,
            errno: 0,
            parameters: ["online": 1]
        )
        let second = DeviceProtocolMessage(
            topic: "VIDEO_CTRL",
            operation: .notify,
            messageID: "evt-2",
            notifyType: .event,
            errno: 0,
            parameters: ["status": 0]
        )
        let payload = try codec.encode(first) + codec.encode(second)
        let splitIndex = payload.index(payload.startIndex, offsetBy: 12)
        var buffer = DeviceProtocolFrameBuffer(codec: codec)

        #expect(buffer.append(payload[..<splitIndex]).isEmpty)

        let results = buffer.append(payload[splitIndex...])

        #expect(results.count == 2)
        let firstResult = try results[0].get()
        let secondResult = try results[1].get()
        #expect(firstResult.topic == first.topic)
        #expect(firstResult.notifyType == first.notifyType)
        #expect(firstResult.parameters["online"]?.intValue == 1)
        #expect(secondResult.topic == second.topic)
        #expect(secondResult.notifyType == second.notifyType)
        #expect(secondResult.parameters["status"]?.intValue == 0)
        #expect(buffer.bufferedByteCount == 0)
    }

    @Test
    func frameBufferDropsInvalidFrameWithoutBlockingNextMessage() throws {
        let codec = DeviceProtocolCodec()
        let validMessage = DeviceProtocolMessage(
            topic: "UUID",
            operation: .notify,
            messageID: "dev-1",
            notifyType: .response,
            replyTo: "app-1",
            errno: 0,
            parameters: ["uuid": "112233445566778899"]
        )
        var buffer = DeviceProtocolFrameBuffer(codec: codec)
        var payload = Data("{not-json}\n".utf8)
        payload.append(try codec.encode(validMessage))

        let results = buffer.append(payload)

        #expect(results.count == 2)
        switch results[0] {
        case .failure:
            break
        case .success:
            #expect(Bool(false))
        }
        let decodedMessage = try results[1].get()
        #expect(decodedMessage.topic == validMessage.topic)
        #expect(decodedMessage.replyTo == validMessage.replyTo)
        #expect(decodedMessage.parameters["uuid"]?.stringValue == "112233445566778899")
    }

    @Test
    func clientMatchesResponsesByReplyToAndRoutesEventsSeparately() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue.global(qos: .userInitiated)
        )
        let eventLock = NSLock()
        var events: [DeviceProtocolMessage] = []
        client.onEvent = { event in
            eventLock.withLock {
                events.append(event)
            }
        }
        transport.responseProvider = { request in
            DeviceProtocolMessage(
                topic: request.topic,
                operation: .notify,
                messageID: "dev-\(request.messageID)",
                notifyType: .response,
                replyTo: request.messageID,
                errno: 0,
                parameters: ["uuid": "112233445566778899"]
            )
        }

        let result = waitForResult { completion in
            client.send(.uuid, completion: completion)
        }
        transport.push(
            DeviceProtocolMessage(
                topic: "SD_STATUS",
                operation: .notify,
                messageID: "evt-1",
                notifyType: .event,
                errno: 0,
                parameters: ["online": 1]
            )
        )
        _ = waitUntil {
            eventLock.withLock {
                events.count == 1
            }
        }

        switch result {
        case .success(let response):
            #expect(response.topic == "UUID")
            #expect(response.parameters["uuid"]?.stringValue == "112233445566778899")
        case .failure, .none:
            #expect(Bool(false))
        }

        let firstEvent = eventLock.withLock {
            events.first
        }
        #expect(firstEvent?.topic == "SD_STATUS")
        #expect(transport.sentMessages.first?.topic == "UUID")
    }

    @Test
    func handshakeUsesIOSAppAccessAndExpectedReadSequence() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue.global(qos: .userInitiated)
        )
        transport.responseProvider = { request in
            DeviceProtocolMessage(
                topic: request.topic,
                operation: .notify,
                messageID: "dev-\(request.messageID)",
                notifyType: .response,
                replyTo: request.messageID,
                errno: 0,
                parameters: [:]
            )
        }

        let result = waitForResult { completion in
            client.startHandshake(appVersion: "1.2.3", completion: completion)
        }

        let expectedTopics = DeviceProtocolHandshakePlan(appVersion: "1.2.3").commands.map(\.topic)

        switch result {
        case .success(let responses):
            #expect(responses.map(\.topic) == expectedTopics)
        case .failure, .none:
            #expect(Bool(false))
        }

        #expect(transport.sentMessages.map(\.topic) == expectedTopics)
        #expect(transport.sentMessages.first?.topic == "APP_ACCESS")
        #expect(transport.sentMessages.first?.parameters["type"]?.intValue == 1)
        #expect(transport.sentMessages.first?.parameters["ver"]?.stringValue == "1.2.3")
    }

    @Test
    func controlCommandsUseConfirmedTopicsAndParameters() {
        let startRecording = DeviceProtocolCommand.setRecording(enabled: true)
        let stopRecording = DeviceProtocolCommand.setRecording(enabled: false)
        let snapshotControl = DeviceProtocolCommand.snapshotControl(mode: .preview)
        let snapshotData = DeviceProtocolCommand.snapshotData(snapshotID: "snap-1")

        #expect(DeviceProtocolCommand.recordingState.topic == "VIDEO_CTRL")
        #expect(DeviceProtocolCommand.recordingState.operation == .get)
        #expect(startRecording.topic == "VIDEO_CTRL")
        #expect(startRecording.operation == .post)
        #expect(startRecording.parameters["status"]?.intValue == 1)
        #expect(stopRecording.parameters["status"]?.intValue == 0)
        #expect(snapshotControl.topic == "SNAPSHOT_CTRL")
        #expect(snapshotControl.operation == .post)
        #expect(snapshotControl.parameters["mode"]?.stringValue == "preview")
        #expect(snapshotData.topic == "SNAPSHOT_DATA")
        #expect(snapshotData.operation == .get)
        #expect(snapshotData.parameters["snapshot_id"]?.stringValue == "snap-1")
    }
}

private final class FakeDeviceProtocolTransport: DeviceProtocolTransport {
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

    func push(_ message: DeviceProtocolMessage) {
        guard let data = try? codec.encode(message) else {
            return
        }

        onReceiveData?(data)
    }
}

private func waitForResult<T>(
    timeout: TimeInterval = 1,
    _ start: (@escaping (T) -> Void) -> Void
) -> T? {
    let semaphore = DispatchSemaphore(value: 0)
    var result: T?
    start {
        result = $0
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + timeout)
    return result
}

private func waitUntil(
    timeout: TimeInterval = 1,
    condition: @escaping () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        Thread.sleep(forTimeInterval: 0.01)
    }

    return condition()
}

private extension NSLock {
    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}
