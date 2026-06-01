import Foundation
import Testing
@testable import Cam360

private let validFirmwareUpgradeChecksum = "sha256:4a9b4f2b5d7e31c04a9b4f2b5d7e31c04a9b4f2b5d7e31c04a9b4f2b5d7e31c0"

private func expectCommandFlagInvalid(
    _ expectedReason: String,
    parameters: [String: DeviceProtocolValue],
    sourceLocation: SourceLocation = #_sourceLocation,
    parse: ([String: DeviceProtocolValue]) throws -> Void
) {
    #expect(throws: DeviceSessionCommandError.invalidResponse(expectedReason), sourceLocation: sourceLocation) {
        try parse(parameters)
    }
}

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
    func codecRejectsBooleanErrno() {
        let rawMessage = """
        {"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":"app-1","errno":true,"param":{"level":1}}
        """

        #expect(throws: DeviceProtocolError.decodeFailed) {
            try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
        }
    }

    @Test
    func codecRejectsNotifyDeviceMessagesMissingErrno() {
        let rawMessages = [
            #"{"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":"app-1","param":{"level":1}}"#,
            #"{"topic":"SD_STATUS","op":"notify","notify_type":"event","msg_id":"evt-1","param":{"online":1}}"#
        ]

        for rawMessage in rawMessages {
            #expect(throws: DeviceProtocolError.decodeFailed) {
                try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
            }
        }
    }

    @Test
    func codecRejectsMessagesMissingRequiredParam() {
        let rawMessage = """
        {"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":"app-1","errno":0}
        """

        #expect(throws: DeviceProtocolError.decodeFailed) {
            try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
        }
    }

    @Test
    func codecRejectsNonObjectParamValues() {
        let rawMessages = [
            #"{"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":"app-1","errno":0,"param":null}"#,
            #"{"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":"app-1","errno":0,"param":[]}"#
        ]

        for rawMessage in rawMessages {
            #expect(throws: DeviceProtocolError.decodeFailed) {
                try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
            }
        }
    }

    @Test
    func codecRejectsBlankTopicAndMessageID() {
        let rawMessages = [
            #"{"topic":" ","op":"notify","notify_type":"event","msg_id":"evt-1","errno":0,"param":{}}"#,
            #"{"topic":"SD_STATUS","op":"notify","notify_type":"event","msg_id":" ","errno":0,"param":{}}"#
        ]

        for rawMessage in rawMessages {
            #expect(throws: DeviceProtocolError.decodeFailed) {
                try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
            }
        }
    }

    @Test
    func codecRejectsBlankResponseReplyTo() {
        let rawMessage = """
        {"topic":"BAT_STATUS","op":"notify","notify_type":"response","msg_id":"dev-1","reply_to":" ","errno":0,"param":{"level":1}}
        """

        #expect(throws: DeviceProtocolError.decodeFailed) {
            try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
        }
    }

    @Test
    func codecRejectsNotifyMessagesMissingNotifyType() {
        let rawMessage = """
        {"topic":"SD_STATUS","op":"notify","msg_id":"evt-1","errno":0,"param":{"online":1}}
        """

        #expect(throws: DeviceProtocolError.decodeFailed) {
            try DeviceProtocolCodec().decode(Data(rawMessage.utf8))
        }
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
    func frameBufferRejectsOversizedControlFrame() throws {
        let codec = DeviceProtocolCodec()
        let oversizedResponse = oversizedResponseMessage(topic: "UUID", replyTo: "app-1")
        var buffer = DeviceProtocolFrameBuffer(codec: codec)

        let results = buffer.append(try codec.encode(oversizedResponse))

        #expect(results.count == 1)
        switch results[0] {
        case .failure(.invalidFrame):
            break
        default:
            #expect(Bool(false))
        }
        #expect(buffer.bufferedByteCount == 0)
    }

    @Test
    func frameBufferRejectsOversizedUnterminatedControlFrame() {
        var buffer = DeviceProtocolFrameBuffer()
        let payload = Data(repeating: 0x78, count: DeviceProtocolFrameBuffer.maxControlFrameBytes + 1)

        let results = buffer.append(payload)

        #expect(results.count == 1)
        switch results[0] {
        case .failure(.invalidFrame):
            break
        default:
            #expect(Bool(false))
        }
        #expect(buffer.bufferedByteCount == 0)
    }

    @Test
    func frameBufferAllowsOversizedMediaResponseWithinExtendedLimit() throws {
        let codec = DeviceProtocolCodec()
        let mediaResponse = oversizedResponseMessage(topic: "SNAPSHOT_DATA", replyTo: "app-1")
        var buffer = DeviceProtocolFrameBuffer(codec: codec)

        let results = buffer.append(try codec.encode(mediaResponse))

        #expect(results.count == 1)
        let decodedMessage = try results[0].get()
        #expect(decodedMessage.topic == "SNAPSHOT_DATA")
        #expect(decodedMessage.parameters["padding"]?.stringValue?.count == 70_000)
        #expect(buffer.bufferedByteCount == 0)
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
    func clientDisconnectsWhenIncomingControlFrameExceedsLimit() throws {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-frame-limit")
        )
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<DeviceProtocolMessage, DeviceProtocolError>?

        client.send(.uuid) { commandResult in
            result = commandResult
            semaphore.signal()
        }
        #expect(waitUntil { transport.sentMessages.count == 1 })

        transport.pushRaw(try DeviceProtocolCodec().encode(oversizedResponseMessage(topic: "UUID", replyTo: "ios-oversized")))

        _ = semaphore.wait(timeout: .now() + 1)
        switch result {
        case .failure(.invalidFrame):
            break
        default:
            #expect(Bool(false))
        }
        #expect(waitUntil { transport.disconnectCount == 1 })
    }

    @Test
    func clientDisconnectsWhenPartialFrameTimesOut() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-partial-frame-timeout")
        )
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<DeviceProtocolMessage, DeviceProtocolError>?

        client.send(.uuid) { commandResult in
            result = commandResult
            semaphore.signal()
        }
        #expect(waitUntil { transport.sentMessages.count == 1 })

        transport.pushRaw(Data(#"{"topic":"UUID""#.utf8))

        _ = semaphore.wait(timeout: .now() + 6)
        switch result {
        case .failure(.invalidFrame):
            break
        default:
            #expect(Bool(false))
        }
        #expect(waitUntil { transport.disconnectCount == 1 })
    }

    @Test
    func clientDisconnectsAfterThreeConsecutiveDecodeFailures() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-decode-failure-limit")
        )
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<DeviceProtocolMessage, DeviceProtocolError>?

        client.send(.uuid) { commandResult in
            result = commandResult
            semaphore.signal()
        }
        #expect(waitUntil { transport.sentMessages.count == 1 })

        transport.pushRaw(Data("{bad-json-1}\n".utf8))
        transport.pushRaw(Data("{bad-json-2}\n".utf8))
        transport.pushRaw(Data("{bad-json-3}\n".utf8))

        _ = semaphore.wait(timeout: .now() + 1)
        switch result {
        case .failure(.decodeFailed):
            break
        default:
            #expect(Bool(false))
        }
        #expect(waitUntil { transport.disconnectCount == 1 })
    }

    @Test
    func clientAllowsSplitExtendedMediaResponseWithinLimit() throws {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-media-frame-limit")
        )
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<DeviceProtocolMessage, DeviceProtocolError>?

        client.send(.snapshotData(snapshotID: "snap-1")) { commandResult in
            result = commandResult
            semaphore.signal()
        }
        #expect(waitUntil { transport.sentMessages.count == 1 })
        guard let replyTo = transport.sentMessages.first?.messageID else {
            #expect(Bool(false))
            return
        }

        let payload = try DeviceProtocolCodec().encode(
            oversizedResponseMessage(topic: "SNAPSHOT_DATA", replyTo: replyTo, paddingLength: 140_000)
        )
        var offset = 0
        while offset < payload.count {
            let end = min(offset + DeviceProtocolFrameBuffer.maxControlFrameBytes, payload.count)
            transport.pushRaw(payload.subdata(in: offset..<end))
            offset = end
        }

        _ = semaphore.wait(timeout: .now() + 1)
        switch result {
        case .success(let message):
            #expect(message.topic == "SNAPSHOT_DATA")
            #expect(message.parameters["padding"]?.stringValue?.count == 140_000)
        default:
            #expect(Bool(false))
        }
        #expect(transport.disconnectCount == 0)
    }

    @Test
    func clientAppliesNegotiatedSmallerControlFrameLimitToResponses() throws {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-negotiated-response-limit")
        )
        transport.responseProvider = { request in
            makeHandshakeResponse(request, maxControlFrameBytes: 512)
        }

        let handshake = waitForResult { completion in
            client.startHandshake(appVersion: "1.2.3", completion: completion)
        }
        guard case .success = handshake else {
            #expect(Bool(false))
            return
        }

        transport.responseProvider = nil
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<DeviceProtocolMessage, DeviceProtocolError>?

        client.send(.uuid) { commandResult in
            result = commandResult
            semaphore.signal()
        }
        #expect(waitUntil { transport.sentMessages.last?.topic == "UUID" })
        guard let replyTo = transport.sentMessages.last?.messageID else {
            #expect(Bool(false))
            return
        }

        transport.pushRaw(try DeviceProtocolCodec().encode(
            oversizedResponseMessage(topic: "UUID", replyTo: replyTo, paddingLength: 600)
        ))

        _ = semaphore.wait(timeout: .now() + 1)
        switch result {
        case .failure(.invalidFrame):
            break
        default:
            #expect(Bool(false))
        }
        #expect(waitUntil { transport.disconnectCount == 1 })
    }

    @Test
    func clientAppliesNegotiatedSmallerControlFrameLimitToRequests() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-negotiated-request-limit")
        )
        transport.responseProvider = { request in
            makeHandshakeResponse(request, maxControlFrameBytes: 512)
        }

        let handshake = waitForResult { completion in
            client.startHandshake(appVersion: "1.2.3", completion: completion)
        }
        guard case .success = handshake else {
            #expect(Bool(false))
            return
        }

        let sentCountAfterHandshake = transport.sentMessages.count
        let longPath = "/" + String(repeating: "x", count: 640)
        let result = waitForResult { completion in
            client.send(.thumbnailList(paths: [longPath]), completion: completion)
        }

        switch result {
        case .failure(.invalidFrame):
            break
        default:
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.count == sentCountAfterHandshake)
    }

    @Test
    func clientIgnoresBooleanNegotiatedFrameLimits() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue(label: "com.cam360.tests.device-protocol-boolean-frame-limits")
        )
        transport.responseProvider = { request in
            makeHandshakeResponse(request, protocolCapabilityOverrides: [
                "max_control_frame_bytes": true,
                "max_media_frame_bytes": false
            ])
        }

        let handshake = waitForResult { completion in
            client.startHandshake(appVersion: "1.2.3", completion: completion)
        }
        guard case .success = handshake else {
            #expect(Bool(false))
            return
        }

        let sentCountAfterHandshake = transport.sentMessages.count
        let result = waitForResult { completion in
            client.send(.uuid, completion: completion)
        }

        switch result {
        case .success(let response):
            #expect(response.topic == "UUID")
        default:
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.count == sentCountAfterHandshake + 1)
        #expect(transport.disconnectCount == 0)
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

        let expectedTopics = [
            "APP_ACCESS",
            "CTP_CMD_OPENAPP",
            "PROTOCOL_VERSION",
            "UUID",
            "FW_VERSION",
            "SD_STATUS",
            "BAT_STATUS",
            "TF_CAP",
            "CAMERA_CAPABILITY"
        ]

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
        #expect(transport.sentMessages.first?.parameters["protocol_ver"]?.stringValue == "1.2")
    }

    @Test
    func handshakeStopsWhenDeviceRequiresNewerAppVersion() {
        let transport = FakeDeviceProtocolTransport()
        let client = DeviceProtocolClient(
            transport: transport,
            callbackQueue: DispatchQueue.global(qos: .userInitiated)
        )
        transport.responseProvider = { request in
            let parameters: [String: DeviceProtocolValue]
            if request.topic == "PROTOCOL_VERSION" {
                parameters = [
                    "protocol_ver": "1.2",
                    "min_supported_ver": "2.0"
                ]
            } else {
                parameters = [:]
            }
            return DeviceProtocolMessage(
                topic: request.topic,
                operation: .notify,
                messageID: "dev-\(request.messageID)",
                notifyType: .response,
                replyTo: request.messageID,
                errno: 0,
                parameters: parameters
            )
        }

        let result = waitForResult { completion in
            client.startHandshake(appVersion: "1.0", completion: completion)
        }

        if case .failure(let error)? = result {
            #expect(DeviceProtocolFailureReason.message(for: error) == "APP 版本 1.0 低于设备最低支持 2.0")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.map(\.topic) == [
            "APP_ACCESS",
            "CTP_CMD_OPENAPP",
            "PROTOCOL_VERSION"
        ])
    }

    @Test
    func snapshotFaultsExposeScenarioSpecificMessages() {
        #expect(
            DeviceProtocolFailureReason.message(for: .deviceError(errno: -3, topic: "SNAPSHOT_CTRL", parameters: [:])) ==
                "截图失败: SNAPSHOT_CTRL (errno -3)"
        )
        #expect(
            DeviceProtocolFailureReason.message(for: .deviceError(errno: -7, topic: "SNAPSHOT_DATA", parameters: [:])) ==
                "截图数据超限: SNAPSHOT_DATA (errno -7)"
        )
        #expect(
            DeviceProtocolFailureReason.message(for: .requestTimedOut(topic: "SNAPSHOT_DATA")) ==
                "截图请求超时: SNAPSHOT_DATA"
        )
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

        let req = try codec.decode(Data(#"{"topic":"T","op":"NOTIFY","msg_id":"1","notify_type":"req","param":{}}"#.utf8))
        #expect(req.notifyType == .request)

        let resp = try codec.decode(Data(#"{"topic":"T","op":"NOTIFY","msg_id":"1","notify_type":"resp","reply_to":"0","errno":0,"param":{}}"#.utf8))
        #expect(resp.notifyType == .response)

        let evt = try codec.decode(Data(#"{"topic":"T","op":"NOTIFY","msg_id":"1","notify_type":"evt","errno":0,"param":{}}"#.utf8))
        #expect(evt.notifyType == .event)
    }

    @Test
    func operationDecodesCaseInsensitive() throws {
        let codec = DeviceProtocolCodec()

        let get = try codec.decode(Data(#"{"topic":"T","op":"get","msg_id":"1","param":{}}"#.utf8))
        #expect(get.operation == .get)

        let post = try codec.decode(Data(#"{"topic":"T","op":"post","msg_id":"1","param":{}}"#.utf8))
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
    func deviceBasicInfoParserUsesConfirmedResponseFields() throws {
        let info = try DeviceFileResponseParser.deviceBasicInfo(from: [
            "device_name": "Camera 360",
            "model": "C360-X1",
            "serial_no": "C360X1202605140001",
            "uuid": "112233445566778899",
            "fw_version": "v1.0.1",
            "protocol_version": "1.2"
        ])

        #expect(info.deviceName == "Camera 360")
        #expect(info.model == "C360-X1")
        #expect(info.serialNumber == "C360X1202605140001")
        #expect(info.uuid == "112233445566778899")
        #expect(info.firmwareVersion == "v1.0.1")
        #expect(info.protocolVersion == "1.2")
    }

    @Test
    func deviceBasicInfoParserRejectsBlankDocumentedRequiredFields() {
        let baseParameters: [String: DeviceProtocolValue] = [
            "device_name": "Camera 360",
            "model": "C360-X1",
            "serial_no": "C360X1202605140001",
            "uuid": "112233445566778899",
            "fw_version": "v1.0.1",
            "protocol_version": "1.2"
        ]

        for key in baseParameters.keys {
            var parameters = baseParameters
            parameters[key] = " "

            #expect(throws: DeviceSessionReadOnlyError.invalidResponse("DEVICE_INFO.\(key) 缺失")) {
                try DeviceFileResponseParser.deviceBasicInfo(from: parameters)
            }
        }
    }

    @Test
    func realtimeGPSDataParserUsesConfirmedResponseFields() throws {
        let data = try DeviceFileResponseParser.realtimeGPSData(from: [
            "info": "2022/05/27 21:20:29 N:22.525370 E:114.429984 0.00 km/h 0.00 25.70 8"
        ])

        #expect(data.info == "2022/05/27 21:20:29 N:22.525370 E:114.429984 0.00 km/h 0.00 25.70 8")
    }

    @Test
    func realtimeGPSDataParserRejectsBlankDocumentedInfoField() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("VI_GPS_RTDATA.info 缺失")) {
            try DeviceFileResponseParser.realtimeGPSData(from: [
                "info": " "
            ])
        }
    }

    @Test
    func hourTypeParserUsesConfirmedResponseFields() throws {
        let setting = try DeviceFileResponseParser.hourTypeSetting(from: [
            "type": 24
        ])

        #expect(setting.type == .twentyFourHour)
    }

    @Test
    func hourTypeParserRejectsBooleanTypeValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("HOUR_TYPE.type 缺失")) {
            try DeviceFileResponseParser.hourTypeSetting(from: [
                "type": true
            ])
        }
    }

    @Test
    func legacyRecordingSettingParsersUseConfirmedResponseFields() throws {
        let videoSize = try DeviceFileResponseParser.videoSizeSetting(from: [
            "str": "4K;2K;1080P",
            "val": 2
        ])
        let loop = try DeviceFileResponseParser.videoLoopSetting(from: [
            "cyc": 2
        ])
        let microphone = try DeviceFileResponseParser.videoMicrophoneSetting(from: [
            "mic": 1
        ])

        #expect(videoSize.supportedResolutions == ["4K", "2K", "1080P"])
        #expect(videoSize.selectedIndex == 2)
        #expect(loop.cycle == .threeMinutes)
        #expect(microphone.isEnabled == true)
    }

    @Test
    func legacyRecordingFlagParsersRejectInvalidDocumentedFlags() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid("VIDEO_MIC.mic 无效", parameters: ["mic": value]) {
                _ = try DeviceFileResponseParser.videoMicrophoneSetting(from: $0)
            }
        }
    }

    @Test
    func videoSizeParserRejectsBooleanSelectedIndexValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_SIZE.val 缺失")) {
            try DeviceFileResponseParser.videoSizeSetting(from: [
                "str": "4K;2K;1080P",
                "val": true
            ])
        }
    }

    @Test
    func videoSizeParserRejectsOutOfRangeSelectedIndexValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_SIZE.val 无效")) {
            try DeviceFileResponseParser.videoSizeSetting(from: [
                "str": "4K;2K;1080P",
                "val": 3
            ])
        }
    }

    @Test
    func videoLoopParserRejectsBooleanCycleValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_LOOP.cyc 缺失")) {
            try DeviceFileResponseParser.videoLoopSetting(from: [
                "cyc": true
            ])
        }
    }

    @Test
    func legacySafetySettingParsersUseConfirmedResponseFields() throws {
        let wideDynamicRange = try DeviceFileResponseParser.videoWideDynamicRangeSetting(from: [
            "wdr": 1
        ])
        let exposure = try DeviceFileResponseParser.videoExposureSetting(from: [
            "exp": 6
        ])
        let collisionSensitivity = try DeviceFileResponseParser.collisionSensitivitySetting(from: [
            "gra": 2
        ])
        let motionDetection = try DeviceFileResponseParser.motionDetectionSetting(from: [
            "mot": 1
        ])

        #expect(wideDynamicRange.isEnabled == true)
        #expect(exposure.level == .zero)
        #expect(collisionSensitivity.sensitivity == .medium)
        #expect(motionDetection.isEnabled == true)
    }

    @Test
    func legacySafetyFlagParsersRejectInvalidDocumentedFlags() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid("VIDEO_WDR.wdr 无效", parameters: ["wdr": value]) {
                _ = try DeviceFileResponseParser.videoWideDynamicRangeSetting(from: $0)
            }
            expectCommandFlagInvalid("MOVE_CHECK.mot 无效", parameters: ["mot": value]) {
                _ = try DeviceFileResponseParser.motionDetectionSetting(from: $0)
            }
        }
    }

    @Test
    func videoExposureParserRejectsBooleanLevelValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_EXP.exp 缺失")) {
            try DeviceFileResponseParser.videoExposureSetting(from: [
                "exp": true
            ])
        }
    }

    @Test
    func collisionSensitivityParserRejectsBooleanSensitivityValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("GRA_SEN.gra 缺失")) {
            try DeviceFileResponseParser.collisionSensitivitySetting(from: [
                "gra": true
            ])
        }
    }

    @Test
    func legacyParkingPowerSettingParsersUseConfirmedResponseFields() throws {
        let monitorMode = try DeviceFileResponseParser.parkingMonitorModeSetting(from: [
            "mode": 1
        ])
        let monitorDuration = try DeviceFileResponseParser.parkingMonitorDurationSetting(from: [
            "gaplen": 12
        ])
        let voltageProtection = try DeviceFileResponseParser.voltageProtectionSetting(from: [
            "vpr": 1
        ])

        #expect(monitorMode.mode == .timeLapse)
        #expect(monitorDuration.duration == .twelveHours)
        #expect(voltageProtection.threshold == .twelveVolts)
    }

    @Test
    func parkingMonitorModeParserRejectsBooleanModeValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("MONITOR_MODE.mode 缺失")) {
            try DeviceFileResponseParser.parkingMonitorModeSetting(from: [
                "mode": true
            ])
        }
    }

    @Test
    func parkingMonitorDurationParserRejectsBooleanDurationValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("MONITOR_TIME.gaplen 缺失")) {
            try DeviceFileResponseParser.parkingMonitorDurationSetting(from: [
                "gaplen": true
            ])
        }
    }

    @Test
    func voltageProtectionParserRejectsBooleanThresholdValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VOLTAGE_PRO.vpr 缺失")) {
            try DeviceFileResponseParser.voltageProtectionSetting(from: [
                "vpr": true
            ])
        }
    }

    @Test
    func legacyDisplayPowerSettingParsersUseConfirmedResponseFields() throws {
        let dateWatermark = try DeviceFileResponseParser.videoDateWatermarkSetting(from: [
            "dat": 1
        ])
        let horizontalMirror = try DeviceFileResponseParser.horizontalMirrorSetting(from: [
            "status": 1
        ])
        let verticalFlip = try DeviceFileResponseParser.verticalFlipSetting(from: [
            "status": 1
        ])
        let autoShutdown = try DeviceFileResponseParser.autoShutdownSetting(from: [
            "aff": 1
        ])
        let screenProtection = try DeviceFileResponseParser.screenProtectionSetting(from: [
            "pro": 2
        ])

        #expect(dateWatermark.isEnabled == true)
        #expect(horizontalMirror.isEnabled == true)
        #expect(verticalFlip.isEnabled == true)
        #expect(autoShutdown.delay == .threeMinutes)
        #expect(screenProtection.delay == .oneMinute)
    }

    @Test
    func legacyDisplayPowerFlagParsersRejectInvalidDocumentedFlags() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid("VIDEO_DATE.dat 无效", parameters: ["dat": value]) {
                _ = try DeviceFileResponseParser.videoDateWatermarkSetting(from: $0)
            }
            expectCommandFlagInvalid("MIRROR_HOR.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.horizontalMirrorSetting(from: $0)
            }
            expectCommandFlagInvalid("FLIP_VER.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.verticalFlipSetting(from: $0)
            }
        }
    }

    @Test
    func autoShutdownParserRejectsBooleanDelayValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("AUTO_SHUTDOWN.aff 缺失")) {
            try DeviceFileResponseParser.autoShutdownSetting(from: [
                "aff": true
            ])
        }
    }

    @Test
    func screenProtectionParserRejectsBooleanDelayValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SCREEN_PRO.pro 缺失")) {
            try DeviceFileResponseParser.screenProtectionSetting(from: [
                "pro": true
            ])
        }
    }

    @Test
    func legacyVideoPhotoDisplayParkingSettingParsersUseConfirmedResponseFields() throws {
        let videoParameter = try DeviceFileResponseParser.videoParameterSetting(from: [
            "w": 1280,
            "h": 720,
            "format": 1
        ])
        let photoResolution = try DeviceFileResponseParser.photoResolutionSetting(from: [
            "reso": "12M"
        ])
        let photoQuality = try DeviceFileResponseParser.photoQualitySetting(from: [
            "quality": "high"
        ])
        let photoDateWatermark = try DeviceFileResponseParser.photoDateWatermarkSetting(from: [
            "date": 1
        ])
        let tvMode = try DeviceFileResponseParser.tvModeSetting(from: [
            "mode": "PAL"
        ])
        let parkingGuard = try DeviceFileResponseParser.parkingGuardSetting(from: [
            "status": 1
        ])
        let parkingCollisionSensitivity = try DeviceFileResponseParser.parkingCollisionSensitivitySetting(from: [
            "level": 2
        ])

        #expect(videoParameter.width == 1280)
        #expect(videoParameter.height == 720)
        #expect(videoParameter.encodingFormat == .h264)
        #expect(photoResolution.resolution == "12M")
        #expect(photoQuality.quality == .high)
        #expect(photoDateWatermark.isEnabled == true)
        #expect(tvMode.mode == .pal)
        #expect(parkingGuard.isEnabled == true)
        #expect(parkingCollisionSensitivity.sensitivity == .high)
    }

    @Test
    func legacyVideoPhotoDisplayParkingFlagParsersRejectInvalidDocumentedFlags() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid("PHOTO_DATE.date 无效", parameters: ["date": value]) {
                _ = try DeviceFileResponseParser.photoDateWatermarkSetting(from: $0)
            }
            expectCommandFlagInvalid("VIDEO_PAR_CAR.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.parkingGuardSetting(from: $0)
            }
        }
    }

    @Test
    func stringSettingParsersTrimSimulatorNormalizedValues() throws {
        let photoResolution = try DeviceFileResponseParser.photoResolutionSetting(from: [
            "reso": " 12M "
        ])
        let photoQuality = try DeviceFileResponseParser.photoQualitySetting(from: [
            "quality": " high "
        ])
        let tvMode = try DeviceFileResponseParser.tvModeSetting(from: [
            "mode": " PAL "
        ])
        let lightFrequency = try DeviceFileResponseParser.lightFrequencySetting(from: [
            "freq": " 50Hz "
        ])

        #expect(photoResolution.resolution == "12M")
        #expect(photoQuality.quality == .high)
        #expect(tvMode.mode == .pal)
        #expect(lightFrequency.frequency == .hz50)
    }

    @Test
    func photoResolutionParserRejectsBlankResolutionValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("PHOTO_RESO.reso 缺失")) {
            try DeviceFileResponseParser.photoResolutionSetting(from: [
                "reso": " "
            ])
        }
    }

    @Test
    func parkingCollisionSensitivityParserRejectsBooleanLevelValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_PAR_VSIX.level 缺失")) {
            try DeviceFileResponseParser.parkingCollisionSensitivitySetting(from: [
                "level": true
            ])
        }
    }

    @Test
    func videoParameterParserRejectsBooleanWidthValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.w 缺失")) {
            try DeviceFileResponseParser.videoParameterSetting(from: [
                "w": true,
                "h": 720,
                "format": 1
            ])
        }
    }

    @Test
    func videoParameterParserRejectsBooleanHeightValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.h 缺失")) {
            try DeviceFileResponseParser.videoParameterSetting(from: [
                "w": 1280,
                "h": true,
                "format": 1
            ])
        }
    }

    @Test
    func videoParameterParserRejectsBooleanFormatValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.format 缺失")) {
            try DeviceFileResponseParser.videoParameterSetting(from: [
                "w": 1280,
                "h": 720,
                "format": true
            ])
        }
    }

    @Test
    func videoParameterParserRejectsUnsupportedDimensions() {
        let unsupportedDimensions: [[String: DeviceProtocolValue]] = [
            [
                "w": 1234,
                "h": 720,
                "format": 1
            ],
            [
                "w": -1280,
                "h": 720,
                "format": 1
            ]
        ]

        for parameters in unsupportedDimensions {
            #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_PARAM.w/h 无效")) {
                try DeviceFileResponseParser.videoParameterSetting(from: parameters)
            }
        }
    }

    @Test
    func legacyAuxiliarySettingParsersUseConfirmedResponseFields() throws {
        let intervalRecording = try DeviceFileResponseParser.intervalRecordingSetting(from: [
            "status": 1
        ])
        let gpsTimeSync = try DeviceFileResponseParser.gpsTimeSyncSetting(from: [
            "sync": 1
        ])
        let drivingRestReminder = try DeviceFileResponseParser.drivingRestReminderSetting(from: [
            "status": 1
        ])
        let lightFrequency = try DeviceFileResponseParser.lightFrequencySetting(from: [
            "freq": "50Hz"
        ])
        let speakerVolume = try DeviceFileResponseParser.speakerVolumeSetting(from: [
            "volume": 5
        ])
        let speech = try DeviceFileResponseParser.speechSetting(from: [
            "speech": 1
        ])
        let keyVoice = try DeviceFileResponseParser.keyVoiceSetting(from: [
            "voice": 1
        ])
        let antiTremor = try DeviceFileResponseParser.antiTremorSetting(from: [
            "status": 1
        ])
        let electronicDogVoice = try DeviceFileResponseParser.electronicDogVoiceSetting(from: [
            "status": 1
        ])
        let infraredLight = try DeviceFileResponseParser.infraredLightSetting(from: [
            "status": 1
        ])

        #expect(intervalRecording.isEnabled == true)
        #expect(gpsTimeSync.isEnabled == true)
        #expect(drivingRestReminder.isEnabled == true)
        #expect(lightFrequency.frequency == .hz50)
        #expect(speakerVolume.volume == 5)
        #expect(speech.isEnabled == true)
        #expect(keyVoice.isEnabled == true)
        #expect(antiTremor.isEnabled == true)
        #expect(electronicDogVoice.isEnabled == true)
        #expect(infraredLight.isEnabled == true)
    }

    @Test
    func legacyAuxiliaryFlagParsersRejectInvalidDocumentedFlags() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid("VIDEO_INV.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.intervalRecordingSetting(from: $0)
            }
            expectCommandFlagInvalid("VIDEO_SYNC.sync 无效", parameters: ["sync": value]) {
                _ = try DeviceFileResponseParser.gpsTimeSyncSetting(from: $0)
            }
            expectCommandFlagInvalid("VIDEO_RDER.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.drivingRestReminderSetting(from: $0)
            }
            expectCommandFlagInvalid("SPEECH.speech 无效", parameters: ["speech": value]) {
                _ = try DeviceFileResponseParser.speechSetting(from: $0)
            }
            expectCommandFlagInvalid("KEY_VOICE.voice 无效", parameters: ["voice": value]) {
                _ = try DeviceFileResponseParser.keyVoiceSetting(from: $0)
            }
            expectCommandFlagInvalid("ANTI_TREMOR.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.antiTremorSetting(from: $0)
            }
            expectCommandFlagInvalid("EDOG_VOICE.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.electronicDogVoiceSetting(from: $0)
            }
            expectCommandFlagInvalid("IR_SWITCH.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.infraredLightSetting(from: $0)
            }
        }
    }

    @Test
    func speakerVolumeParserRejectsBooleanVolumeValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SPEAKER_VOLUME.volume 缺失")) {
            try DeviceFileResponseParser.speakerVolumeSetting(from: ["volume": true])
        }
    }

    @Test
    func speakerVolumeParserRejectsOutOfRangeVolumeValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SPEAKER_VOLUME.volume 缺失")) {
            try DeviceFileResponseParser.speakerVolumeSetting(from: ["volume": 11])
        }
    }

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
    func fileListParserRejectsInvalidDocumentedPageType() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("FILE_LIST.type 无效")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "type": "audio",
                "files": .array([])
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
    func fileResponseParsersRejectBlankDocumentedPathFields() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("文件 path 缺失")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "files": .array([
                    .object([
                        "name": "REC00001.AVI",
                        "path": " "
                    ])
                ])
            ])
        }
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("FILE_DOWNLOAD_URL.path 缺失")) {
            try DeviceFileResponseParser.playbackResource(from: [
                "path": "\n",
                "rtsp_url": "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI"
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_DELETE.path 缺失")) {
            try DeviceFileResponseParser.fileDeletionResult(from: [
                "path": " ",
                "deleted": 1
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_LOCK.file 缺失")) {
            try DeviceFileResponseParser.fileLockResult(from: [
                "file": "\n",
                "status": 1
            ])
        }
    }

    @Test
    func fileListParserRejectsInvalidDocumentedFileType() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("文件 type 无效")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "files": .array([
                    .object([
                        "name": "REC00001.AVI",
                        "path": "/DCIMA/REC00001.AVI",
                        "type": "audio"
                    ])
                ])
            ])
        }
    }

    @Test
    func fileListParserRejectsBooleanLockedValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("文件 locked 无效")) {
            try DeviceFileResponseParser.fileListPage(from: [
                "files": .array([
                    .object([
                        "name": "REC00001.AVI",
                        "path": "/DCIMA/REC00001.AVI",
                        "locked": true
                    ])
                ])
            ])
        }
    }

    @Test
    func fileListParserRejectsInvalidDocumentedNumericFields() {
        func expectInvalid(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.fileListPage(from: [
                    "files": .array([
                        .object([
                            "name": "REC00001.AVI",
                            "path": "/DCIMA/REC00001.AVI",
                            key: value
                        ])
                    ])
                ])
            }
        }

        expectInvalid("size", true, "文件 size 无效")
        expectInvalid("size", -1, "文件 size 无效")
        expectInvalid("duration", true, "文件 duration 无效")
        expectInvalid("duration", -1, "文件 duration 无效")
    }

    @Test
    func fileInfoParserRejectsInvalidDocumentedNumericFields() {
        func expectInvalid(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.fileInfo(from: [
                    "name": "REC00001.AVI",
                    "path": "/DCIMA/REC00001.AVI",
                    key: value
                ])
            }
        }

        expectInvalid("bitrate", true, "FILE_INFO.bitrate 无效")
        expectInvalid("bitrate", -1, "FILE_INFO.bitrate 无效")
        expectInvalid("framerate", true, "FILE_INFO.framerate 无效")
        expectInvalid("framerate", -1, "FILE_INFO.framerate 无效")
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
    func playbackResourceParserKeepsRTSPConnectionMetadata() throws {
        let resource = try DeviceFileResponseParser.playbackResource(from: [
            "path": "/DCIMA/REC00001.AVI",
            "rtsp_url": "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI",
            "transport": "TCP",
            "size": 524_288_000,
            "duration": 180,
            "seekable": true,
            "session_timeout": 60,
            "auth_type": "digest",
            "username": "playback",
            "password": "one-shot-token",
            "max_sessions": 1,
            "seek_granularity_ms": 1_000,
            "keepalive_interval": 20
        ])

        #expect(resource.authType == "digest")
        #expect(resource.username == "playback")
        #expect(resource.password == "one-shot-token")
        #expect(resource.maxSessions == 1)
        #expect(resource.seekGranularityMilliseconds == 1_000)
        #expect(resource.keepaliveInterval == 20)
    }

    @Test
    func playbackResourceParserRejectsInvalidDocumentedRTSPMetadata() {
        let validParameters: [String: DeviceProtocolValue] = [
            "path": "/DCIMA/REC00001.AVI",
            "rtsp_url": "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI",
            "transport": "TCP",
            "size": 524_288_000,
            "duration": 180,
            "seekable": true,
            "session_timeout": 60,
            "auth_type": "digest",
            "username": "playback",
            "password": "one-shot-token",
            "max_sessions": 1,
            "seek_granularity_ms": 1_000,
            "keepalive_interval": 20
        ]

        func expectInvalid(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            var parameters = validParameters
            parameters[key] = value
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.playbackResource(from: parameters)
            }
        }

        expectInvalid("rtsp_url", "http://192.168.169.1/playback/DCIMA/REC00001.AVI", "FILE_DOWNLOAD_URL.rtsp_url 无效")
        expectInvalid("transport", "HTTP", "FILE_DOWNLOAD_URL.transport 无效")
        expectInvalid("auth_type", "token", "FILE_DOWNLOAD_URL.auth_type 无效")
        expectInvalid("size", -1, "FILE_DOWNLOAD_URL.size 无效")
        expectInvalid("duration", true, "FILE_DOWNLOAD_URL.duration 无效")
        expectInvalid("session_timeout", 0, "FILE_DOWNLOAD_URL.session_timeout 无效")
        expectInvalid("max_sessions", true, "FILE_DOWNLOAD_URL.max_sessions 无效")
        expectInvalid("seek_granularity_ms", 0, "FILE_DOWNLOAD_URL.seek_granularity_ms 无效")
        expectInvalid("keepalive_interval", -1, "FILE_DOWNLOAD_URL.keepalive_interval 无效")
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
    func thumbnailParserRejectsInvalidDocumentedBase64MediaFields() {
        let validParameters: [String: DeviceProtocolValue] = [
            "path": "/DCIMA/REC00001.AVI",
            "format": "JPEG",
            "width": 320,
            "height": 180,
            "size": 4,
            "image_base64": "AQIDBA=="
        ]

        func expectInvalid(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            var parameters = validParameters
            parameters[key] = value
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.thumbnail(from: parameters)
            }
        }

        expectInvalid("format", "PNG", "THUMB_GET.format 无效")
        expectInvalid("width", 0, "THUMB_GET.width 无效")
        expectInvalid("height", true, "THUMB_GET.height 无效")
        expectInvalid("size", .int(65 * 1024), "THUMB_GET.size 无效")
        expectInvalid("image_base64", "not-base64", "THUMB_GET.image_base64 无效")
        expectInvalid("image_base64", "", "THUMB_GET.image_base64 无效")
    }

    @Test
    func thumbnailsParserRejectsOversizedDocumentedBatch() {
        let oversizedImageBase64 = Data(repeating: 1, count: 64 * 1024).base64EncodedString()

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("THUMB_LIST.thumbs 总大小无效")) {
            try DeviceFileResponseParser.thumbnails(from: [
                "thumbs": .array((0..<9).map { index in
                    .object([
                        "path": .string("/DCIMA/REC\(index).AVI"),
                        "format": .string("JPEG"),
                        "width": .int(320),
                        "height": .int(180),
                        "size": .int(64 * 1024),
                        "image_base64": .string(oversizedImageBase64)
                    ])
                })
            ])
        }
    }

    @Test
    func snapshotIDParserThrowsWhenSnapshotIDMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.snapshot_id 缺失")) {
            try DeviceFileResponseParser.snapshotID(from: [:])
        }
    }

    @Test
    func snapshotIDParserThrowsWhenSnapshotIDBlank() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.snapshot_id 缺失")) {
            try DeviceFileResponseParser.snapshotID(from: ["snapshot_id": .string(" ")])
        }
    }

    @Test
    func snapshotControlParserRejectsInvalidDocumentedStatus() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.status 无效")) {
            try DeviceFileResponseParser.snapshotID(from: [
                "snapshot_id": .string("snap-1"),
                "status": .string("done")
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_CTRL.status 无效")) {
            try DeviceFileResponseParser.snapshotID(from: [
                "snapshot_id": .string("snap-1"),
                "status": .string(" ")
            ])
        }
    }

    @Test
    func snapshotResourceParserThrowsWhenSnapshotIDMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_DATA.snapshot_id 缺失")) {
            try DeviceFileResponseParser.snapshotResource(from: [:])
        }
    }

    @Test
    func snapshotResourceParserThrowsWhenSnapshotIDBlank() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SNAPSHOT_DATA.snapshot_id 缺失")) {
            try DeviceFileResponseParser.snapshotResource(from: ["snapshot_id": .string(" ")])
        }
    }

    @Test
    func snapshotResourceParserRejectsInvalidDocumentedBase64MediaFields() {
        let validParameters: [String: DeviceProtocolValue] = [
            "snapshot_id": "snap-1",
            "format": "JPEG",
            "width": 1280,
            "height": 720,
            "size": 4,
            "image_base64": "AQIDBA=="
        ]

        func expectInvalid(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            var parameters = validParameters
            parameters[key] = value
            #expect(throws: DeviceSessionCommandError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.snapshotResource(from: parameters)
            }
        }

        expectInvalid("format", "GIF", "SNAPSHOT_DATA.format 无效")
        expectInvalid("width", true, "SNAPSHOT_DATA.width 无效")
        expectInvalid("height", 0, "SNAPSHOT_DATA.height 无效")
        expectInvalid("size", .int((512 * 1024) + 1), "SNAPSHOT_DATA.size 无效")
        expectInvalid("image_base64", "not-base64", "SNAPSHOT_DATA.image_base64 无效")
        expectInvalid("image_base64", "", "SNAPSHOT_DATA.image_base64 无效")
    }

    @Test
    func recordingStateParserThrowsWhenStatusMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("VIDEO_CTRL.status 缺失")) {
            try DeviceFileResponseParser.recordingState(from: [:])
        }
    }

    @Test
    func recordingStateParserRejectsInvalidDocumentedStatusFlag() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid("VIDEO_CTRL.status 无效", parameters: ["status": value]) {
                _ = try DeviceFileResponseParser.recordingState(from: $0)
            }
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
    func fileDeletionResultParserRejectsInvalidDocumentedDeletedFlag() {
        func expectInvalid(
            _ value: DeviceProtocolValue,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_DELETE.deleted 无效"), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.fileDeletionResult(from: [
                    "path": "/DCIMA/REC00001.AVI",
                    "deleted": value
                ])
            }
        }

        expectInvalid(true)
        expectInvalid(2)
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
    func fileLockResultParserRejectsInvalidDocumentedStatusFlag() {
        func expectInvalid(
            _ value: DeviceProtocolValue,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionCommandError.invalidResponse("FILE_LOCK.status 无效"), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.fileLockResult(from: [
                    "file": "/DCIMA/REC00001.AVI",
                    "status": value
                ])
            }
        }

        expectInvalid(true)
        expectInvalid(2)
    }

    @Test
    func accessPointIdentityParserThrowsWhenSsidMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("AP_SSID_INFO.ssid 缺失")) {
            try DeviceFileResponseParser.accessPointIdentity(from: [:])
        }
    }

    @Test
    func accessPointIdentityParserRejectsInvalidDocumentedStatusFlag() {
        for value in [DeviceProtocolValue.bool(true), .int(2)] {
            expectCommandFlagInvalid(
                "AP_SSID_INFO.status 无效",
                parameters: ["ssid": "AP_XXF", "status": value]
            ) {
                _ = try DeviceFileResponseParser.accessPointIdentity(from: $0)
            }
        }
    }

    @Test
    func storageFormatResultParserThrowsWhenFrmMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("FORMAT.frm 缺失")) {
            try DeviceFileResponseParser.storageFormatResult(from: [:])
        }
    }

    @Test
    func storageFormatResultParserRejectsInvalidDocumentedFormatFlag() {
        func expectInvalid(
            _ value: DeviceProtocolValue,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionCommandError.invalidResponse("FORMAT.frm 无效"), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.storageFormatResult(from: [
                    "frm": value
                ])
            }
        }

        expectInvalid(true)
        expectInvalid(2)
    }

    @Test
    func systemDefaultResultParserThrowsWhenDefMissing() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("SYSTEM_DEFAULT.def 缺失")) {
            try DeviceFileResponseParser.systemDefaultResult(from: [:])
        }
    }

    @Test
    func systemDefaultResultParserRejectsInvalidDocumentedDefaultFlag() {
        func expectInvalid(
            _ value: DeviceProtocolValue,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionCommandError.invalidResponse("SYSTEM_DEFAULT.def 无效"), sourceLocation: sourceLocation) {
                try DeviceFileResponseParser.systemDefaultResult(from: [
                    "def": value
                ])
            }
        }

        expectInvalid(true)
        expectInvalid(2)
    }

    @Test
    func sdCardStatusParserRejectsBooleanOnlineValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("SD_STATUS.online 缺失")) {
            try DeviceFileResponseParser.sdCardStatus(from: ["online": true])
        }
    }

    @Test
    func sdCardStatusParserRejectsNegativeOnlineValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("SD_STATUS.online 缺失")) {
            try DeviceFileResponseParser.sdCardStatus(from: ["online": -1])
        }
    }

    @Test
    func batteryStatusParserRejectsBooleanLevelValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("BAT_STATUS.level 缺失")) {
            try DeviceFileResponseParser.batteryStatus(from: ["level": true])
        }
    }

    @Test
    func batteryStatusParserRejectsOutOfRangeLevelValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("BAT_STATUS.level 缺失")) {
            try DeviceFileResponseParser.batteryStatus(from: ["level": 5])
        }
    }

    @Test
    func storageCapacityParserRejectsBooleanRemainingValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("TF_CAP.left 缺失")) {
            try DeviceFileResponseParser.storageCapacity(from: [
                "left": true,
                "total": 22_222
            ])
        }
    }

    @Test
    func storageCapacityParserRejectsBooleanTotalValue() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("TF_CAP.total 缺失")) {
            try DeviceFileResponseParser.storageCapacity(from: [
                "left": 4_000,
                "total": true
            ])
        }
    }

    @Test
    func storageCapacityParserRejectsNegativeValues() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("TF_CAP.left 缺失")) {
            try DeviceFileResponseParser.storageCapacity(from: [
                "left": -1,
                "total": 22_222
            ])
        }
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("TF_CAP.total 缺失")) {
            try DeviceFileResponseParser.storageCapacity(from: [
                "left": 4_000,
                "total": -1
            ])
        }
    }

    @Test
    func storageCapacityParserRejectsRemainingGreaterThanTotal() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("TF_CAP.left 无效")) {
            try DeviceFileResponseParser.storageCapacity(from: [
                "left": 22_223,
                "total": 22_222
            ])
        }
    }

    @Test
    func firmwareUpgradeResultParsersUseConfirmedResponseFields() throws {
        let check = try DeviceFileResponseParser.firmwareUpgradeCheckResult(from: [
            "current_version": "v1.0.1",
            "latest_version": "v1.1.0",
            "has_update": 1,
            "upgrade_allowed": 1,
            "reason": "ok",
            "release_notes": .array([
                .string("优化录像稳定性"),
                .string("修复时间戳显示问题")
            ])
        ])
        let start = try DeviceFileResponseParser.firmwareUpgradeStartResult(from: [
            "task_id": "upgrade-task-20260514-0001",
            "accepted": 1,
            "status": "queued",
            "target_version": "v1.1.0"
        ])

        #expect(check.currentVersion == "v1.0.1")
        #expect(check.latestVersion == "v1.1.0")
        #expect(check.hasUpdate)
        #expect(check.upgradeAllowed)
        #expect(check.reason == "ok")
        #expect(check.releaseNotes == ["优化录像稳定性", "修复时间戳显示问题"])
        #expect(start.taskID == "upgrade-task-20260514-0001")
        #expect(start.accepted)
        #expect(start.status == "queued")
        #expect(start.targetVersion == "v1.1.0")
    }

    @Test
    func firmwareUpgradeResultParsersRejectBooleanFlags() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CHECK.has_update 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeCheckResult(from: [
                "current_version": "v1.0.1",
                "latest_version": "v1.1.0",
                "has_update": true,
                "upgrade_allowed": 1
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CHECK.upgrade_allowed 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeCheckResult(from: [
                "current_version": "v1.0.1",
                "latest_version": "v1.1.0",
                "has_update": 1,
                "upgrade_allowed": true
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.accepted 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeStartResult(from: [
                "task_id": "upgrade-task-20260514-0001",
                "accepted": true,
                "status": "queued",
                "target_version": "v1.1.0"
            ])
        }
    }

    @Test
    func firmwareUpgradeResultParsersRejectBlankRequiredStrings() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CHECK.current_version 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeCheckResult(from: [
                "current_version": " ",
                "latest_version": "v1.1.0",
                "has_update": 1,
                "upgrade_allowed": 1
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CHECK.latest_version 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeCheckResult(from: [
                "current_version": "v1.0.1",
                "latest_version": "\n",
                "has_update": 1,
                "upgrade_allowed": 1
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.task_id 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeStartResult(from: [
                "task_id": " ",
                "accepted": 1,
                "status": "queued",
                "target_version": "v1.1.0"
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.target_version 缺失")) {
            try DeviceFileResponseParser.firmwareUpgradeStartResult(from: [
                "task_id": "upgrade-task-20260514-0001",
                "accepted": 1,
                "status": "queued",
                "target_version": "\n"
            ])
        }
    }

    @Test
    func firmwareUpgradeStartParserRejectsInvalidDocumentedStatus() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.status 无效")) {
            try DeviceFileResponseParser.firmwareUpgradeStartResult(from: [
                "task_id": "upgrade-task-20260514-0001",
                "accepted": 1,
                "status": "done",
                "target_version": "v1.1.0"
            ])
        }
        #expect(throws: DeviceSessionCommandError.invalidResponse("UPGRADE_CTRL.status 无效")) {
            try DeviceFileResponseParser.firmwareUpgradeStartResult(from: [
                "task_id": "upgrade-task-20260514-0001",
                "accepted": 1,
                "status": " ",
                "target_version": "v1.1.0"
            ])
        }
    }

    @Test
    func dateTimeSyncResultParserUsesConfirmedResponseFields() throws {
        let result = try DeviceFileResponseParser.dateTimeSyncResult(from: [
            "date": "20230607103056",
            "tz_offset_min": 480
        ])

        #expect(result.date == "20230607103056")
        #expect(result.timeZoneOffsetMinutes == 480)
    }

    @Test
    func dateTimeSyncResultParserRejectsBooleanTimeZoneOffsetValue() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("DATE_TIME.tz_offset_min 缺失")) {
            try DeviceFileResponseParser.dateTimeSyncResult(from: [
                "date": "20230607103056",
                "tz_offset_min": true
            ])
        }
    }

    @Test
    func dateTimeSyncResultParserRejectsInvalidDocumentedDate() {
        #expect(throws: DeviceSessionCommandError.invalidResponse("DATE_TIME.date 无效")) {
            try DeviceFileResponseParser.dateTimeSyncResult(from: [
                "date": "20230230103056",
                "tz_offset_min": 480
            ])
        }
    }

    @Test
    func controlCommandsUseConfirmedTopicsAndParameters() {
        let startRecording = DeviceProtocolCommand.setRecording(enabled: true)
        let stopRecording = DeviceProtocolCommand.setRecording(enabled: false)
        let snapshotControl = DeviceProtocolCommand.snapshotControl(mode: .preview)
        let snapshotData = DeviceProtocolCommand.snapshotData(snapshotID: "snap-1")
        let dateTime = DeviceProtocolCommand.syncDateTime(
            date: "20230607103056",
            timeZoneOffsetMinutes: 480
        )

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
        #expect(dateTime.topic == "DATE_TIME")
        #expect(dateTime.operation == .post)
        #expect(dateTime.parameters["date"]?.stringValue == "20230607103056")
        #expect(dateTime.parameters["tz_offset_min"]?.intValue == 480)
    }

    @Test
    func deviceInfoCommandUsesConfirmedTopic() {
        #expect(DeviceProtocolCommand.deviceInfo.topic == "DEVICE_INFO")
        #expect(DeviceProtocolCommand.deviceInfo.operation == .get)
        #expect(DeviceProtocolCommand.deviceInfo.parameters.isEmpty)
    }

    @Test
    func realtimeGPSDataCommandUsesConfirmedTopic() {
        #expect(DeviceProtocolCommand.realtimeGPSData.topic == "VI_GPS_RTDATA")
        #expect(DeviceProtocolCommand.realtimeGPSData.operation == .get)
        #expect(DeviceProtocolCommand.realtimeGPSData.parameters.isEmpty)
    }

    @Test
    func hourTypeCommandsUseConfirmedTopicAndParameters() {
        let getHourType = DeviceProtocolCommand.hourType
        let setHourType = DeviceProtocolCommand.updateHourType(.twentyFourHour)

        #expect(getHourType.topic == "HOUR_TYPE")
        #expect(getHourType.operation == .get)
        #expect(getHourType.parameters.isEmpty)
        #expect(setHourType.topic == "HOUR_TYPE")
        #expect(setHourType.operation == .post)
        #expect(setHourType.parameters["type"]?.intValue == 24)
    }

    @Test
    func legacyRecordingSettingCommandsUseConfirmedTopicsAndParameters() {
        let getVideoSize = DeviceProtocolCommand.videoSize
        let setVideoSize = DeviceProtocolCommand.updateVideoSize(
            supportedResolutions: ["4K", "2K", "1080P"],
            selectedIndex: 2
        )
        let getLoop = DeviceProtocolCommand.videoLoop
        let setLoop = DeviceProtocolCommand.updateVideoLoop(.threeMinutes)
        let getMicrophone = DeviceProtocolCommand.videoMicrophone
        let setMicrophone = DeviceProtocolCommand.updateVideoMicrophone(isEnabled: false)

        #expect(getVideoSize.topic == "VIDEO_SIZE")
        #expect(getVideoSize.operation == .get)
        #expect(setVideoSize.topic == "VIDEO_SIZE")
        #expect(setVideoSize.operation == .post)
        #expect(setVideoSize.parameters["str"]?.stringValue == "4K;2K;1080P")
        #expect(setVideoSize.parameters["val"]?.intValue == 2)
        #expect(getLoop.topic == "VIDEO_LOOP")
        #expect(getLoop.operation == .get)
        #expect(setLoop.topic == "VIDEO_LOOP")
        #expect(setLoop.operation == .post)
        #expect(setLoop.parameters["cyc"]?.intValue == 2)
        #expect(getMicrophone.topic == "VIDEO_MIC")
        #expect(getMicrophone.operation == .get)
        #expect(setMicrophone.topic == "VIDEO_MIC")
        #expect(setMicrophone.operation == .post)
        #expect(setMicrophone.parameters["mic"]?.intValue == 0)
    }

    @Test
    func legacySafetySettingCommandsUseConfirmedTopicsAndParameters() {
        let getWideDynamicRange = DeviceProtocolCommand.videoWideDynamicRange
        let setWideDynamicRange = DeviceProtocolCommand.updateVideoWideDynamicRange(isEnabled: true)
        let getExposure = DeviceProtocolCommand.videoExposure
        let setExposure = DeviceProtocolCommand.updateVideoExposure(.zero)
        let getCollisionSensitivity = DeviceProtocolCommand.collisionSensitivity
        let setCollisionSensitivity = DeviceProtocolCommand.updateCollisionSensitivity(.medium)
        let getMotionDetection = DeviceProtocolCommand.motionDetection
        let setMotionDetection = DeviceProtocolCommand.updateMotionDetection(isEnabled: true)

        #expect(getWideDynamicRange.topic == "VIDEO_WDR")
        #expect(getWideDynamicRange.operation == .get)
        #expect(setWideDynamicRange.topic == "VIDEO_WDR")
        #expect(setWideDynamicRange.operation == .post)
        #expect(setWideDynamicRange.parameters["wdr"]?.intValue == 1)
        #expect(getExposure.topic == "VIDEO_EXP")
        #expect(getExposure.operation == .get)
        #expect(setExposure.topic == "VIDEO_EXP")
        #expect(setExposure.operation == .post)
        #expect(setExposure.parameters["exp"]?.intValue == 6)
        #expect(getCollisionSensitivity.topic == "GRA_SEN")
        #expect(getCollisionSensitivity.operation == .get)
        #expect(setCollisionSensitivity.topic == "GRA_SEN")
        #expect(setCollisionSensitivity.operation == .post)
        #expect(setCollisionSensitivity.parameters["gra"]?.intValue == 2)
        #expect(getMotionDetection.topic == "MOVE_CHECK")
        #expect(getMotionDetection.operation == .get)
        #expect(setMotionDetection.topic == "MOVE_CHECK")
        #expect(setMotionDetection.operation == .post)
        #expect(setMotionDetection.parameters["mot"]?.intValue == 1)
    }

    @Test
    func legacyParkingPowerSettingCommandsUseConfirmedTopicsAndParameters() {
        let getMonitorMode = DeviceProtocolCommand.parkingMonitorMode
        let setMonitorMode = DeviceProtocolCommand.updateParkingMonitorMode(.timeLapse)
        let getMonitorDuration = DeviceProtocolCommand.parkingMonitorDuration
        let setMonitorDuration = DeviceProtocolCommand.updateParkingMonitorDuration(.twelveHours)
        let getVoltageProtection = DeviceProtocolCommand.voltageProtection
        let setVoltageProtection = DeviceProtocolCommand.updateVoltageProtection(.twelveVolts)

        #expect(getMonitorMode.topic == "MONITOR_MODE")
        #expect(getMonitorMode.operation == .get)
        #expect(setMonitorMode.topic == "MONITOR_MODE")
        #expect(setMonitorMode.operation == .post)
        #expect(setMonitorMode.parameters["mode"]?.intValue == 1)
        #expect(getMonitorDuration.topic == "MONITOR_TIME")
        #expect(getMonitorDuration.operation == .get)
        #expect(setMonitorDuration.topic == "MONITOR_TIME")
        #expect(setMonitorDuration.operation == .post)
        #expect(setMonitorDuration.parameters["gaplen"]?.intValue == 12)
        #expect(getVoltageProtection.topic == "VOLTAGE_PRO")
        #expect(getVoltageProtection.operation == .get)
        #expect(setVoltageProtection.topic == "VOLTAGE_PRO")
        #expect(setVoltageProtection.operation == .post)
        #expect(setVoltageProtection.parameters["vpr"]?.intValue == 1)
    }

    @Test
    func legacyDisplayPowerSettingCommandsUseConfirmedTopicsAndParameters() {
        let getDateWatermark = DeviceProtocolCommand.videoDateWatermark
        let setDateWatermark = DeviceProtocolCommand.updateVideoDateWatermark(isEnabled: true)
        let getHorizontalMirror = DeviceProtocolCommand.horizontalMirror
        let setHorizontalMirror = DeviceProtocolCommand.updateHorizontalMirror(isEnabled: true)
        let getVerticalFlip = DeviceProtocolCommand.verticalFlip
        let setVerticalFlip = DeviceProtocolCommand.updateVerticalFlip(isEnabled: true)
        let getAutoShutdown = DeviceProtocolCommand.autoShutdown
        let setAutoShutdown = DeviceProtocolCommand.updateAutoShutdown(.threeMinutes)
        let getScreenProtection = DeviceProtocolCommand.screenProtection
        let setScreenProtection = DeviceProtocolCommand.updateScreenProtection(.oneMinute)

        #expect(getDateWatermark.topic == "VIDEO_DATE")
        #expect(getDateWatermark.operation == .get)
        #expect(setDateWatermark.topic == "VIDEO_DATE")
        #expect(setDateWatermark.operation == .post)
        #expect(setDateWatermark.parameters["dat"]?.intValue == 1)
        #expect(getHorizontalMirror.topic == "MIRROR_HOR")
        #expect(getHorizontalMirror.operation == .get)
        #expect(setHorizontalMirror.topic == "MIRROR_HOR")
        #expect(setHorizontalMirror.operation == .post)
        #expect(setHorizontalMirror.parameters["status"]?.intValue == 1)
        #expect(getVerticalFlip.topic == "FLIP_VER")
        #expect(getVerticalFlip.operation == .get)
        #expect(setVerticalFlip.topic == "FLIP_VER")
        #expect(setVerticalFlip.operation == .post)
        #expect(setVerticalFlip.parameters["status"]?.intValue == 1)
        #expect(getAutoShutdown.topic == "AUTO_SHUTDOWN")
        #expect(getAutoShutdown.operation == .get)
        #expect(setAutoShutdown.topic == "AUTO_SHUTDOWN")
        #expect(setAutoShutdown.operation == .post)
        #expect(setAutoShutdown.parameters["aff"]?.intValue == 1)
        #expect(getScreenProtection.topic == "SCREEN_PRO")
        #expect(getScreenProtection.operation == .get)
        #expect(setScreenProtection.topic == "SCREEN_PRO")
        #expect(setScreenProtection.operation == .post)
        #expect(setScreenProtection.parameters["pro"]?.intValue == 2)
    }

    @Test
    func legacyVideoPhotoDisplayParkingSettingCommandsUseConfirmedTopicsAndParameters() {
        let getVideoParameter = DeviceProtocolCommand.videoParameter
        let setVideoParameter = DeviceProtocolCommand.updateVideoParameter(
            width: 1280,
            height: 720,
            encodingFormat: .h264
        )
        let getPhotoResolution = DeviceProtocolCommand.photoResolution
        let setPhotoResolution = DeviceProtocolCommand.updatePhotoResolution("12M")
        let getPhotoQuality = DeviceProtocolCommand.photoQuality
        let setPhotoQuality = DeviceProtocolCommand.updatePhotoQuality(.high)
        let getPhotoDateWatermark = DeviceProtocolCommand.photoDateWatermark
        let setPhotoDateWatermark = DeviceProtocolCommand.updatePhotoDateWatermark(isEnabled: true)
        let getTVMode = DeviceProtocolCommand.tvMode
        let setTVMode = DeviceProtocolCommand.updateTVMode(.pal)
        let getParkingGuard = DeviceProtocolCommand.parkingGuard
        let setParkingGuard = DeviceProtocolCommand.updateParkingGuard(isEnabled: true)
        let getParkingCollisionSensitivity = DeviceProtocolCommand.parkingCollisionSensitivity
        let setParkingCollisionSensitivity = DeviceProtocolCommand.updateParkingCollisionSensitivity(.high)

        #expect(getVideoParameter.topic == "VIDEO_PARAM")
        #expect(getVideoParameter.operation == .get)
        #expect(setVideoParameter.topic == "VIDEO_PARAM")
        #expect(setVideoParameter.operation == .post)
        #expect(setVideoParameter.parameters["w"]?.intValue == 1280)
        #expect(setVideoParameter.parameters["h"]?.intValue == 720)
        #expect(setVideoParameter.parameters["format"]?.intValue == 1)
        #expect(getPhotoResolution.topic == "PHOTO_RESO")
        #expect(getPhotoResolution.operation == .get)
        #expect(setPhotoResolution.topic == "PHOTO_RESO")
        #expect(setPhotoResolution.operation == .post)
        #expect(setPhotoResolution.parameters["reso"]?.stringValue == "12M")
        #expect(getPhotoQuality.topic == "PHOTO_QUALITY")
        #expect(getPhotoQuality.operation == .get)
        #expect(setPhotoQuality.topic == "PHOTO_QUALITY")
        #expect(setPhotoQuality.operation == .post)
        #expect(setPhotoQuality.parameters["quality"]?.stringValue == "high")
        #expect(getPhotoDateWatermark.topic == "PHOTO_DATE")
        #expect(getPhotoDateWatermark.operation == .get)
        #expect(setPhotoDateWatermark.topic == "PHOTO_DATE")
        #expect(setPhotoDateWatermark.operation == .post)
        #expect(setPhotoDateWatermark.parameters["date"]?.intValue == 1)
        #expect(getTVMode.topic == "TV_MODE")
        #expect(getTVMode.operation == .get)
        #expect(setTVMode.topic == "TV_MODE")
        #expect(setTVMode.operation == .post)
        #expect(setTVMode.parameters["mode"]?.stringValue == "PAL")
        #expect(getParkingGuard.topic == "VIDEO_PAR_CAR")
        #expect(getParkingGuard.operation == .get)
        #expect(setParkingGuard.topic == "VIDEO_PAR_CAR")
        #expect(setParkingGuard.operation == .post)
        #expect(setParkingGuard.parameters["status"]?.intValue == 1)
        #expect(getParkingCollisionSensitivity.topic == "VIDEO_PAR_VSIX")
        #expect(getParkingCollisionSensitivity.operation == .get)
        #expect(setParkingCollisionSensitivity.topic == "VIDEO_PAR_VSIX")
        #expect(setParkingCollisionSensitivity.operation == .post)
        #expect(setParkingCollisionSensitivity.parameters["level"]?.intValue == 2)
    }

    @Test
    func legacyAuxiliarySettingCommandsUseConfirmedTopicsAndParameters() {
        let getIntervalRecording = DeviceProtocolCommand.intervalRecording
        let setIntervalRecording = DeviceProtocolCommand.updateIntervalRecording(isEnabled: true)
        let getGPSTimeSync = DeviceProtocolCommand.gpsTimeSync
        let setGPSTimeSync = DeviceProtocolCommand.updateGPSTimeSync(isEnabled: true)
        let getDrivingRestReminder = DeviceProtocolCommand.drivingRestReminder
        let setDrivingRestReminder = DeviceProtocolCommand.updateDrivingRestReminder(isEnabled: true)
        let getLightFrequency = DeviceProtocolCommand.lightFrequency
        let setLightFrequency = DeviceProtocolCommand.updateLightFrequency(.hz50)
        let getSpeakerVolume = DeviceProtocolCommand.speakerVolume
        let setSpeakerVolume = DeviceProtocolCommand.updateSpeakerVolume(5)
        let getSpeech = DeviceProtocolCommand.speech
        let setSpeech = DeviceProtocolCommand.updateSpeech(isEnabled: true)
        let getKeyVoice = DeviceProtocolCommand.keyVoice
        let setKeyVoice = DeviceProtocolCommand.updateKeyVoice(isEnabled: true)
        let getAntiTremor = DeviceProtocolCommand.antiTremor
        let setAntiTremor = DeviceProtocolCommand.updateAntiTremor(isEnabled: true)
        let getElectronicDogVoice = DeviceProtocolCommand.electronicDogVoice
        let setElectronicDogVoice = DeviceProtocolCommand.updateElectronicDogVoice(isEnabled: true)
        let getInfraredLight = DeviceProtocolCommand.infraredLight
        let setInfraredLight = DeviceProtocolCommand.updateInfraredLight(isEnabled: true)

        #expect(getIntervalRecording.topic == "VIDEO_INV")
        #expect(getIntervalRecording.operation == .get)
        #expect(setIntervalRecording.topic == "VIDEO_INV")
        #expect(setIntervalRecording.operation == .post)
        #expect(setIntervalRecording.parameters["status"]?.intValue == 1)
        #expect(getGPSTimeSync.topic == "VIDEO_SYNC")
        #expect(getGPSTimeSync.operation == .get)
        #expect(setGPSTimeSync.topic == "VIDEO_SYNC")
        #expect(setGPSTimeSync.operation == .post)
        #expect(setGPSTimeSync.parameters["sync"]?.intValue == 1)
        #expect(getDrivingRestReminder.topic == "VIDEO_RDER")
        #expect(getDrivingRestReminder.operation == .get)
        #expect(setDrivingRestReminder.topic == "VIDEO_RDER")
        #expect(setDrivingRestReminder.operation == .post)
        #expect(setDrivingRestReminder.parameters["status"]?.intValue == 1)
        #expect(getLightFrequency.topic == "LIGHT_FRE")
        #expect(getLightFrequency.operation == .get)
        #expect(setLightFrequency.topic == "LIGHT_FRE")
        #expect(setLightFrequency.operation == .post)
        #expect(setLightFrequency.parameters["freq"]?.stringValue == "50Hz")
        #expect(getSpeakerVolume.topic == "SPEAKER_VOLUME")
        #expect(getSpeakerVolume.operation == .get)
        #expect(setSpeakerVolume.topic == "SPEAKER_VOLUME")
        #expect(setSpeakerVolume.operation == .post)
        #expect(setSpeakerVolume.parameters["volume"]?.intValue == 5)
        #expect(getSpeech.topic == "SPEECH")
        #expect(getSpeech.operation == .get)
        #expect(setSpeech.topic == "SPEECH")
        #expect(setSpeech.operation == .post)
        #expect(setSpeech.parameters["speech"]?.intValue == 1)
        #expect(getKeyVoice.topic == "KEY_VOICE")
        #expect(getKeyVoice.operation == .get)
        #expect(setKeyVoice.topic == "KEY_VOICE")
        #expect(setKeyVoice.operation == .post)
        #expect(setKeyVoice.parameters["voice"]?.intValue == 1)
        #expect(getAntiTremor.topic == "ANTI_TREMOR")
        #expect(getAntiTremor.operation == .get)
        #expect(setAntiTremor.topic == "ANTI_TREMOR")
        #expect(setAntiTremor.operation == .post)
        #expect(setAntiTremor.parameters["status"]?.intValue == 1)
        #expect(getElectronicDogVoice.topic == "EDOG_VOICE")
        #expect(getElectronicDogVoice.operation == .get)
        #expect(setElectronicDogVoice.topic == "EDOG_VOICE")
        #expect(setElectronicDogVoice.operation == .post)
        #expect(setElectronicDogVoice.parameters["status"]?.intValue == 1)
        #expect(getInfraredLight.topic == "IR_SWITCH")
        #expect(getInfraredLight.operation == .get)
        #expect(setInfraredLight.topic == "IR_SWITCH")
        #expect(setInfraredLight.operation == .post)
        #expect(setInfraredLight.parameters["status"]?.intValue == 1)
    }

    @Test
    func firmwareUpgradeModelsRejectMalformedChecksums() {
        let invalidUpgradeCandidate: DeviceFirmwareUpgradeCandidate? = DeviceFirmwareUpgradeCandidate(
            latestVersion: "v1.1.0",
            packageSize: 33_554_432,
            checksum: "sha256:4a9b4f2b5d7e31",
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ==",
            releaseNotes: []
        )
        let invalidUpgradePackage: DeviceFirmwareUpgradePackage? = DeviceFirmwareUpgradePackage(
            targetVersion: "v1.1.0",
            packageURL: "http://192.168.25.2:8080/upgrade/fw-v1.1.0.bin",
            packageSize: 33_554_432,
            checksum: "sha256:4a9b4f2b5d7e31",
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ=="
        )

        #expect(invalidUpgradeCandidate == nil)
        #expect(invalidUpgradePackage == nil)
    }

    @Test
    func firmwareUpgradeModelsRejectBlankVersionFields() {
        let invalidUpgradeCandidate: DeviceFirmwareUpgradeCandidate? = DeviceFirmwareUpgradeCandidate(
            latestVersion: " ",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ==",
            releaseNotes: []
        )
        let invalidUpgradePackage: DeviceFirmwareUpgradePackage? = DeviceFirmwareUpgradePackage(
            targetVersion: "\n",
            packageURL: "http://192.168.25.2:8080/upgrade/fw-v1.1.0.bin",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ=="
        )

        #expect(invalidUpgradeCandidate == nil)
        #expect(invalidUpgradePackage == nil)
    }

    @Test
    func firmwareUpgradeModelsRejectInvalidTrustAndPackageFields() {
        let invalidPackageSize: DeviceFirmwareUpgradeCandidate? = DeviceFirmwareUpgradeCandidate(
            latestVersion: "v1.1.0",
            packageSize: 0,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ==",
            releaseNotes: []
        )
        let invalidRollbackIndex: DeviceFirmwareUpgradeCandidate? = DeviceFirmwareUpgradeCandidate(
            latestVersion: "v1.1.0",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 0,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ==",
            releaseNotes: []
        )
        let invalidSignature: DeviceFirmwareUpgradeCandidate? = DeviceFirmwareUpgradeCandidate(
            latestVersion: "v1.1.0",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "base64-signature",
            releaseNotes: []
        )
        let invalidPackageURL: DeviceFirmwareUpgradePackage? = DeviceFirmwareUpgradePackage(
            targetVersion: "v1.1.0",
            packageURL: "file:///tmp/fw-v1.1.0.bin",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ=="
        )

        #expect(invalidPackageSize == nil)
        #expect(invalidRollbackIndex == nil)
        #expect(invalidSignature == nil)
        #expect(invalidPackageURL == nil)
    }

    @Test
    func dangerousCommandsUseConfirmedTopicsAndParameters() throws {
        let deleteFile = DeviceProtocolCommand.deleteFile(path: "/DCIMA/REC00001.AVI")
        let lockFile = DeviceProtocolCommand.setFileLocked(path: "/DCIMA/REC00001.AVI")
        let updateAccessPoint = DeviceProtocolCommand.updateAccessPointIdentity(
            ssid: "Cam360_New",
            password: "12345678"
        )

        let upgradeCandidate = try #require(DeviceFirmwareUpgradeCandidate(
            latestVersion: "v1.1.0",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ==",
            releaseNotes: ["优化录像稳定性", "修复时间戳显示问题"]
        ))
        let upgradePackage = try #require(DeviceFirmwareUpgradePackage(
            targetVersion: "v1.1.0",
            packageURL: "http://192.168.25.2:8080/upgrade/fw-v1.1.0.bin",
            packageSize: 33_554_432,
            checksum: validFirmwareUpgradeChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ=="
        ))
        let upgradeCheck = DeviceProtocolCommand.firmwareUpgradeCheck(candidate: upgradeCandidate)
        let upgradeStart = DeviceProtocolCommand.startFirmwareUpgrade(package: upgradePackage)

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

        #expect(upgradeCheck.topic == "UPGRADE_CHECK")
        #expect(upgradeCheck.operation == .post)
        #expect(upgradeCheck.parameters["latest_version"]?.stringValue == "v1.1.0")
        #expect(upgradeCheck.parameters["package_size"]?.intValue == 33_554_432)
        #expect(upgradeCheck.parameters["checksum"]?.stringValue == validFirmwareUpgradeChecksum)
        #expect(upgradeCheck.parameters["rollback_index"]?.intValue == 2_026_052_501)
        #expect(upgradeCheck.parameters["signature_alg"]?.stringValue == "ed25519")
        #expect(upgradeCheck.parameters["signature"]?.stringValue == "YmFzZTY0LXNpZ25hdHVyZQ==")
        #expect(upgradeCheck.parameters["release_notes"]?.arrayValue?.map(\.stringValue) == [
            "优化录像稳定性",
            "修复时间戳显示问题"
        ])

        #expect(upgradeStart.topic == "UPGRADE_CTRL")
        #expect(upgradeStart.operation == .post)
        #expect(upgradeStart.parameters["action"]?.stringValue == "start")
        #expect(upgradeStart.parameters["target_version"]?.stringValue == "v1.1.0")
        #expect(upgradeStart.parameters["package_url"]?.stringValue == "http://192.168.25.2:8080/upgrade/fw-v1.1.0.bin")
        #expect(upgradeStart.parameters["package_size"]?.intValue == 33_554_432)
        #expect(upgradeStart.parameters["checksum"]?.stringValue == validFirmwareUpgradeChecksum)
        #expect(upgradeStart.parameters["rollback_index"]?.intValue == 2_026_052_501)
        #expect(upgradeStart.parameters["signature_alg"]?.stringValue == "ed25519")
        #expect(upgradeStart.parameters["signature"]?.stringValue == "YmFzZTY0LXNpZ25hdHVyZQ==")
    }

    @Test
    func aggregateCommandsUseConfirmedTopicsAndParameters() {
        let heartbeat = DeviceProtocolCommand.heartbeat(seq: 7, clientTime: "20260525103056")
        let stateSync = DeviceProtocolCommand.stateSync(scope: .initial)
        let mediaIndex = DeviceProtocolCommand.mediaIndex(
            query: DeviceMediaIndexQuery(mediaType: .video, groupBy: .date, eventOnly: true, pageNo: 2, pageSize: 8)
        )
        let recentEvents = DeviceProtocolCommand.recentEvents(
            query: DeviceRecentEventsQuery(limit: 4, eventType: "impact", includeLockedOnly: false)
        )

        #expect(heartbeat.topic == "HEARTBEAT")
        #expect(heartbeat.operation == .post)
        #expect(heartbeat.parameters["seq"]?.intValue == 7)
        #expect(heartbeat.parameters["client_time"]?.stringValue == "20260525103056")

        #expect(stateSync.topic == "STATE_SYNC")
        #expect(stateSync.operation == .get)
        #expect(stateSync.parameters["scope"]?.stringValue == "initial")

        #expect(mediaIndex.topic == "MEDIA_INDEX")
        #expect(mediaIndex.operation == .get)
        #expect(mediaIndex.parameters["media_type"]?.stringValue == "video")
        #expect(mediaIndex.parameters["group_by"]?.stringValue == "date")
        #expect(mediaIndex.parameters["event_only"]?.intValue == 1)
        #expect(mediaIndex.parameters["page_no"]?.intValue == 2)
        #expect(mediaIndex.parameters["page_size"]?.intValue == 8)

        #expect(recentEvents.topic == "RECENT_EVENTS")
        #expect(recentEvents.operation == .get)
        #expect(recentEvents.parameters["limit"]?.intValue == 4)
        #expect(recentEvents.parameters["event_type"]?.stringValue == "impact")
        #expect(recentEvents.parameters["include_locked_only"]?.intValue == 0)

        #expect(DeviceProtocolCommand.recordingConfiguration.topic == "RECORDING_CONFIG")
        #expect(DeviceProtocolCommand.safetyConfiguration.topic == "SAFETY_CONFIG")
        #expect(DeviceProtocolCommand.storagePolicyConfiguration.topic == "STORAGE_POLICY_CONFIG")
        #expect(DeviceProtocolCommand.systemPreferencesConfiguration.topic == "SYSTEM_PREFERENCES_CONFIG")
        #expect(DeviceProtocolCommand.watermarkConfiguration.topic == "WATERMARK_CONFIG")
    }

    @Test
    func handshakeUtilityCommandsDoNotSendInvalidOptionalFields() {
        let blankPage = DeviceProtocolCommand.openApp(page: " ")
        let paddedPage = DeviceProtocolCommand.openApp(page: " preview ")
        let exitApp = DeviceProtocolCommand.exitApp()
        let invalidHeartbeat = DeviceProtocolCommand.heartbeat(seq: 0, clientTime: "20260230103056")
        let paddedHeartbeat = DeviceProtocolCommand.heartbeat(seq: 8, clientTime: " 20260525103056 ")

        #expect(blankPage.topic == "CTP_CMD_OPENAPP")
        #expect(blankPage.parameters["page"] == nil)
        #expect(paddedPage.parameters["page"]?.stringValue == "preview")
        #expect(exitApp.topic == "CTP_CMD_EXITAPP")
        #expect(exitApp.parameters["reason"]?.stringValue == "user_leave")
        #expect(exitApp.parameters["page"] == nil)

        #expect(invalidHeartbeat.topic == "HEARTBEAT")
        #expect(invalidHeartbeat.parameters["seq"] == nil)
        #expect(invalidHeartbeat.parameters["client_time"] == nil)
        #expect(paddedHeartbeat.parameters["seq"]?.intValue == 8)
        #expect(paddedHeartbeat.parameters["client_time"]?.stringValue == "20260525103056")
    }

    @Test
    func readOnlyListQueriesClampDocumentedPaginationBounds() {
        let fileList = DeviceProtocolCommand.fileList(
            query: DeviceFileListQuery(type: .video, page: 0, pageSize: 101)
        )
        let mediaIndex = DeviceProtocolCommand.mediaIndex(
            query: DeviceMediaIndexQuery(mediaType: .video, groupBy: .date, eventOnly: false, pageNo: 0, pageSize: 101)
        )
        let recentEvents = DeviceProtocolCommand.recentEvents(
            query: DeviceRecentEventsQuery(limit: 21)
        )

        #expect(fileList.parameters["page"]?.intValue == 1)
        #expect(fileList.parameters["page_size"]?.intValue == 100)
        #expect(mediaIndex.parameters["page_no"]?.intValue == 1)
        #expect(mediaIndex.parameters["page_size"]?.intValue == 100)
        #expect(recentEvents.parameters["limit"]?.intValue == 20)
    }

    @Test
    func fileListQueryNormalizesDocumentedSortOptions() {
        let invalidSort = DeviceProtocolCommand.fileList(
            query: DeviceFileListQuery(sortBy: "latest", sortOrder: "up")
        )
        let paddedSort = DeviceProtocolCommand.fileList(
            query: DeviceFileListQuery(sortBy: " SIZE ", sortOrder: " ASC ")
        )
        let blankSort = DeviceProtocolCommand.fileList(
            query: DeviceFileListQuery(sortBy: " ", sortOrder: " ")
        )

        #expect(invalidSort.parameters["sort_by"]?.stringValue == "time")
        #expect(invalidSort.parameters["sort_order"]?.stringValue == "desc")
        #expect(paddedSort.parameters["sort_by"]?.stringValue == "size")
        #expect(paddedSort.parameters["sort_order"]?.stringValue == "asc")
        #expect(blankSort.parameters["sort_by"]?.stringValue == "time")
        #expect(blankSort.parameters["sort_order"]?.stringValue == "desc")
    }

    @Test
    func thumbnailListCommandClampsDocumentedPathLimit() throws {
        let paths = (1...25).map { String(format: "/DCIMA/REC%05d.AVI", $0) }

        let command = DeviceProtocolCommand.thumbnailList(paths: paths)

        guard case .array(let sentPaths) = try #require(command.parameters["paths"]) else {
            Issue.record("THUMB_LIST.paths 应为数组")
            return
        }
        #expect(sentPaths.count == 20)
        #expect(sentPaths.map(\.stringValue) == Array(paths.prefix(20)))
    }

    @Test
    func readOnlyListQueriesClampLowerPaginationBounds() {
        let fileList = DeviceProtocolCommand.fileList(
            query: DeviceFileListQuery(type: .video, page: -1, pageSize: 0)
        )
        let mediaIndex = DeviceProtocolCommand.mediaIndex(
            query: DeviceMediaIndexQuery(mediaType: .video, groupBy: .date, eventOnly: false, pageNo: -1, pageSize: 0)
        )
        let recentEvents = DeviceProtocolCommand.recentEvents(
            query: DeviceRecentEventsQuery(limit: 0)
        )

        #expect(fileList.parameters["page"]?.intValue == 1)
        #expect(fileList.parameters["page_size"]?.intValue == 1)
        #expect(mediaIndex.parameters["page_no"]?.intValue == 1)
        #expect(mediaIndex.parameters["page_size"]?.intValue == 1)
        #expect(recentEvents.parameters["limit"]?.intValue == 1)
    }

    @Test
    func recentEventsQueryNormalizesDocumentedEventType() {
        let uppercaseEventType = DeviceProtocolCommand.recentEvents(
            query: DeviceRecentEventsQuery(eventType: " IMPACT ")
        )
        let unsupportedEventType = DeviceProtocolCommand.recentEvents(
            query: DeviceRecentEventsQuery(eventType: "collision")
        )

        #expect(uppercaseEventType.parameters["event_type"]?.stringValue == "impact")
        #expect(unsupportedEventType.parameters["event_type"]?.stringValue == "all")
    }

    @Test
    func aggregateParsersAcceptDocumentedEventTimeDurationAndThumbnailFields() throws {
        let recentEvents = try DeviceAggregateResponseParser.recentEvents(from: [
            "items": .array([
                .object([
                    "event_id": "evt-20231027-143215-0001",
                    "path": "/DCIMA/REC00003.AVI",
                    "media_type": "video",
                    "event_type": "impact",
                    "title_key": "event.collision_detected",
                    "title": "Collision Detected",
                    "start_time": "2023-10-27 14:32:15",
                    "duration_sec": 240,
                    "size": 712_345_678,
                    "thumb_ready": 1,
                    "locked": 1
                ])
            ])
        ])

        #expect(recentEvents.items.first?.createTime == "2023-10-27 14:32:15")
        #expect(recentEvents.items.first?.duration == 240)
        #expect(recentEvents.items.first?.mediaType == .video)
        #expect(recentEvents.items.first?.titleKey == "event.collision_detected")
        #expect(recentEvents.items.first?.size == 712_345_678)
        #expect(recentEvents.items.first?.thumbReady == true)
        #expect(recentEvents.items.first?.locked == true)

        let mediaIndex = try DeviceAggregateResponseParser.mediaIndex(from: [
            "groups": .array([
                .object([
                    "group_key": "2023-10-27",
                    "items": .array([
                        .object([
                            "path": "/DCIMA/REC00003.AVI",
                            "media_type": "video",
                            "event_type": "impact",
                            "title_key": "event.collision_detected",
                            "title": "Collision Detected",
                            "start_time": "2023-10-27 14:32:15",
                            "duration_sec": 240,
                            "size": 712_345_678,
                            "locked": 1,
                            "thumb_ready": 1
                        ])
                    ])
                ])
            ])
        ])

        let item = mediaIndex.groups.first?.items.first
        #expect(item?.name == "REC00003.AVI")
        #expect(item?.createTime == "2023-10-27 14:32:15")
        #expect(item?.duration == 240)
        #expect(item?.mediaType == .video)
        #expect(item?.titleKey == "event.collision_detected")
        #expect(item?.hasThumbnail == true)
    }

    @Test
    func aggregateParsersRejectInvalidDocumentedEventNumericFields() {
        let validRecentEventItem: [String: DeviceProtocolValue] = [
            "event_id": "evt-20231027-143215-0001",
            "path": "/DCIMA/REC00003.AVI",
            "media_type": "video",
            "event_type": "impact",
            "start_time": "2023-10-27 14:32:15",
            "duration_sec": 240,
            "size": 712_345_678,
            "locked": 1,
            "thumb_ready": 1
        ]
        let validMediaIndexItem: [String: DeviceProtocolValue] = [
            "path": "/DCIMA/REC00003.AVI",
            "media_type": "video",
            "event_type": "impact",
            "start_time": "2023-10-27 14:32:15",
            "duration_sec": 240,
            "size": 712_345_678,
            "locked": 1,
            "thumb_ready": 1
        ]

        func expectInvalidRecentEvent(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            var item = validRecentEventItem
            item[key] = value
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceAggregateResponseParser.recentEvents(from: [
                    "items": .array([.object(item)])
                ])
            }
        }

        func expectInvalidMediaIndex(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            var item = validMediaIndexItem
            item[key] = value
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceAggregateResponseParser.mediaIndex(from: [
                    "groups": .array([
                        .object([
                            "group_key": "2023-10-27",
                            "items": .array([.object(item)])
                        ])
                    ])
                ])
            }
        }

        expectInvalidRecentEvent("duration_sec", true, "RECENT_EVENTS.duration_sec 无效")
        expectInvalidRecentEvent("duration_sec", -1, "RECENT_EVENTS.duration_sec 无效")
        expectInvalidRecentEvent("size", true, "RECENT_EVENTS.size 无效")
        expectInvalidRecentEvent("size", -1, "RECENT_EVENTS.size 无效")
        expectInvalidRecentEvent("locked", true, "RECENT_EVENTS.locked 无效")
        expectInvalidRecentEvent("locked", 2, "RECENT_EVENTS.locked 无效")
        expectInvalidRecentEvent("thumb_ready", true, "RECENT_EVENTS.thumb_ready 无效")
        expectInvalidRecentEvent("thumb_ready", -1, "RECENT_EVENTS.thumb_ready 无效")

        expectInvalidMediaIndex("duration_sec", true, "MEDIA_INDEX.duration_sec 无效")
        expectInvalidMediaIndex("duration_sec", -1, "MEDIA_INDEX.duration_sec 无效")
        expectInvalidMediaIndex("size", true, "MEDIA_INDEX.size 无效")
        expectInvalidMediaIndex("size", -1, "MEDIA_INDEX.size 无效")
        expectInvalidMediaIndex("locked", true, "MEDIA_INDEX.locked 无效")
        expectInvalidMediaIndex("locked", 2, "MEDIA_INDEX.locked 无效")
        expectInvalidMediaIndex("thumb_ready", true, "MEDIA_INDEX.thumb_ready 无效")
        expectInvalidMediaIndex("thumb_ready", -1, "MEDIA_INDEX.thumb_ready 无效")
    }

    @Test
    func recentEventsParserRejectsInvalidDocumentedPageMetadata() {
        let validItem: DeviceProtocolValue = .object([
            "event_id": "evt-20231027-143215-0001",
            "path": "/DCIMA/REC00003.AVI",
            "media_type": "video",
            "event_type": "impact"
        ])

        func expectInvalidPageMetadata(
            _ key: String,
            _ value: DeviceProtocolValue,
            _ message: String,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(throws: DeviceSessionReadOnlyError.invalidResponse(message), sourceLocation: sourceLocation) {
                try DeviceAggregateResponseParser.recentEvents(from: [
                    key: value,
                    "items": .array([validItem])
                ])
            }
        }

        expectInvalidPageMetadata("limit", true, "RECENT_EVENTS.limit 无效")
        expectInvalidPageMetadata("limit", 21, "RECENT_EVENTS.limit 无效")
        expectInvalidPageMetadata("total_recent_count", true, "RECENT_EVENTS.total_recent_count 无效")
        expectInvalidPageMetadata("total_recent_count", -1, "RECENT_EVENTS.total_recent_count 无效")
    }

    @Test
    func aggregateParsersRejectBlankDocumentedStableIdentifiers() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.event_id 缺失")) {
            try DeviceAggregateResponseParser.recentEvents(from: [
                "items": .array([
                    .object([
                        "event_id": " ",
                        "path": "/DCIMA/REC00003.AVI",
                        "media_type": "video",
                        "event_type": "impact"
                    ])
                ])
            ])
        }

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.path 缺失")) {
            try DeviceAggregateResponseParser.recentEvents(from: [
                "items": .array([
                    .object([
                        "event_id": "evt-20231027-143215-0001",
                        "path": " ",
                        "media_type": "video",
                        "event_type": "impact"
                    ])
                ])
            ])
        }

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.group_key 缺失")) {
            try DeviceAggregateResponseParser.mediaIndex(from: [
                "groups": .array([
                    .object([
                        "group_key": " ",
                        "items": .array([
                            .object([
                                "path": "/DCIMA/REC00003.AVI",
                                "media_type": "video"
                            ])
                        ])
                    ])
                ])
            ])
        }

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.path 缺失")) {
            try DeviceAggregateResponseParser.mediaIndex(from: [
                "groups": .array([
                    .object([
                        "group_key": "2023-10-27",
                        "items": .array([
                            .object([
                                "path": " ",
                                "media_type": "video"
                            ])
                        ])
                    ])
                ])
            ])
        }
    }

    @Test
    func aggregateParsersRejectInvalidDocumentedMediaType() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("RECENT_EVENTS.media_type 无效")) {
            try DeviceAggregateResponseParser.recentEvents(from: [
                "items": .array([
                    .object([
                        "event_id": "evt-20231027-143215-0001",
                        "path": "/DCIMA/REC00003.AVI",
                        "media_type": "audio",
                        "event_type": "impact"
                    ])
                ])
            ])
        }
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("MEDIA_INDEX.media_type 无效")) {
            try DeviceAggregateResponseParser.mediaIndex(from: [
                "groups": .array([
                    .object([
                        "items": .array([
                            .object([
                                "path": "/DCIMA/REC00003.AVI",
                                "media_type": " "
                            ])
                        ])
                    ])
                ])
            ])
        }
    }

    @Test
    func aggregateParsersPreferClientEventTitleMappingOverDeviceTitle() throws {
        let recentEvents = try DeviceAggregateResponseParser.recentEvents(from: [
            "items": .array([
                .object([
                    "event_id": "evt-1",
                    "path": "/DCIMA/REC00003.AVI",
                    "event_type": "impact",
                    "title": "Device Supplied Title"
                ])
            ])
        ])

        #expect(recentEvents.items.first?.title == "Collision Detected")

        let mediaIndex = try DeviceAggregateResponseParser.mediaIndex(from: [
            "groups": .array([
                .object([
                    "items": .array([
                        .object([
                            "path": "/DCIMA/REC00003.AVI",
                            "event_type": "parking",
                            "title": "Device Supplied Title"
                        ])
                    ])
                ])
            ])
        ])

        #expect(mediaIndex.groups.first?.items.first?.title == "Parking Incident")
    }

    @Test
    func aggregateParsersMapStableNormalAndPhotoEventTypes() throws {
        let recentEvents = try DeviceAggregateResponseParser.recentEvents(from: [
            "items": .array([
                .object([
                    "event_id": "evt-normal",
                    "path": "/DCIMA/REC00003.AVI",
                    "event_type": "normal",
                    "title": "Device Supplied Title"
                ]),
                .object([
                    "event_id": "evt-photo",
                    "path": "/DCIMA/SNAP0001.JPG",
                    "event_type": "photo",
                    "title_key": "event.photo",
                    "title": "Device Supplied Title"
                ])
            ])
        ])

        #expect(recentEvents.items.map(\.title) == ["Normal Recording", "Photo"])

        let mediaIndex = try DeviceAggregateResponseParser.mediaIndex(from: [
            "groups": .array([
                .object([
                    "items": .array([
                        .object([
                            "path": "/DCIMA/REC00005.AVI",
                            "event_type": "normal",
                            "title_key": "event.normal_recording",
                            "title": "Device Supplied Title"
                        ]),
                        .object([
                            "path": "/DCIMA/SNAP0001.JPG",
                            "event_type": "photo",
                            "title": "Device Supplied Title"
                        ])
                    ])
                ])
            ])
        ])

        #expect(mediaIndex.groups.first?.items.map(\.title) == ["Normal Recording", "Photo"])
    }

    @Test
    func stateSyncParserPreservesDocumentedSnapshotMetadata() throws {
        let snapshot = try DeviceAggregateResponseParser.stateSync(from: [
            "scope": "initial",
            "schema_version": "state_sync.v1",
            "generated_at": "2026-05-29T09:30:00Z",
            "cache_ttl_ms": 500,
            "truncated": 1,
            "omitted_sections": .array(["media_index", "recent_events"]),
            "sections": .object([
                "home": .object([:])
            ])
        ])

        #expect(snapshot.schemaVersion == "state_sync.v1")
        #expect(snapshot.generatedAt == "2026-05-29T09:30:00Z")
        #expect(snapshot.cacheTTLMilliseconds == 500)
        #expect(snapshot.truncated == true)
        #expect(snapshot.omittedSections == ["media_index", "recent_events"])
    }

    @Test
    func stateSyncParserRejectsInvalidDocumentedSnapshotMetadata() {
        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.cache_ttl_ms 无效")) {
            try DeviceAggregateResponseParser.stateSync(from: [
                "scope": "initial",
                "cache_ttl_ms": true,
                "sections": .object([:])
            ])
        }

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.cache_ttl_ms 无效")) {
            try DeviceAggregateResponseParser.stateSync(from: [
                "scope": "initial",
                "cache_ttl_ms": -1,
                "sections": .object([:])
            ])
        }

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.omitted_sections 无效")) {
            try DeviceAggregateResponseParser.stateSync(from: [
                "scope": "initial",
                "omitted_sections": .array(["home", 1]),
                "sections": .object([:])
            ])
        }

        #expect(throws: DeviceSessionReadOnlyError.invalidResponse("STATE_SYNC.truncated 无效")) {
            try DeviceAggregateResponseParser.stateSync(from: [
                "scope": "initial",
                "truncated": 2,
                "sections": .object([:])
            ])
        }
    }
}

private final class FakeDeviceProtocolTransport: DeviceProtocolTransport {
    var onReceiveData: ((Data) -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var responseProvider: ((DeviceProtocolMessage) -> DeviceProtocolMessage?)?
    private(set) var sentMessages: [DeviceProtocolMessage] = []
    private(set) var disconnectCount = 0

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
        disconnectCount += 1
        onDisconnect?(nil)
    }

    func push(_ message: DeviceProtocolMessage) {
        guard let data = try? codec.encode(message) else {
            return
        }

        onReceiveData?(data)
    }

    func pushRaw(_ data: Data) {
        onReceiveData?(data)
    }
}

private func makeHandshakeResponse(
    _ request: DeviceProtocolMessage,
    maxControlFrameBytes: Int
) -> DeviceProtocolMessage {
    makeHandshakeResponse(
        request,
        protocolCapabilityOverrides: [
            "max_control_frame_bytes": .int(maxControlFrameBytes)
        ]
    )
}

private func makeHandshakeResponse(
    _ request: DeviceProtocolMessage,
    protocolCapabilityOverrides: [String: DeviceProtocolValue]
) -> DeviceProtocolMessage {
    let parameters: [String: DeviceProtocolValue]
    if request.topic == "PROTOCOL_VERSION" {
        parameters = [
            "protocol_ver": "1.2",
            "min_supported_ver": "1.0"
        ]
    } else if request.topic == "CAMERA_CAPABILITY" {
        var protocolCapabilities: [String: DeviceProtocolValue] = [
            "inline_media_base64": true,
            "max_control_frame_bytes": .int(DeviceProtocolFrameBuffer.maxControlFrameBytes),
            "max_media_frame_bytes": .int(DeviceProtocolFrameBuffer.maxMediaFrameBytes),
            "state_sync_supported": true,
            "media_index_supported": true,
            "recent_events_supported": true,
            "aggregate_config_supported": true
        ]
        protocolCapabilityOverrides.forEach { key, value in
            protocolCapabilities[key] = value
        }
        parameters = [
            "capabilities": [
                "protocol": .object(protocolCapabilities)
            ]
        ]
    } else {
        parameters = [:]
    }

    return DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: 0,
        parameters: parameters
    )
}

private func oversizedResponseMessage(
    topic: String,
    replyTo: String,
    paddingLength: Int = 70_000
) -> DeviceProtocolMessage {
    DeviceProtocolMessage(
        topic: topic,
        operation: .notify,
        messageID: "dev-\(replyTo)",
        notifyType: .response,
        replyTo: replyTo,
        errno: 0,
        parameters: ["padding": .string(String(repeating: "x", count: paddingLength))]
    )
}

private func waitForResult<T>(
    timeout: TimeInterval = 3,
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
