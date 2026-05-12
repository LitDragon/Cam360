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
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-events")
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
    func codecEncodesAndDecodesRoundTrip() throws {
        let codec = DeviceProtocolCodec()
        let original = DeviceProtocolMessage(
            topic: "VIDEO_CTRL",
            operation: .notify,
            messageID: "dev-1",
            notifyType: .response,
            replyTo: "app-1",
            errno: 0,
            parameters: ["status": 1, "path": "/DCIMA/REC00001.AVI"]
        )

        let encoded = try codec.encode(original)
        let decoded = try codec.decode(encoded)

        #expect(decoded.topic == original.topic)
        #expect(decoded.operation == original.operation)
        #expect(decoded.messageID == original.messageID)
        #expect(decoded.notifyType == original.notifyType)
        #expect(decoded.replyTo == original.replyTo)
        #expect(decoded.errno == original.errno)
        #expect(decoded.parameters["status"]?.intValue == 1)
        #expect(decoded.parameters["path"]?.stringValue == "/DCIMA/REC00001.AVI")
    }

    @Test
    func codecDecodeThrowsInvalidFrameForEmptyData() {
        let codec = DeviceProtocolCodec()

        #expect(throws: DeviceProtocolError.invalidFrame) {
            try codec.decode(Data())
        }
    }

    @Test
    func codecDecodeThrowsDecodeFailedForMalformedJSON() {
        let codec = DeviceProtocolCodec()

        #expect(throws: DeviceProtocolError.decodeFailed) {
            try codec.decode(Data("{bad-json}".utf8))
        }
    }

    @Test
    func notifyTypeDecodesShortAliases() throws {
        let codec = DeviceProtocolCodec()

        let req = try codec.decode(Data(#"{"topic":"T","op":"NOTIFY","msg_id":"1","notify_type":"req"}"#.utf8))
        #expect(req.notifyType == .request)

        let resp = try codec.decode(Data(#"{"topic":"T","op":"NOTIFY","msg_id":"1","notify_type":"resp","reply_to":"0"}"#.utf8))
        #expect(resp.notifyType == .response)

        let evt = try codec.decode(Data(#"{"topic":"T","op":"NOTIFY","msg_id":"1","notify_type":"evt"}"#.utf8))
        #expect(evt.notifyType == .event)
    }

    @Test
    func operationDecodesCaseInsensitive() throws {
        let codec = DeviceProtocolCodec()

        let get = try codec.decode(Data(#"{"topic":"T","op":"get","msg_id":"1"}"#.utf8))
        #expect(get.operation == .get)

        let post = try codec.decode(Data(#"{"topic":"T","op":"post","msg_id":"1"}"#.utf8))
        #expect(post.operation == .post)
    }

    @Test
    func protocolValueIntFromDouble() {
        let value = DeviceProtocolValue.double(3.0)
        #expect(value.intValue == 3)
    }

    @Test
    func protocolValueIntFromBool() {
        #expect(DeviceProtocolValue.bool(true).intValue == 1)
        #expect(DeviceProtocolValue.bool(false).intValue == 0)
    }

    @Test
    func protocolValueNullProperties() {
        let value = DeviceProtocolValue.null
        #expect(value.stringValue == nil)
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.objectValue == nil)
        #expect(value.arrayValue == nil)
    }

    @Test
    func protocolValueArrayDirectAccess() {
        let value = DeviceProtocolValue.array([.int(1), .int(2), .int(3)])
        #expect(value.arrayValue?.count == 3)
        #expect(value.arrayValue?[0].intValue == 1)
    }

    @Test
    func clientRoutesEventsThroughOnEventCallback() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-event-order")
        )
        let eventLock = NSLock()
        var events: [DeviceProtocolMessage] = []
        client.onEvent = { event in
            eventLock.withLock {
                events.append(event)
            }
        }

        transport.push(
            DeviceProtocolMessage(
                topic: "BAT_STATUS",
                operation: .notify,
                messageID: "evt-bat-1",
                notifyType: .event,
                errno: 0,
                parameters: ["level": 85]
            )
        )
        transport.push(
            DeviceProtocolMessage(
                topic: "SD_STATUS",
                operation: .notify,
                messageID: "evt-sd-1",
                notifyType: .event,
                errno: 0,
                parameters: ["online": 1]
            )
        )

        _ = waitUntil {
            eventLock.withLock { events.count == 2 }
        }

        #expect(eventLock.withLock { events.map(\.topic) } == ["BAT_STATUS", "SD_STATUS"])
        #expect(eventLock.withLock { events[0].parameters["level"]?.intValue } == 85)
        #expect(eventLock.withLock { events[1].parameters["online"]?.intValue } == 1)
    }

    // MARK: - DeviceFileResponseParser error paths

    @Test
    func fileListParserThrowsWhenFilesMissing() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.files 缺失")) {
            try DeviceFileResponseParser.fileListPage(from: [:])
        }
    }

    @Test
    func fileListParserThrowsWhenFilesContainsNonObject() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.files 包含非对象")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "files": .array([.string("not-an-object")])
            ])
        }
    }

    @Test
    func fileListParserThrowsWhenFileItemMissingName() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("文件 name 缺失")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "files": .array([
                    .object(["path": "/DCIMA/REC00001.AVI"])
                ])
            ])
        }
    }

    @Test
    func fileListParserThrowsWhenFileItemMissingPath() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("文件 path 缺失")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "files": .array([
                    .object(["name": "REC00001.AVI"])
                ])
            ])
        }
    }

    @Test
    func playbackResourceParserThrowsWhenPathMissing() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.path 缺失")) {
            try DeviceFileResponseParser.playbackResource(from: [:])
        }
    }

    @Test
    func playbackResourceParserThrowsWhenRtspURLMissing() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.rtsp_url 缺失")) {
            try DeviceFileResponseParser.playbackResource(from: [
                "path": "/DCIMA/REC00001.AVI"
            ])
        }
    }

    @Test
    func thumbnailsParserThrowsWhenThumbsMissing() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 缺失")) {
            try DeviceFileResponseParser.thumbnails(from: [:])
        }
    }

    @Test
    func thumbnailsParserThrowsWhenThumbsContainsNonObject() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 包含非对象")) {
            try DeviceFileResponseParser.thumbnails(from: [
                "thumbs": .array([.int(42)])
            ])
        }
    }

    @Test
    func thumbnailParserThrowsWhenPathMissing() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("THUMB_GET.path 缺失")) {
            try DeviceFileResponseParser.thumbnail(from: [:])
        }
    }

    @Test
    func snapshotIDParserThrowsWhenSnapshotIDMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.snapshot_id 缺失")) {
            try DeviceFileResponseParser.snapshotID(from: [:])
        }
    }

    @Test
    func snapshotResourceParserThrowsWhenSnapshotIDMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_DATA.snapshot_id 缺失")) {
            try DeviceFileResponseParser.snapshotResource(from: [:])
        }
    }

    @Test
    func recordingStateParserThrowsWhenStatusMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_CTRL.status 缺失")) {
            try DeviceFileResponseParser.recordingState(from: [:])
        }
    }

    @Test
    func fileDeletionResultParserThrowsWhenPathMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_DELETE.path 缺失")) {
            try DeviceFileResponseParser.fileDeletionResult(from: [:])
        }
    }

    @Test
    func fileDeletionResultParserThrowsWhenDeletedMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_DELETE.deleted 缺失")) {
            try DeviceFileResponseParser.fileDeletionResult(from: [
                "path": "/DCIMA/REC00001.AVI"
            ])
        }
    }

    @Test
    func fileLockResultParserThrowsWhenFileMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_LOCK.file 缺失")) {
            try DeviceFileResponseParser.fileLockResult(from: [:])
        }
    }

    @Test
    func fileLockResultParserThrowsWhenStatusMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_LOCK.status 缺失")) {
            try DeviceFileResponseParser.fileLockResult(from: [
                "file": "/DCIMA/REC00001.AVI"
            ])
        }
    }

    @Test
    func accessPointIdentityParserThrowsWhenSsidMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("AP_SSID_INFO.ssid 缺失")) {
            try DeviceFileResponseParser.accessPointIdentity(from: [:])
        }
    }

    @Test
    func storageFormatResultParserThrowsWhenFrmMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("FORMAT.frm 缺失")) {
            try DeviceFileResponseParser.storageFormatResult(from: [:])
        }
    }

    @Test
    func systemDefaultResultParserThrowsWhenDefMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SYSTEM_DEFAULT.def 缺失")) {
            try DeviceFileResponseParser.systemDefaultResult(from: [:])
        }
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

    @Test
    func dangerousCommandsUseConfirmedTopicsAndParameters() {
        let deleteFile = DeviceProtocolCommand.deleteFile(path: "/DCIMA/REC00001.AVI")
        let lockFile = DeviceProtocolCommand.setFileLocked(path: "/DCIMA/REC00001.AVI")
        let updateAccessPoint = DeviceProtocolCommand.updateAccessPointIdentity(
            ssid: "Cam360_New",
            password: "12345678"
        )

        #expect(deleteFile.topic == "FILE_DELETE")
        #expect(deleteFile.operation == .post)
        #expect(deleteFile.parameters["path"]?.stringValue == "/DCIMA/REC00001.AVI")

        #expect(lockFile.topic == "FILE_LOCK")
        #expect(lockFile.operation == .post)
        #expect(lockFile.parameters["file"]?.stringValue == "/DCIMA/REC00001.AVI")
        #expect(lockFile.parameters["status"]?.intValue == 1)

        #expect(DeviceProtocolCommand.accessPointIdentity.topic == "AP_SSID_INFO")
        #expect(DeviceProtocolCommand.accessPointIdentity.operation == .get)
        #expect(updateAccessPoint.topic == "AP_SSID_INFO")
        #expect(updateAccessPoint.operation == .post)
        #expect(updateAccessPoint.parameters["ssid"]?.stringValue == "Cam360_New")
        #expect(updateAccessPoint.parameters["pwd"]?.stringValue == "12345678")
        #expect(updateAccessPoint.parameters["status"]?.intValue == 1)

        #expect(DeviceProtocolCommand.formatStorage.topic == "FORMAT")
        #expect(DeviceProtocolCommand.formatStorage.operation == .post)
        #expect(DeviceProtocolCommand.restoreDefaultConfiguration.topic == "SYSTEM_DEFAULT")
        #expect(DeviceProtocolCommand.restoreDefaultConfiguration.operation == .post)
        #expect(DeviceProtocolCommand.restoreDefaultConfiguration.parameters["def"]?.intValue == 1)
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
