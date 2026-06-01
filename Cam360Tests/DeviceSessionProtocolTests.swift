import Foundation
import Testing
@testable import Cam360

private let validTestThumbnailBase64 = "AQIDBA=="
private let alternateTestThumbnailBase64 = "BQYHCA=="
private let validTestSnapshotBase64 = "CQoLDA=="

@MainActor
@Suite(.serialized)
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
        #expect(session.deviceStatus.sdCardOnline == 1)
        #expect(session.deviceStatus.batteryLevel == 4)
        #expect(session.deviceStatus.storageCapacity == DeviceStorageCapacity(remainingMegabytes: 4_000, totalMegabytes: 22_222))
    }

    @Test
    func protocolHandshakeFailsWhenFirmwareVersionIsMissing() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "FW_VERSION" {
                return makeTopicResponse(request, parameters: [:])
            }
            return makeHandshakeResponse(request)
        }

        startHandshake(session)

        #expect(await waitForSessionState(timeout: 0.5) { failedError(from: session.state) != nil })
        #expect(failedError(from: session.state) == .handshakeFailed(reason: "FW_VERSION.ver 缺失"))
    }

    @Test
    func protocolHandshakeFailsWhenDeviceUUIDIsMissing() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "UUID" {
                return makeTopicResponse(request, parameters: [:])
            }
            return makeHandshakeResponse(request)
        }

        startHandshake(session)

        #expect(await waitForSessionState(timeout: 0.5) { failedError(from: session.state) != nil })
        #expect(failedError(from: session.state) == .handshakeFailed(reason: "UUID.uuid 缺失"))
    }

    @Test
    func protocolHandshakeStartsHeartbeatUsingAppAccessInterval() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "HEARTBEAT" {
                return makeHeartbeatResponse(request)
            }
            return makeHandshakeResponse(
                request,
                appAccessParameters: [
                    "heartbeat_interval": .double(0.05),
                    "heartbeat_timeout": .double(0.25)
                ]
            )
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        #expect(await waitForSessionState { transport.sentMessages.contains { $0.topic == "HEARTBEAT" } })
        let heartbeat = transport.sentMessages.first { $0.topic == "HEARTBEAT" }
        #expect(heartbeat?.operation == .post)
        #expect(heartbeat?.parameters["seq"]?.intValue == 1)
        #expect(heartbeat?.parameters["client_time"]?.stringValue?.count == 14)
        #expect(session.state.isConnected)
    }

    @Test
    func heartbeatDisconnectsAfterTwoMissingAcks() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "HEARTBEAT" {
                return nil
            }
            return makeHandshakeResponse(
                request,
                appAccessParameters: [
                    "heartbeat_interval": .double(0.02),
                    "heartbeat_timeout": .double(0.5)
                ]
            )
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        #expect(await waitForSessionState { failedError(from: session.state) == .connectionLost })
        #expect(transport.sentMessages.filter { $0.topic == "HEARTBEAT" }.count == 2)
        #expect(transport.disconnectCount == 1)
    }

    @Test
    func heartbeatDisconnectsAfterTwoMismatchedAckSequences() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "HEARTBEAT" {
                return DeviceProtocolMessage(
                    topic: "HEARTBEAT",
                    operation: .notify,
                    messageID: "dev-\(request.messageID)",
                    notifyType: .response,
                    replyTo: request.messageID,
                    errno: 0,
                    parameters: [
                        "ack": true,
                        "seq": .int((request.parameters["seq"]?.intValue ?? 0) + 100)
                    ]
                )
            }
            return makeHandshakeResponse(
                request,
                appAccessParameters: [
                    "heartbeat_interval": .double(0.02),
                    "heartbeat_timeout": .double(0.5)
                ]
            )
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        #expect(await waitForSessionState(timeout: 0.5) { failedError(from: session.state) == .connectionLost })
        #expect(transport.sentMessages.filter { $0.topic == "HEARTBEAT" }.count == 2)
        #expect(transport.disconnectCount == 1)
    }

    @Test
    func heartbeatRejectsBooleanAckSequence() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "HEARTBEAT" {
                return DeviceProtocolMessage(
                    topic: "HEARTBEAT",
                    operation: .notify,
                    messageID: "dev-\(request.messageID)",
                    notifyType: .response,
                    replyTo: request.messageID,
                    errno: 0,
                    parameters: [
                        "ack": true,
                        "seq": true
                    ]
                )
            }
            return makeHandshakeResponse(
                request,
                appAccessParameters: [
                    "heartbeat_interval": .double(0.02),
                    "heartbeat_timeout": .double(0.5)
                ]
            )
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        #expect(await waitForSessionState(timeout: 0.5) { failedError(from: session.state) == .connectionLost })
        #expect(transport.sentMessages.filter { $0.topic == "HEARTBEAT" }.count == 2)
        #expect(transport.disconnectCount == 1)
    }

    @Test
    func lowProtocolVersionDoesNotStartHeartbeatWithoutCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "HEARTBEAT" {
                return makeHeartbeatResponse(request)
            }
            return makeHandshakeResponse(
                request,
                appAccessParameters: ["heartbeat_interval": .double(0.05)],
                protocolVersion: "1.1"
            )
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })
        try? await Task.sleep(nanoseconds: 150_000_000)

        #expect(transport.sentMessages.contains { $0.topic == "HEARTBEAT" } == false)
        #expect(session.state.isConnected)
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
        #expect(failedError(from: session.state) == .handshakeFailed(reason: "设备忙: APP_ACCESS (errno -4)"))
    }

    @Test
    func protocolDeviceErrorReasonUsesDocumentedErrnoMapping() {
        #expect(
            DeviceSession.protocolFailureReason(
                for: .deviceError(errno: -5, topic: "VIDEO_CTRL", parameters: [:])
            ) == "不支持此功能: VIDEO_CTRL (errno -5)"
        )
        #expect(
            DeviceSession.protocolFailureReason(
                for: .deviceError(errno: -99, topic: "UNKNOWN", parameters: [:])
            ) == "设备错误 errno -99: UNKNOWN"
        )
    }

    @Test
    func protocolFailureReasonCoversAllErrorVariants() {
        #expect(
            DeviceSession.protocolFailureReason(for: .transportDisconnected) == "控制通道已断开"
        )
        #expect(
            DeviceSession.protocolFailureReason(for: .requestTimedOut(topic: "APP_ACCESS")) == "请求超时: APP_ACCESS"
        )
        #expect(
            DeviceSession.protocolFailureReason(for: .transportFailed("connection reset")) == "传输失败: connection reset"
        )
        #expect(
            DeviceSession.protocolFailureReason(for: .invalidFrame) == "协议帧无效"
        )
        #expect(
            DeviceSession.protocolFailureReason(for: .encodeFailed) == "协议编码失败"
        )
        #expect(
            DeviceSession.protocolFailureReason(for: .decodeFailed) == "协议解码失败"
        )
        #expect(
            DeviceSession.protocolFailureReason(for: .responseWithoutRequest(replyTo: "ios-orphan")) == "未匹配的设备响应: ios-orphan"
        )
        #expect(
            DeviceSession.protocolFailureReason(
                for: .unsupportedAppVersion(appVersion: "1.0", minSupportedVersion: "2.0")
            ) == "APP 版本 1.0 低于设备最低支持 2.0"
        )
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

    @Test
    func disconnectSendsExitAppBeforeClosingProtocolConnection() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.send(.disconnect)

        #expect(await waitForSessionState { transport.disconnectCount == 1 })
        #expect(session.state == .disconnected)
        #expect(transport.sentMessages.last?.topic == "CTP_CMD_EXITAPP")
        #expect(transport.sentMessages.last?.operation == .post)
    }

    @Test
    func resetSendsExitAppBeforeReturningReadySessionToIdle() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.send(.reset)

        #expect(await waitForSessionState { transport.disconnectCount == 1 })
        #expect(session.state == .idle)
        #expect(transport.sentMessages.last?.topic == "CTP_CMD_EXITAPP")
        #expect(transport.sentMessages.last?.operation == .post)
    }

    @Test
    func disconnectDuringHandshakeClosesProtocolWithoutExitApp() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport, handshakeCommandTimeout: 1)
        transport.responseProvider = { _ in nil }

        startHandshake(session)
        #expect(await waitForSessionState { transport.sentMessages.count == 1 })

        session.send(.disconnect)

        #expect(await waitForSessionState { transport.disconnectCount == 1 })
        #expect(session.state == .disconnected)
        #expect(transport.sentMessages.map(\.topic) == ["APP_ACCESS"])
    }

    @Test
    func fileListReadOnlyCommandRequiresReadySession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var result: Result<DeviceFileListPage, DeviceSessionReadOnlyError>?

        session.fetchFileList { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.sessionNotReady)? = result {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.isEmpty)
    }

    @Test
    func controlCommandRequiresReadySessionWhenSessionIsBusy() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }
        var result: Result<DeviceRecordingState, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })
        let sentCountBeforeBusyCommand = transport.sentMessages.count

        session.send(.startOperation(.livePreview))
        session.fetchRecordingState { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.sessionNotReady)? = result {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.count == sentCountBeforeBusyCommand)
    }

    @Test
    func fileListReadOnlyCommandSendsFileListThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeFileTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var page: DeviceFileListPage?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchFileList(
            query: DeviceFileListQuery(type: .video, page: 1, pageSize: 20)
        ) { result in
            if case .success(let filePage) = result {
                page = filePage
            }
        }

        #expect(await waitForSessionState { page != nil })
        #expect(transport.sentMessages.last?.topic == "FILE_LIST")
        #expect(transport.sentMessages.last?.parameters["type"]?.stringValue == "video")
        #expect(transport.sentMessages.last?.parameters["page"]?.intValue == 1)
        #expect(page?.total == 1)
        #expect(page?.files.first?.path == "/DCIMA/REC00001.AVI")
        #expect(page?.files.first?.hasThumbnail == true)
    }

    @Test
    func deviceInfoReadOnlyCommandSendsDeviceInfoThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeDeviceInfoTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var deviceInfo: DeviceBasicInfo?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchDeviceBasicInfo { result in
            if case .success(let info) = result {
                deviceInfo = info
            }
        }

        #expect(await waitForSessionState { deviceInfo != nil })
        #expect(transport.sentMessages.last?.topic == "DEVICE_INFO")
        #expect(transport.sentMessages.last?.operation == .get)
        #expect(deviceInfo?.deviceName == "Camera 360")
        #expect(deviceInfo?.model == "C360-X1")
        #expect(deviceInfo?.serialNumber == "C360X1202605140001")
        #expect(deviceInfo?.uuid == "112233445566778899")
        #expect(deviceInfo?.firmwareVersion == "v1.0.1")
        #expect(deviceInfo?.protocolVersion == "1.2")
    }

    @Test
    func realtimeGPSDataReadOnlyCommandSendsConfirmedTopicThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeRealtimeGPSDataTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var gpsData: DeviceRealtimeGPSData?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchRealtimeGPSData { result in
            if case .success(let data) = result {
                gpsData = data
            }
        }

        #expect(await waitForSessionState { gpsData != nil })
        #expect(transport.sentMessages.last?.topic == "VI_GPS_RTDATA")
        #expect(transport.sentMessages.last?.operation == .get)
        #expect(gpsData?.info == "2022/05/27 21:20:29 N:22.525370 E:114.429984 0.00 km/h 0.00 25.70 8")
    }

    @Test
    func fileReadOnlyCommandsSendExpectedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeFileTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var completedTopics: [String] = []

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchFileInfo(path: "/DCIMA/REC00001.AVI") { result in
            if case .success(let info) = result, info.path == "/DCIMA/REC00001.AVI" {
                completedTopics.append("FILE_INFO")
            }
        }
        session.fetchPlaybackResource(path: "/DCIMA/REC00001.AVI") { result in
            if case .success(let resource) = result, resource.rtspURL == "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI" {
                completedTopics.append("FILE_DOWNLOAD_URL")
            }
        }
        session.fetchThumbnails(paths: ["/DCIMA/REC00001.AVI"]) { result in
            if case .success(let thumbnails) = result, thumbnails.first?.path == "/DCIMA/REC00001.AVI" {
                completedTopics.append("THUMB_LIST")
            }
        }
        session.fetchThumbnail(path: "/DCIMA/REC00001.AVI") { result in
            if case .success(let thumbnail) = result, thumbnail.imageBase64 == validTestThumbnailBase64 {
                completedTopics.append("THUMB_GET")
            }
        }

        #expect(await waitForSessionState { completedTopics.count == 4 })
        #expect(Array(transport.sentMessages.map(\.topic).suffix(4)) == [
            "FILE_INFO",
            "FILE_DOWNLOAD_URL",
            "THUMB_LIST",
            "THUMB_GET"
        ])
    }

    @Test
    func fileReadOnlyCommandsRejectBlankProtocolPathsBeforeSending() async {
        await expectReadOnlyCommandRejectedForInvalidParameters(topic: "FILE_INFO") { session, completion in
            session.fetchFileInfo(path: " ", completion: completion)
        }
        await expectReadOnlyCommandRejectedForInvalidParameters(topic: "FILE_DOWNLOAD_URL") { session, completion in
            session.fetchPlaybackResource(path: " ", completion: completion)
        }
        await expectReadOnlyCommandRejectedForInvalidParameters(topic: "THUMB_GET") { session, completion in
            session.fetchThumbnail(path: " ", completion: completion)
        }
        await expectReadOnlyCommandRejectedForInvalidParameters(topic: "THUMB_LIST") { session, completion in
            session.fetchThumbnails(paths: [], completion: completion)
        }
        await expectReadOnlyCommandRejectedForInvalidParameters(topic: "THUMB_LIST") { session, completion in
            session.fetchThumbnails(paths: ["/DCIMA/REC00001.AVI", " "], completion: completion)
        }
    }

    @Test
    func thumbnailCommandsRequireDeclaredBase64TransportCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeFileTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: legacyCameraCapabilities()
            )
        }
        var result: Result<[DeviceFileThumbnail], DeviceSessionReadOnlyError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchThumbnails(paths: ["/DCIMA/REC00001.AVI"]) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "THUMB_LIST")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "THUMB_LIST" } == false)
    }

    @Test
    func thumbnailCommandsRequireDeclaredFileThumbnailCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["file"] = .object([
            "lock": true,
            "unlock": false,
            "delete_locked": false,
            "thumbnail": false,
            "download": true,
            "thumbnail_transport": ["base64"]
        ])

        await expectReadOnlyCommandBlocked(topic: "THUMB_GET", cameraCapabilities: capabilities) { session, completion in
            session.fetchThumbnail(path: "/DCIMA/REC00001.AVI", completion: completion)
        }
    }

    @Test
    func recordingCommandsSendVideoCtrlThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var states: [DeviceRecordingState] = []

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchRecordingState { result in
            if case .success(let state) = result {
                states.append(state)
            }
        }
        session.setRecording(enabled: true) { result in
            if case .success(let state) = result {
                states.append(state)
            }
        }

        #expect(await waitForSessionState { states.count == 2 })
        #expect(states[0] == DeviceRecordingState(isRecording: false, path: nil))
        #expect(states[1] == DeviceRecordingState(isRecording: true, path: "/DCIMA/REC99999.AVI"))
        #expect(Array(transport.sentMessages.map(\.topic).suffix(2)) == [
            "VIDEO_CTRL",
            "VIDEO_CTRL"
        ])
        #expect(transport.sentMessages.suffix(2).first?.operation == .get)
        #expect(transport.sentMessages.last?.operation == .post)
        #expect(transport.sentMessages.last?.parameters["status"]?.intValue == 1)
    }

    @Test
    func recordingCommandResponsesUpdateSessionDeviceStatus() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var states: [DeviceRecordingState] = []

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchRecordingState { result in
            if case .success(let state) = result {
                states.append(state)
            }
        }

        #expect(await waitForSessionState { states.count == 1 })
        #expect(session.deviceStatus.recordingState == DeviceRecordingState(isRecording: false, path: nil))

        session.setRecording(enabled: true) { result in
            if case .success(let state) = result {
                states.append(state)
            }
        }

        #expect(await waitForSessionState { states.count == 2 })
        #expect(session.deviceStatus.recordingState == DeviceRecordingState(
            isRecording: true,
            path: "/DCIMA/REC99999.AVI"
        ))
    }

    @Test
    func deviceStatusReadCommandsUpdateSessionDeviceStatus() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeStatusTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var sdCardOnline: Int?
        var batteryLevel: Int?
        var storageCapacity: DeviceStorageCapacity?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchSDCardStatus { result in
            if case .success(let online) = result {
                sdCardOnline = online
            }
        }
        session.fetchBatteryStatus { result in
            if case .success(let level) = result {
                batteryLevel = level
            }
        }
        session.fetchStorageCapacity { result in
            if case .success(let capacity) = result {
                storageCapacity = capacity
            }
        }

        #expect(await waitForSessionState {
            sdCardOnline != nil && batteryLevel != nil && storageCapacity != nil
        })
        #expect(sdCardOnline == 1)
        #expect(batteryLevel == 4)
        #expect(storageCapacity == DeviceStorageCapacity(remainingMegabytes: 4_000, totalMegabytes: 22_222))
        #expect(session.deviceStatus.sdCardOnline == 1)
        #expect(session.deviceStatus.batteryLevel == 4)
        #expect(session.deviceStatus.storageCapacity == storageCapacity)
        #expect(Array(transport.sentMessages.map(\.topic).suffix(3)) == [
            "SD_STATUS",
            "BAT_STATUS",
            "TF_CAP"
        ])
    }

    @Test
    func controlCommandDeviceErrorReturnsMappedFailureAndKeepsSessionReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "VIDEO_CTRL" {
                return makeControlTopicResponse(request, errno: -4)
            }
            return makeHandshakeResponse(request)
        }
        var result: Result<DeviceRecordingState, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchRecordingState { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -4)
            #expect(topic == "VIDEO_CTRL")
        } else {
            #expect(Bool(false))
        }
        #expect(result?.failureMessage == "设备忙: VIDEO_CTRL (errno -4)")
        #expect(session.state.isConnected)
    }

    @Test
    func deleteLockedFileReturnsLockedFileMessageAndKeepsSessionReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "FILE_DELETE" {
                return makeControlTopicResponse(request, errno: -6)
            }
            return makeHandshakeResponse(request)
        }
        var result: Result<DeviceFileDeletionResult, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.deleteFile(path: "/DCIMA/LOCKED0001.AVI") { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -6)
            #expect(topic == "FILE_DELETE")
        } else {
            #expect(Bool(false))
        }
        #expect(result?.failureMessage == "文件已加锁，无法删除: FILE_DELETE (errno -6)")
        #expect(session.state.isConnected)
    }

    @Test
    func pendingControlCommandAfterResetCompletesAsStaleSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            request.topic == "VIDEO_CTRL" ? nil : makeHandshakeResponse(request)
        }
        var result: Result<DeviceRecordingState, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.setRecording(enabled: true) { commandResult in
            result = commandResult
        }
        #expect(await waitForSessionState { transport.sentMessages.last?.topic == "VIDEO_CTRL" })

        session.send(.reset)

        #expect(await waitForSessionState { result != nil })
        if case .failure(.staleSession)? = result {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func captureSnapshotSendsSnapshotControlThenSnapshotDataThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var snapshot: DeviceSnapshotResource?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.captureSnapshot { result in
            if case .success(let resource) = result {
                snapshot = resource
            }
        }

        #expect(await waitForSessionState { snapshot != nil })
        #expect(snapshot?.snapshotID == "snap-1")
        #expect(snapshot?.imageBase64 == validTestSnapshotBase64)
        #expect(snapshot?.width == 1280)
        #expect(snapshot?.height == 720)
        #expect(Array(transport.sentMessages.map(\.topic).suffix(2)) == [
            "SNAPSHOT_CTRL",
            "SNAPSHOT_DATA"
        ])
        #expect(transport.sentMessages.suffix(2).first?.parameters["mode"]?.stringValue == "preview")
        #expect(transport.sentMessages.last?.parameters["snapshot_id"]?.stringValue == "snap-1")
    }

    @Test
    func snapshotCommandsRequireDeclaredBase64TransportCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: legacyCameraCapabilities()
            )
        }
        var result: Result<DeviceSnapshotResource, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.captureSnapshot { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "SNAPSHOT_CTRL")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "SNAPSHOT_CTRL" } == false)
    }

    @Test
    func dateTimeSyncSendsConfirmedTopicThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var syncedDateTime: DeviceDateTimeSyncResult?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.syncDateTime(date: "20230607103056", timeZoneOffsetMinutes: 480) { result in
            if case .success(let dateTime) = result {
                syncedDateTime = dateTime
            }
        }

        #expect(await waitForSessionState { syncedDateTime != nil })
        #expect(syncedDateTime?.date == "20230607103056")
        #expect(syncedDateTime?.timeZoneOffsetMinutes == 480)
        #expect(transport.sentMessages.last?.topic == "DATE_TIME")
        #expect(transport.sentMessages.last?.operation == .post)
        #expect(transport.sentMessages.last?.parameters["date"]?.stringValue == "20230607103056")
        #expect(transport.sentMessages.last?.parameters["tz_offset_min"]?.intValue == 480)
    }

    @Test
    func dateTimeSyncRejectsInvalidDocumentedDateBeforeSending() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        let invalidDates = [
            "",
            "2023060710305",
            "20230230103056"
        ]

        for date in invalidDates {
            var result: Result<DeviceDateTimeSyncResult, DeviceSessionCommandError>?
            session.syncDateTime(date: date, timeZoneOffsetMinutes: 480) { commandResult in
                result = commandResult
            }

            #expect(await waitForSessionState { result != nil })
            if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
                #expect(errno == -2)
                #expect(topic == "DATE_TIME")
            } else {
                #expect(Bool(false))
            }
        }
        #expect(transport.sentMessages.contains { $0.topic == "DATE_TIME" } == false)
    }

    @Test
    func hourTypeCommandsSendConfirmedTopicThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedHourType: DeviceHourTypeSetting?
        var updatedHourType: DeviceHourTypeSetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchHourType { result in
            if case .success(let setting) = result {
                fetchedHourType = setting
            }
        }
        session.updateHourType(.twentyFourHour) { result in
            if case .success(let setting) = result {
                updatedHourType = setting
            }
        }

        #expect(await waitForSessionState { fetchedHourType != nil && updatedHourType != nil })
        let commandMessages = Array(transport.sentMessages.suffix(2))
        #expect(commandMessages.map(\.topic) == ["HOUR_TYPE", "HOUR_TYPE"])
        #expect(commandMessages.map(\.operation) == [.get, .post])
        #expect(commandMessages.last?.parameters["type"]?.intValue == 24)
        #expect(fetchedHourType?.type == .twentyFourHour)
        #expect(updatedHourType?.type == .twentyFourHour)
    }

    @Test
    func legacyRecordingSettingCommandsSendConfirmedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedVideoSize: DeviceVideoSizeSetting?
        var updatedVideoSize: DeviceVideoSizeSetting?
        var fetchedLoop: DeviceVideoLoopSetting?
        var updatedLoop: DeviceVideoLoopSetting?
        var fetchedMicrophone: DeviceVideoMicrophoneSetting?
        var updatedMicrophone: DeviceVideoMicrophoneSetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchVideoSize { result in
            if case .success(let setting) = result {
                fetchedVideoSize = setting
            }
        }
        session.updateVideoSize(
            supportedResolutions: ["4K", "2K", "1080P"],
            selectedIndex: 2
        ) { result in
            if case .success(let setting) = result {
                updatedVideoSize = setting
            }
        }
        session.fetchVideoLoop { result in
            if case .success(let setting) = result {
                fetchedLoop = setting
            }
        }
        session.updateVideoLoop(.threeMinutes) { result in
            if case .success(let setting) = result {
                updatedLoop = setting
            }
        }
        session.fetchVideoMicrophone { result in
            if case .success(let setting) = result {
                fetchedMicrophone = setting
            }
        }
        session.updateVideoMicrophone(isEnabled: false) { result in
            if case .success(let setting) = result {
                updatedMicrophone = setting
            }
        }

        #expect(await waitForSessionState {
            fetchedVideoSize != nil &&
                updatedVideoSize != nil &&
                fetchedLoop != nil &&
                updatedLoop != nil &&
                fetchedMicrophone != nil &&
                updatedMicrophone != nil
        })
        let commandMessages = Array(transport.sentMessages.suffix(6))
        #expect(commandMessages.map(\.topic) == [
            "VIDEO_SIZE",
            "VIDEO_SIZE",
            "VIDEO_LOOP",
            "VIDEO_LOOP",
            "VIDEO_MIC",
            "VIDEO_MIC"
        ])
        #expect(commandMessages.map(\.operation) == [.get, .post, .get, .post, .get, .post])
        #expect(commandMessages[1].parameters["str"]?.stringValue == "4K;2K;1080P")
        #expect(commandMessages[1].parameters["val"]?.intValue == 2)
        #expect(commandMessages[3].parameters["cyc"]?.intValue == 2)
        #expect(commandMessages[5].parameters["mic"]?.intValue == 0)
        #expect(fetchedVideoSize?.supportedResolutions == ["4K", "2K", "1080P"])
        #expect(updatedVideoSize?.selectedIndex == 2)
        #expect(fetchedLoop?.cycle == .oneMinute)
        #expect(updatedLoop?.cycle == .threeMinutes)
        #expect(fetchedMicrophone?.isEnabled == true)
        #expect(updatedMicrophone?.isEnabled == false)
    }

    @Test
    func legacySafetySettingCommandsSendConfirmedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedWideDynamicRange: DeviceVideoWideDynamicRangeSetting?
        var updatedWideDynamicRange: DeviceVideoWideDynamicRangeSetting?
        var fetchedExposure: DeviceVideoExposureSetting?
        var updatedExposure: DeviceVideoExposureSetting?
        var fetchedCollisionSensitivity: DeviceCollisionSensitivitySetting?
        var updatedCollisionSensitivity: DeviceCollisionSensitivitySetting?
        var fetchedMotionDetection: DeviceMotionDetectionSetting?
        var updatedMotionDetection: DeviceMotionDetectionSetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchVideoWideDynamicRange { result in
            if case .success(let setting) = result {
                fetchedWideDynamicRange = setting
            }
        }
        session.updateVideoWideDynamicRange(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedWideDynamicRange = setting
            }
        }
        session.fetchVideoExposure { result in
            if case .success(let setting) = result {
                fetchedExposure = setting
            }
        }
        session.updateVideoExposure(.zero) { result in
            if case .success(let setting) = result {
                updatedExposure = setting
            }
        }
        session.fetchCollisionSensitivity { result in
            if case .success(let setting) = result {
                fetchedCollisionSensitivity = setting
            }
        }
        session.updateCollisionSensitivity(.medium) { result in
            if case .success(let setting) = result {
                updatedCollisionSensitivity = setting
            }
        }
        session.fetchMotionDetection { result in
            if case .success(let setting) = result {
                fetchedMotionDetection = setting
            }
        }
        session.updateMotionDetection(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedMotionDetection = setting
            }
        }

        #expect(await waitForSessionState {
            fetchedWideDynamicRange != nil &&
                updatedWideDynamicRange != nil &&
                fetchedExposure != nil &&
                updatedExposure != nil &&
                fetchedCollisionSensitivity != nil &&
                updatedCollisionSensitivity != nil &&
                fetchedMotionDetection != nil &&
                updatedMotionDetection != nil
        })
        let commandMessages = Array(transport.sentMessages.suffix(8))
        #expect(commandMessages.map(\.topic) == [
            "VIDEO_WDR",
            "VIDEO_WDR",
            "VIDEO_EXP",
            "VIDEO_EXP",
            "GRA_SEN",
            "GRA_SEN",
            "MOVE_CHECK",
            "MOVE_CHECK"
        ])
        #expect(commandMessages.map(\.operation) == [.get, .post, .get, .post, .get, .post, .get, .post])
        #expect(commandMessages[1].parameters["wdr"]?.intValue == 1)
        #expect(commandMessages[3].parameters["exp"]?.intValue == 6)
        #expect(commandMessages[5].parameters["gra"]?.intValue == 2)
        #expect(commandMessages[7].parameters["mot"]?.intValue == 1)
        #expect(fetchedWideDynamicRange?.isEnabled == true)
        #expect(updatedWideDynamicRange?.isEnabled == true)
        #expect(fetchedExposure?.level == .zero)
        #expect(updatedExposure?.level == .zero)
        #expect(fetchedCollisionSensitivity?.sensitivity == .medium)
        #expect(updatedCollisionSensitivity?.sensitivity == .medium)
        #expect(fetchedMotionDetection?.isEnabled == true)
        #expect(updatedMotionDetection?.isEnabled == true)
    }

    @Test
    func legacyParkingPowerSettingCommandsSendConfirmedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedMonitorMode: DeviceParkingMonitorModeSetting?
        var updatedMonitorMode: DeviceParkingMonitorModeSetting?
        var fetchedMonitorDuration: DeviceParkingMonitorDurationSetting?
        var updatedMonitorDuration: DeviceParkingMonitorDurationSetting?
        var fetchedVoltageProtection: DeviceVoltageProtectionSetting?
        var updatedVoltageProtection: DeviceVoltageProtectionSetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchParkingMonitorMode { result in
            if case .success(let setting) = result {
                fetchedMonitorMode = setting
            }
        }
        session.updateParkingMonitorMode(.timeLapse) { result in
            if case .success(let setting) = result {
                updatedMonitorMode = setting
            }
        }
        session.fetchParkingMonitorDuration { result in
            if case .success(let setting) = result {
                fetchedMonitorDuration = setting
            }
        }
        session.updateParkingMonitorDuration(.twelveHours) { result in
            if case .success(let setting) = result {
                updatedMonitorDuration = setting
            }
        }
        session.fetchVoltageProtection { result in
            if case .success(let setting) = result {
                fetchedVoltageProtection = setting
            }
        }
        session.updateVoltageProtection(.twelveVolts) { result in
            if case .success(let setting) = result {
                updatedVoltageProtection = setting
            }
        }

        #expect(await waitForSessionState {
            fetchedMonitorMode != nil &&
                updatedMonitorMode != nil &&
                fetchedMonitorDuration != nil &&
                updatedMonitorDuration != nil &&
                fetchedVoltageProtection != nil &&
                updatedVoltageProtection != nil
        })
        let commandMessages = Array(transport.sentMessages.suffix(6))
        #expect(commandMessages.map(\.topic) == [
            "MONITOR_MODE",
            "MONITOR_MODE",
            "MONITOR_TIME",
            "MONITOR_TIME",
            "VOLTAGE_PRO",
            "VOLTAGE_PRO"
        ])
        #expect(commandMessages.map(\.operation) == [.get, .post, .get, .post, .get, .post])
        #expect(commandMessages[1].parameters["mode"]?.intValue == 1)
        #expect(commandMessages[3].parameters["gaplen"]?.intValue == 12)
        #expect(commandMessages[5].parameters["vpr"]?.intValue == 1)
        #expect(fetchedMonitorMode?.mode == .timeLapse)
        #expect(updatedMonitorMode?.mode == .timeLapse)
        #expect(fetchedMonitorDuration?.duration == .twelveHours)
        #expect(updatedMonitorDuration?.duration == .twelveHours)
        #expect(fetchedVoltageProtection?.threshold == .twelveVolts)
        #expect(updatedVoltageProtection?.threshold == .twelveVolts)
    }

    @Test
    func legacyDisplayPowerSettingCommandsSendConfirmedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedDateWatermark: DeviceVideoDateWatermarkSetting?
        var updatedDateWatermark: DeviceVideoDateWatermarkSetting?
        var fetchedHorizontalMirror: DeviceHorizontalMirrorSetting?
        var updatedHorizontalMirror: DeviceHorizontalMirrorSetting?
        var fetchedVerticalFlip: DeviceVerticalFlipSetting?
        var updatedVerticalFlip: DeviceVerticalFlipSetting?
        var fetchedAutoShutdown: DeviceAutoShutdownSetting?
        var updatedAutoShutdown: DeviceAutoShutdownSetting?
        var fetchedScreenProtection: DeviceScreenProtectionSetting?
        var updatedScreenProtection: DeviceScreenProtectionSetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchVideoDateWatermark { result in
            if case .success(let setting) = result {
                fetchedDateWatermark = setting
            }
        }
        session.updateVideoDateWatermark(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedDateWatermark = setting
            }
        }
        session.fetchHorizontalMirror { result in
            if case .success(let setting) = result {
                fetchedHorizontalMirror = setting
            }
        }
        session.updateHorizontalMirror(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedHorizontalMirror = setting
            }
        }
        session.fetchVerticalFlip { result in
            if case .success(let setting) = result {
                fetchedVerticalFlip = setting
            }
        }
        session.updateVerticalFlip(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedVerticalFlip = setting
            }
        }
        session.fetchAutoShutdown { result in
            if case .success(let setting) = result {
                fetchedAutoShutdown = setting
            }
        }
        session.updateAutoShutdown(.threeMinutes) { result in
            if case .success(let setting) = result {
                updatedAutoShutdown = setting
            }
        }
        session.fetchScreenProtection { result in
            if case .success(let setting) = result {
                fetchedScreenProtection = setting
            }
        }
        session.updateScreenProtection(.oneMinute) { result in
            if case .success(let setting) = result {
                updatedScreenProtection = setting
            }
        }

        #expect(await waitForSessionState {
            fetchedDateWatermark != nil &&
                updatedDateWatermark != nil &&
                fetchedHorizontalMirror != nil &&
                updatedHorizontalMirror != nil &&
                fetchedVerticalFlip != nil &&
                updatedVerticalFlip != nil &&
                fetchedAutoShutdown != nil &&
                updatedAutoShutdown != nil &&
                fetchedScreenProtection != nil &&
                updatedScreenProtection != nil
        })
        let commandMessages = Array(transport.sentMessages.suffix(10))
        #expect(commandMessages.map(\.topic) == [
            "VIDEO_DATE",
            "VIDEO_DATE",
            "MIRROR_HOR",
            "MIRROR_HOR",
            "FLIP_VER",
            "FLIP_VER",
            "AUTO_SHUTDOWN",
            "AUTO_SHUTDOWN",
            "SCREEN_PRO",
            "SCREEN_PRO"
        ])
        #expect(commandMessages.map(\.operation) == [.get, .post, .get, .post, .get, .post, .get, .post, .get, .post])
        #expect(commandMessages[1].parameters["dat"]?.intValue == 1)
        #expect(commandMessages[3].parameters["status"]?.intValue == 1)
        #expect(commandMessages[5].parameters["status"]?.intValue == 1)
        #expect(commandMessages[7].parameters["aff"]?.intValue == 1)
        #expect(commandMessages[9].parameters["pro"]?.intValue == 2)
        #expect(fetchedDateWatermark?.isEnabled == true)
        #expect(updatedDateWatermark?.isEnabled == true)
        #expect(fetchedHorizontalMirror?.isEnabled == true)
        #expect(updatedHorizontalMirror?.isEnabled == true)
        #expect(fetchedVerticalFlip?.isEnabled == true)
        #expect(updatedVerticalFlip?.isEnabled == true)
        #expect(fetchedAutoShutdown?.delay == .threeMinutes)
        #expect(updatedAutoShutdown?.delay == .threeMinutes)
        #expect(fetchedScreenProtection?.delay == .oneMinute)
        #expect(updatedScreenProtection?.delay == .oneMinute)
    }

    @Test
    func legacyVideoPhotoDisplayParkingSettingCommandsSendConfirmedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedVideoParameter: DeviceVideoParameterSetting?
        var updatedVideoParameter: DeviceVideoParameterSetting?
        var fetchedPhotoResolution: DevicePhotoResolutionSetting?
        var updatedPhotoResolution: DevicePhotoResolutionSetting?
        var fetchedPhotoQuality: DevicePhotoQualitySetting?
        var updatedPhotoQuality: DevicePhotoQualitySetting?
        var fetchedPhotoDateWatermark: DevicePhotoDateWatermarkSetting?
        var updatedPhotoDateWatermark: DevicePhotoDateWatermarkSetting?
        var fetchedTVMode: DeviceTVModeSetting?
        var updatedTVMode: DeviceTVModeSetting?
        var fetchedParkingGuard: DeviceParkingGuardSetting?
        var updatedParkingGuard: DeviceParkingGuardSetting?
        var fetchedParkingCollisionSensitivity: DeviceParkingCollisionSensitivitySetting?
        var updatedParkingCollisionSensitivity: DeviceParkingCollisionSensitivitySetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchVideoParameter { result in
            if case .success(let setting) = result {
                fetchedVideoParameter = setting
            }
        }
        session.updateVideoParameter(width: 1280, height: 720, encodingFormat: .h264) { result in
            if case .success(let setting) = result {
                updatedVideoParameter = setting
            }
        }
        session.fetchPhotoResolution { result in
            if case .success(let setting) = result {
                fetchedPhotoResolution = setting
            }
        }
        session.updatePhotoResolution("12M") { result in
            if case .success(let setting) = result {
                updatedPhotoResolution = setting
            }
        }
        session.fetchPhotoQuality { result in
            if case .success(let setting) = result {
                fetchedPhotoQuality = setting
            }
        }
        session.updatePhotoQuality(.high) { result in
            if case .success(let setting) = result {
                updatedPhotoQuality = setting
            }
        }
        session.fetchPhotoDateWatermark { result in
            if case .success(let setting) = result {
                fetchedPhotoDateWatermark = setting
            }
        }
        session.updatePhotoDateWatermark(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedPhotoDateWatermark = setting
            }
        }
        session.fetchTVMode { result in
            if case .success(let setting) = result {
                fetchedTVMode = setting
            }
        }
        session.updateTVMode(.pal) { result in
            if case .success(let setting) = result {
                updatedTVMode = setting
            }
        }
        session.fetchParkingGuard { result in
            if case .success(let setting) = result {
                fetchedParkingGuard = setting
            }
        }
        session.updateParkingGuard(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedParkingGuard = setting
            }
        }
        session.fetchParkingCollisionSensitivity { result in
            if case .success(let setting) = result {
                fetchedParkingCollisionSensitivity = setting
            }
        }
        session.updateParkingCollisionSensitivity(.high) { result in
            if case .success(let setting) = result {
                updatedParkingCollisionSensitivity = setting
            }
        }

        #expect(await waitForSessionState {
            fetchedVideoParameter != nil &&
                updatedVideoParameter != nil &&
                fetchedPhotoResolution != nil &&
                updatedPhotoResolution != nil &&
                fetchedPhotoQuality != nil &&
                updatedPhotoQuality != nil &&
                fetchedPhotoDateWatermark != nil &&
                updatedPhotoDateWatermark != nil &&
                fetchedTVMode != nil &&
                updatedTVMode != nil &&
                fetchedParkingGuard != nil &&
                updatedParkingGuard != nil &&
                fetchedParkingCollisionSensitivity != nil &&
                updatedParkingCollisionSensitivity != nil
        })
        let commandMessages = Array(transport.sentMessages.suffix(14))
        #expect(commandMessages.map(\.topic) == [
            "VIDEO_PARAM",
            "VIDEO_PARAM",
            "PHOTO_RESO",
            "PHOTO_RESO",
            "PHOTO_QUALITY",
            "PHOTO_QUALITY",
            "PHOTO_DATE",
            "PHOTO_DATE",
            "TV_MODE",
            "TV_MODE",
            "VIDEO_PAR_CAR",
            "VIDEO_PAR_CAR",
            "VIDEO_PAR_VSIX",
            "VIDEO_PAR_VSIX"
        ])
        #expect(commandMessages.map(\.operation) == [
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post
        ])
        #expect(commandMessages[1].parameters["w"]?.intValue == 1280)
        #expect(commandMessages[1].parameters["h"]?.intValue == 720)
        #expect(commandMessages[1].parameters["format"]?.intValue == 1)
        #expect(commandMessages[3].parameters["reso"]?.stringValue == "12M")
        #expect(commandMessages[5].parameters["quality"]?.stringValue == "high")
        #expect(commandMessages[7].parameters["date"]?.intValue == 1)
        #expect(commandMessages[9].parameters["mode"]?.stringValue == "PAL")
        #expect(commandMessages[11].parameters["status"]?.intValue == 1)
        #expect(commandMessages[13].parameters["level"]?.intValue == 2)
        #expect(fetchedVideoParameter?.encodingFormat == .h264)
        #expect(updatedVideoParameter?.encodingFormat == .h264)
        #expect(fetchedPhotoResolution?.resolution == "12M")
        #expect(updatedPhotoResolution?.resolution == "12M")
        #expect(fetchedPhotoQuality?.quality == .high)
        #expect(updatedPhotoQuality?.quality == .high)
        #expect(fetchedPhotoDateWatermark?.isEnabled == true)
        #expect(updatedPhotoDateWatermark?.isEnabled == true)
        #expect(fetchedTVMode?.mode == .pal)
        #expect(updatedTVMode?.mode == .pal)
        #expect(fetchedParkingGuard?.isEnabled == true)
        #expect(updatedParkingGuard?.isEnabled == true)
        #expect(fetchedParkingCollisionSensitivity?.sensitivity == .high)
        #expect(updatedParkingCollisionSensitivity?.sensitivity == .high)
    }

    @Test
    func legacyAuxiliarySettingCommandsSendConfirmedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var fetchedIntervalRecording: DeviceIntervalRecordingSetting?
        var updatedIntervalRecording: DeviceIntervalRecordingSetting?
        var fetchedGPSTimeSync: DeviceGPSTimeSyncSetting?
        var updatedGPSTimeSync: DeviceGPSTimeSyncSetting?
        var fetchedDrivingRestReminder: DeviceDrivingRestReminderSetting?
        var updatedDrivingRestReminder: DeviceDrivingRestReminderSetting?
        var fetchedLightFrequency: DeviceLightFrequencySetting?
        var updatedLightFrequency: DeviceLightFrequencySetting?
        var fetchedSpeakerVolume: DeviceSpeakerVolumeSetting?
        var updatedSpeakerVolume: DeviceSpeakerVolumeSetting?
        var fetchedSpeech: DeviceSpeechSetting?
        var updatedSpeech: DeviceSpeechSetting?
        var fetchedKeyVoice: DeviceKeyVoiceSetting?
        var updatedKeyVoice: DeviceKeyVoiceSetting?
        var fetchedAntiTremor: DeviceAntiTremorSetting?
        var updatedAntiTremor: DeviceAntiTremorSetting?
        var fetchedElectronicDogVoice: DeviceElectronicDogVoiceSetting?
        var updatedElectronicDogVoice: DeviceElectronicDogVoiceSetting?
        var fetchedInfraredLight: DeviceInfraredLightSetting?
        var updatedInfraredLight: DeviceInfraredLightSetting?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchIntervalRecording { result in
            if case .success(let setting) = result {
                fetchedIntervalRecording = setting
            }
        }
        session.updateIntervalRecording(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedIntervalRecording = setting
            }
        }
        session.fetchGPSTimeSync { result in
            if case .success(let setting) = result {
                fetchedGPSTimeSync = setting
            }
        }
        session.updateGPSTimeSync(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedGPSTimeSync = setting
            }
        }
        session.fetchDrivingRestReminder { result in
            if case .success(let setting) = result {
                fetchedDrivingRestReminder = setting
            }
        }
        session.updateDrivingRestReminder(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedDrivingRestReminder = setting
            }
        }
        session.fetchLightFrequency { result in
            if case .success(let setting) = result {
                fetchedLightFrequency = setting
            }
        }
        session.updateLightFrequency(.hz50) { result in
            if case .success(let setting) = result {
                updatedLightFrequency = setting
            }
        }
        session.fetchSpeakerVolume { result in
            if case .success(let setting) = result {
                fetchedSpeakerVolume = setting
            }
        }
        session.updateSpeakerVolume(5) { result in
            if case .success(let setting) = result {
                updatedSpeakerVolume = setting
            }
        }
        session.fetchSpeech { result in
            if case .success(let setting) = result {
                fetchedSpeech = setting
            }
        }
        session.updateSpeech(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedSpeech = setting
            }
        }
        session.fetchKeyVoice { result in
            if case .success(let setting) = result {
                fetchedKeyVoice = setting
            }
        }
        session.updateKeyVoice(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedKeyVoice = setting
            }
        }
        session.fetchAntiTremor { result in
            if case .success(let setting) = result {
                fetchedAntiTremor = setting
            }
        }
        session.updateAntiTremor(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedAntiTremor = setting
            }
        }
        session.fetchElectronicDogVoice { result in
            if case .success(let setting) = result {
                fetchedElectronicDogVoice = setting
            }
        }
        session.updateElectronicDogVoice(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedElectronicDogVoice = setting
            }
        }
        session.fetchInfraredLight { result in
            if case .success(let setting) = result {
                fetchedInfraredLight = setting
            }
        }
        session.updateInfraredLight(isEnabled: true) { result in
            if case .success(let setting) = result {
                updatedInfraredLight = setting
            }
        }

        #expect(await waitForSessionState {
            fetchedIntervalRecording != nil &&
                updatedIntervalRecording != nil &&
                fetchedGPSTimeSync != nil &&
                updatedGPSTimeSync != nil &&
                fetchedDrivingRestReminder != nil &&
                updatedDrivingRestReminder != nil &&
                fetchedLightFrequency != nil &&
                updatedLightFrequency != nil &&
                fetchedSpeakerVolume != nil &&
                updatedSpeakerVolume != nil &&
                fetchedSpeech != nil &&
                updatedSpeech != nil &&
                fetchedKeyVoice != nil &&
                updatedKeyVoice != nil &&
                fetchedAntiTremor != nil &&
                updatedAntiTremor != nil &&
                fetchedElectronicDogVoice != nil &&
                updatedElectronicDogVoice != nil &&
                fetchedInfraredLight != nil &&
                updatedInfraredLight != nil
        })
        let commandMessages = Array(transport.sentMessages.suffix(20))
        #expect(commandMessages.map(\.topic) == [
            "VIDEO_INV",
            "VIDEO_INV",
            "VIDEO_SYNC",
            "VIDEO_SYNC",
            "VIDEO_RDER",
            "VIDEO_RDER",
            "LIGHT_FRE",
            "LIGHT_FRE",
            "SPEAKER_VOLUME",
            "SPEAKER_VOLUME",
            "SPEECH",
            "SPEECH",
            "KEY_VOICE",
            "KEY_VOICE",
            "ANTI_TREMOR",
            "ANTI_TREMOR",
            "EDOG_VOICE",
            "EDOG_VOICE",
            "IR_SWITCH",
            "IR_SWITCH"
        ])
        #expect(commandMessages.map(\.operation) == [
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post,
            .get,
            .post
        ])
        #expect(commandMessages[1].parameters["status"]?.intValue == 1)
        #expect(commandMessages[3].parameters["sync"]?.intValue == 1)
        #expect(commandMessages[5].parameters["status"]?.intValue == 1)
        #expect(commandMessages[7].parameters["freq"]?.stringValue == "50Hz")
        #expect(commandMessages[9].parameters["volume"]?.intValue == 5)
        #expect(commandMessages[11].parameters["speech"]?.intValue == 1)
        #expect(commandMessages[13].parameters["voice"]?.intValue == 1)
        #expect(commandMessages[15].parameters["status"]?.intValue == 1)
        #expect(commandMessages[17].parameters["status"]?.intValue == 1)
        #expect(commandMessages[19].parameters["status"]?.intValue == 1)
        #expect(fetchedIntervalRecording?.isEnabled == true)
        #expect(updatedIntervalRecording?.isEnabled == true)
        #expect(fetchedGPSTimeSync?.isEnabled == true)
        #expect(updatedGPSTimeSync?.isEnabled == true)
        #expect(fetchedDrivingRestReminder?.isEnabled == true)
        #expect(updatedDrivingRestReminder?.isEnabled == true)
        #expect(fetchedLightFrequency?.frequency == .hz50)
        #expect(updatedLightFrequency?.frequency == .hz50)
        #expect(fetchedSpeakerVolume?.volume == 5)
        #expect(updatedSpeakerVolume?.volume == 5)
        #expect(fetchedSpeech?.isEnabled == true)
        #expect(updatedSpeech?.isEnabled == true)
        #expect(fetchedKeyVoice?.isEnabled == true)
        #expect(updatedKeyVoice?.isEnabled == true)
        #expect(fetchedAntiTremor?.isEnabled == true)
        #expect(updatedAntiTremor?.isEnabled == true)
        #expect(fetchedElectronicDogVoice?.isEnabled == true)
        #expect(updatedElectronicDogVoice?.isEnabled == true)
        #expect(fetchedInfraredLight?.isEnabled == true)
        #expect(updatedInfraredLight?.isEnabled == true)
    }

    @Test
    func dangerousCommandsSendConfirmedTopicsThroughSession() async throws {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var completedTopics: [String] = []
        let validChecksum = "sha256:4a9b4f2b5d7e31c04a9b4f2b5d7e31c04a9b4f2b5d7e31c04a9b4f2b5d7e31c0"

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.deleteFile(path: "/DCIMA/REC00001.AVI") { result in
            if case .success(let deletion) = result, deletion.deleted {
                completedTopics.append("FILE_DELETE")
            }
        }
        session.setFileLocked(path: "/DCIMA/REC00001.AVI") { result in
            if case .success(let lock) = result, lock.locked {
                completedTopics.append("FILE_LOCK")
            }
        }
        session.fetchAccessPointIdentity { result in
            if case .success(let identity) = result, identity.ssid == "Cam360_AP" {
                completedTopics.append("AP_SSID_INFO_GET")
            }
        }
        session.updateAccessPointIdentity(ssid: "Cam360_New", password: "12345678") { result in
            if case .success(let identity) = result, identity.ssid == "Cam360_New" {
                completedTopics.append("AP_SSID_INFO_POST")
            }
        }
        session.formatStorage { result in
            if case .success(let format) = result, format.formatted {
                completedTopics.append("FORMAT")
            }
        }
        session.restoreDefaultConfiguration { result in
            if case .success(let restore) = result, restore.restored {
                completedTopics.append("SYSTEM_DEFAULT")
            }
        }
        let upgradeCandidate = try #require(DeviceFirmwareUpgradeCandidate(
            latestVersion: "v1.1.0",
            packageSize: 33_554_432,
            checksum: validChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ==",
            releaseNotes: ["优化录像稳定性", "修复时间戳显示问题"]
        ))
        session.checkFirmwareUpgrade(
            candidate: upgradeCandidate
        ) { result in
            if case .success(let check) = result, check.upgradeAllowed {
                completedTopics.append("UPGRADE_CHECK")
            }
        }
        let upgradePackage = try #require(DeviceFirmwareUpgradePackage(
            targetVersion: "v1.1.0",
            packageURL: "http://192.168.25.2:8080/upgrade/fw-v1.1.0.bin",
            packageSize: 33_554_432,
            checksum: validChecksum,
            rollbackIndex: 2_026_052_501,
            signatureAlgorithm: "ed25519",
            signature: "YmFzZTY0LXNpZ25hdHVyZQ=="
        ))
        session.startFirmwareUpgrade(
            package: upgradePackage
        ) { result in
            if case .success(let start) = result, start.accepted {
                completedTopics.append("UPGRADE_CTRL")
            }
        }

        #expect(await waitForSessionState { completedTopics.count == 8 })
        let commandMessages = Array(transport.sentMessages.suffix(8))
        #expect(commandMessages.map(\.topic) == [
            "FILE_DELETE",
            "FILE_LOCK",
            "AP_SSID_INFO",
            "AP_SSID_INFO",
            "FORMAT",
            "SYSTEM_DEFAULT",
            "UPGRADE_CHECK",
            "UPGRADE_CTRL"
        ])
        #expect(commandMessages[2].operation == .get)
        #expect(commandMessages[3].operation == .post)
        #expect(commandMessages[3].parameters["ssid"]?.stringValue == "Cam360_New")
        #expect(commandMessages[6].parameters["latest_version"]?.stringValue == "v1.1.0")
        #expect(commandMessages[7].parameters["action"]?.stringValue == "start")
        #expect(commandMessages[7].parameters["package_url"]?.stringValue == "http://192.168.25.2:8080/upgrade/fw-v1.1.0.bin")
    }

    @Test
    func fileDeleteCommandRejectsBlankProtocolPathBeforeSending() async {
        await expectControlCommandRejectedForInvalidParameters(topic: "FILE_DELETE") { session, completion in
            session.deleteFile(path: " ", completion: completion)
        }
    }

    @Test
    func fileLockCommandRequiresDeclaredFileLockCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: legacyCameraCapabilities()
            )
        }
        var result: Result<DeviceFileLockResult, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.setFileLocked(path: "/DCIMA/REC00001.AVI") { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "FILE_LOCK")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "FILE_LOCK" } == false)
    }

    @Test
    func fileUnlockCommandRequiresDeclaredFileUnlockCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var result: Result<DeviceFileLockResult, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.setFileLocked(path: "/DCIMA/REC00001.AVI", locked: false) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "FILE_LOCK")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "FILE_LOCK" } == false)
    }

    @Test
    func fileLockCommandRejectsBlankProtocolFileBeforeSending() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var result: Result<DeviceFileLockResult, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.setFileLocked(path: " ") { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -2)
            #expect(topic == "FILE_LOCK")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "FILE_LOCK" } == false)
    }

    @Test
    func accessPointIdentityReadRequiresDeclaredWifiConfigurationCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([:])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceAccessPointIdentity, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchAccessPointIdentity { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "AP_SSID_INFO")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "AP_SSID_INFO" } == false)
    }

    @Test
    func accessPointIdentityUpdateRequiresDeclaredEditableWifiCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([
            "wifi_config": true,
            "wifi_ssid_editable": false,
            "wifi_pwd_editable": false
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceAccessPointIdentity, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.updateAccessPointIdentity(ssid: "Cam360_New", password: "12345678") { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "AP_SSID_INFO")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "AP_SSID_INFO" } == false)
    }

    @Test
    func accessPointIdentityUpdateRejectsInvalidDocumentedParametersBeforeSending() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        let invalidRequests = [
            (ssid: "", password: "12345678"),
            (ssid: String(repeating: "A", count: 33), password: "12345678"),
            (ssid: "Cam360_New", password: "short"),
            (ssid: "Cam360_New", password: "1234567é")
        ]

        for request in invalidRequests {
            var result: Result<DeviceAccessPointIdentity, DeviceSessionCommandError>?
            session.updateAccessPointIdentity(ssid: request.ssid, password: request.password) { commandResult in
                result = commandResult
            }

            #expect(await waitForSessionState { result != nil })
            if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
                #expect(errno == -2)
                #expect(topic == "AP_SSID_INFO")
            } else {
                #expect(Bool(false))
            }
        }
        #expect(transport.sentMessages.contains { $0.topic == "AP_SSID_INFO" } == false)
    }

    @Test
    func restoreDefaultCommandRequiresDeclaredFactoryResetCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([
            "wifi_config": true,
            "wifi_ssid_editable": true,
            "wifi_pwd_editable": true,
            "factory_reset": false
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceSystemDefaultResult, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.restoreDefaultConfiguration { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "SYSTEM_DEFAULT")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "SYSTEM_DEFAULT" } == false)
    }

    @Test
    func autoShutdownCommandRequiresDeclaredSystemCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([
            "wifi_config": true,
            "wifi_ssid_editable": true,
            "wifi_pwd_editable": true,
            "factory_reset": true,
            "auto_shutdown": false,
            "screen_protect": true,
            "hour_type": [12, 24]
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceAutoShutdownSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchAutoShutdown { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "AUTO_SHUTDOWN")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "AUTO_SHUTDOWN" } == false)
    }

    @Test
    func screenProtectionCommandRequiresDeclaredSystemCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([
            "wifi_config": true,
            "wifi_ssid_editable": true,
            "wifi_pwd_editable": true,
            "factory_reset": true,
            "auto_shutdown": true,
            "screen_protect": false,
            "hour_type": [12, 24]
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceScreenProtectionSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchScreenProtection { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "SCREEN_PRO")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "SCREEN_PRO" } == false)
    }

    @Test
    func hourTypeReadRequiresDeclaredSystemCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([
            "wifi_config": true,
            "wifi_ssid_editable": true,
            "wifi_pwd_editable": true,
            "factory_reset": true,
            "auto_shutdown": true,
            "screen_protect": true
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceHourTypeSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchHourType { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "HOUR_TYPE")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "HOUR_TYPE" } == false)
    }

    @Test
    func hourTypeUpdateRequiresRequestedDeclaredSystemCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["system"] = .object([
            "wifi_config": true,
            "wifi_ssid_editable": true,
            "wifi_pwd_editable": true,
            "factory_reset": true,
            "auto_shutdown": true,
            "screen_protect": true,
            "hour_type": [12]
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceHourTypeSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.updateHourType(.twentyFourHour) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "HOUR_TYPE")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "HOUR_TYPE" } == false)
    }

    @Test
    func videoMicrophoneCommandRequiresDeclaredAudioCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["audio"] = .object([
            "supported": true,
            "mic_switchable": false,
            "speaker_volume": true,
            "speech": true,
            "key_voice": true
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceVideoMicrophoneSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchVideoMicrophone { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "VIDEO_MIC")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "VIDEO_MIC" } == false)
    }

    @Test
    func speakerVolumeCommandRequiresDeclaredAudioCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["audio"] = .object([
            "supported": true,
            "mic_switchable": true,
            "speaker_volume": false,
            "speech": true,
            "key_voice": true
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceSpeakerVolumeSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchSpeakerVolume { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "SPEAKER_VOLUME")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "SPEAKER_VOLUME" } == false)
    }

    @Test
    func speechCommandRequiresDeclaredAudioCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["audio"] = .object([
            "supported": true,
            "mic_switchable": true,
            "speaker_volume": true,
            "speech": false,
            "key_voice": true
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceSpeechSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchSpeech { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "SPEECH")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "SPEECH" } == false)
    }

    @Test
    func keyVoiceCommandRequiresDeclaredAudioCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var capabilities = defaultCameraCapabilities()
        capabilities["audio"] = .object([
            "supported": true,
            "mic_switchable": true,
            "speaker_volume": true,
            "speech": true,
            "key_voice": false
        ])
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: capabilities
            )
        }
        var result: Result<DeviceKeyVoiceSetting, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchKeyVoice { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "KEY_VOICE")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "KEY_VOICE" } == false)
    }

    @Test
    func imageSettingCommandsRequireDeclaredImageCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": false,
            "exposure_options": [-2, 0, 2],
            "mirror": true,
            "flip": true,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": true,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "VIDEO_WDR", cameraCapabilities: capabilities) { session, completion in
            session.fetchVideoWideDynamicRange(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [],
            "mirror": true,
            "flip": true,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": true,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "VIDEO_EXP", cameraCapabilities: capabilities) { session, completion in
            session.fetchVideoExposure(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [-2, 0, 2],
            "mirror": false,
            "flip": true,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": true,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "MIRROR_HOR", cameraCapabilities: capabilities) { session, completion in
            session.fetchHorizontalMirror(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [-2, 0, 2],
            "mirror": true,
            "flip": false,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": true,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "FLIP_VER", cameraCapabilities: capabilities) { session, completion in
            session.fetchVerticalFlip(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [-2, 0, 2],
            "mirror": true,
            "flip": true,
            "light_frequency": ["60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": true,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "LIGHT_FRE", cameraCapabilities: capabilities) { session, completion in
            session.updateLightFrequency(.hz50, completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [-2, 0, 2],
            "mirror": true,
            "flip": true,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["NTSC"],
            "anti_tremor": true,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "TV_MODE", cameraCapabilities: capabilities) { session, completion in
            session.updateTVMode(.pal, completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [-2, 0, 2],
            "mirror": true,
            "flip": true,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": false,
            "ir_switch": true,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "ANTI_TREMOR", cameraCapabilities: capabilities) { session, completion in
            session.fetchAntiTremor(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["image"] = .object([
            "wdr": true,
            "exposure_options": [-2, 0, 2],
            "mirror": true,
            "flip": true,
            "light_frequency": ["50Hz", "60Hz"],
            "tv_mode": ["PAL", "NTSC"],
            "anti_tremor": true,
            "ir_switch": false,
            "snapshot_transport": ["base64"]
        ])
        await expectControlCommandBlocked(topic: "IR_SWITCH", cameraCapabilities: capabilities) { session, completion in
            session.fetchInfraredLight(completion: completion)
        }
    }

    @Test
    func parkingSettingCommandsRequireDeclaredParkingCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["parking"] = .object([
            "supported": false,
            "modes": ["off", "timelapse", "normal"],
            "monitor_time_options": [0, 6, 12, 24, 48, 96],
            "voltage_protection": [11.8, 12.0, 12.2, 12.5],
            "guard_switch": true,
            "collision_sensitivity": [0, 1, 2]
        ])
        await expectControlCommandBlocked(topic: "MOVE_CHECK", cameraCapabilities: capabilities) { session, completion in
            session.fetchMotionDetection(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["parking"] = .object([
            "supported": true,
            "modes": ["off"],
            "monitor_time_options": [0, 6, 12, 24, 48, 96],
            "voltage_protection": [11.8, 12.0, 12.2, 12.5],
            "guard_switch": true,
            "collision_sensitivity": [0, 1, 2]
        ])
        await expectControlCommandBlocked(topic: "MONITOR_MODE", cameraCapabilities: capabilities) { session, completion in
            session.updateParkingMonitorMode(.normalRecording, completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["parking"] = .object([
            "supported": true,
            "modes": ["off", "timelapse", "normal"],
            "monitor_time_options": [0, 6],
            "voltage_protection": [11.8, 12.0, 12.2, 12.5],
            "guard_switch": true,
            "collision_sensitivity": [0, 1, 2]
        ])
        await expectControlCommandBlocked(topic: "MONITOR_TIME", cameraCapabilities: capabilities) { session, completion in
            session.updateParkingMonitorDuration(.twelveHours, completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["parking"] = .object([
            "supported": true,
            "modes": ["off", "timelapse", "normal"],
            "monitor_time_options": [0, 6, 12, 24, 48, 96],
            "voltage_protection": [11.8, 12.0],
            "guard_switch": true,
            "collision_sensitivity": [0, 1, 2]
        ])
        await expectControlCommandBlocked(topic: "VOLTAGE_PRO", cameraCapabilities: capabilities) { session, completion in
            session.updateVoltageProtection(.twelvePointFiveVolts, completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["parking"] = .object([
            "supported": true,
            "modes": ["off", "timelapse", "normal"],
            "monitor_time_options": [0, 6, 12, 24, 48, 96],
            "voltage_protection": [11.8, 12.0, 12.2, 12.5],
            "guard_switch": false,
            "collision_sensitivity": [0, 1, 2]
        ])
        await expectControlCommandBlocked(topic: "VIDEO_PAR_CAR", cameraCapabilities: capabilities) { session, completion in
            session.fetchParkingGuard(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["parking"] = .object([
            "supported": true,
            "modes": ["off", "timelapse", "normal"],
            "monitor_time_options": [0, 6, 12, 24, 48, 96],
            "voltage_protection": [11.8, 12.0, 12.2, 12.5],
            "guard_switch": true,
            "collision_sensitivity": []
        ])
        await expectControlCommandBlocked(topic: "GRA_SEN", cameraCapabilities: capabilities) { session, completion in
            session.fetchCollisionSensitivity(completion: completion)
        }
        await expectControlCommandBlocked(topic: "VIDEO_PAR_VSIX", cameraCapabilities: capabilities) { session, completion in
            session.fetchParkingCollisionSensitivity(completion: completion)
        }
    }

    @Test
    func videoSettingCommandsRequireDeclaredVideoCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["video"] = .object([
            "supported": false,
            "resolutions": ["4K", "2K", "1080P", "720P", "WVGA"],
            "loop_modes": ["off", "1min", "3min", "5min", "10min"]
        ])
        await expectControlCommandBlocked(topic: "VIDEO_SIZE", cameraCapabilities: capabilities) { session, completion in
            session.fetchVideoSize(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["video"] = .object([
            "supported": true,
            "resolutions": ["4K", "2K"],
            "loop_modes": ["off", "1min", "3min", "5min", "10min"]
        ])
        await expectControlCommandBlocked(topic: "VIDEO_SIZE", cameraCapabilities: capabilities) { session, completion in
            session.updateVideoSize(
                supportedResolutions: ["4K", "2K", "1080P"],
                selectedIndex: 2,
                completion: completion
            )
        }

        capabilities = defaultCameraCapabilities()
        capabilities["video"] = .object([
            "supported": true,
            "resolutions": ["4K", "2K", "1080P", "720P", "WVGA"],
            "loop_modes": ["off", "1min"]
        ])
        await expectControlCommandBlocked(topic: "VIDEO_LOOP", cameraCapabilities: capabilities) { session, completion in
            session.updateVideoLoop(.threeMinutes, completion: completion)
        }
    }

    @Test
    func legacyVideoSettingCommandsRequireDeclaredVideoCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["video"] = .object([
            "supported": false,
            "resolutions": ["4K", "2K", "1080P", "720P", "WVGA"],
            "loop_modes": ["off", "1min", "3min", "5min", "10min"]
        ])

        await expectControlCommandBlocked(topic: "VIDEO_DATE", cameraCapabilities: capabilities) { session, completion in
            session.fetchVideoDateWatermark(completion: completion)
        }
        await expectControlCommandBlocked(topic: "VIDEO_PARAM", cameraCapabilities: capabilities) { session, completion in
            session.fetchVideoParameter(completion: completion)
        }
        await expectControlCommandBlocked(topic: "VIDEO_INV", cameraCapabilities: capabilities) { session, completion in
            session.fetchIntervalRecording(completion: completion)
        }
        await expectControlCommandBlocked(topic: "VIDEO_RDER", cameraCapabilities: capabilities) { session, completion in
            session.fetchDrivingRestReminder(completion: completion)
        }
    }

    @Test
    func photoSettingCommandsRequireDeclaredPhotoCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["photo"] = .object([
            "supported": false,
            "resolutions": ["VGA", "1.3M", "2M", "3M", "5M", "8M", "10M", "12M"],
            "qualities": ["low", "middle", "high"]
        ])
        await expectControlCommandBlocked(topic: "PHOTO_RESO", cameraCapabilities: capabilities) { session, completion in
            session.fetchPhotoResolution(completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["photo"] = .object([
            "supported": true,
            "resolutions": ["VGA", "1.3M"],
            "qualities": ["low", "middle", "high"]
        ])
        await expectControlCommandBlocked(topic: "PHOTO_RESO", cameraCapabilities: capabilities) { session, completion in
            session.updatePhotoResolution("12M", completion: completion)
        }

        capabilities = defaultCameraCapabilities()
        capabilities["photo"] = .object([
            "supported": true,
            "resolutions": ["VGA", "1.3M", "2M", "3M", "5M", "8M", "10M", "12M"],
            "qualities": ["low", "middle"]
        ])
        await expectControlCommandBlocked(topic: "PHOTO_QUALITY", cameraCapabilities: capabilities) { session, completion in
            session.updatePhotoQuality(.high, completion: completion)
        }
    }

    @Test
    func legacyPhotoDateWatermarkRequiresDeclaredPhotoCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["photo"] = .object([
            "supported": false,
            "resolutions": ["VGA", "1.3M", "2M", "3M", "5M", "8M", "10M", "12M"],
            "qualities": ["low", "middle", "high"]
        ])

        await expectControlCommandBlocked(topic: "PHOTO_DATE", cameraCapabilities: capabilities) { session, completion in
            session.fetchPhotoDateWatermark(completion: completion)
        }
    }

    @Test
    func realtimeGPSDataRequiresDeclaredGPSCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["gps"] = .object([
            "supported": true,
            "realtime_data": false,
            "video_overlay": true
        ])

        await expectReadOnlyCommandBlocked(topic: "VI_GPS_RTDATA", cameraCapabilities: capabilities) { session, completion in
            session.fetchRealtimeGPSData(completion: completion)
        }
    }

    @Test
    func gpsTimeSyncRequiresDeclaredGPSVideoOverlayCapability() async {
        var capabilities = defaultCameraCapabilities()
        capabilities["gps"] = .object([
            "supported": true,
            "realtime_data": true,
            "video_overlay": false
        ])

        await expectControlCommandBlocked(topic: "VIDEO_SYNC", cameraCapabilities: capabilities) { session, completion in
            session.fetchGPSTimeSync(completion: completion)
        }
    }

    @Test
    func aggregateReadCommandsSendExpectedTopicsThroughSession() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeAggregateTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var completedTopics: [String] = []

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchStateSync(scope: .home) { result in
            if case .success(let snapshot) = result, snapshot.scope == .home {
                completedTopics.append("STATE_SYNC")
            }
        }
        session.fetchRecentEvents(query: DeviceRecentEventsQuery(limit: 4)) { result in
            if case .success(let page) = result, page.items.first?.eventType == "impact" {
                completedTopics.append("RECENT_EVENTS")
            }
        }
        session.fetchMediaIndex(query: DeviceMediaIndexQuery(eventOnly: true)) { result in
            if case .success(let index) = result, index.groups.first?.items.first?.eventType == "impact" {
                completedTopics.append("MEDIA_INDEX")
            }
        }

        #expect(await waitForSessionState { completedTopics.count == 3 })
        let commandMessages = Array(transport.sentMessages.suffix(3))
        #expect(commandMessages.map(\.topic) == ["STATE_SYNC", "RECENT_EVENTS", "MEDIA_INDEX"])
        #expect(commandMessages[0].parameters["scope"]?.stringValue == "home")
        #expect(commandMessages[1].parameters["limit"]?.intValue == 4)
        #expect(commandMessages[2].parameters["event_only"]?.intValue == 1)
    }

    @Test
    func aggregateReadCommandRequiresDeclaredProtocolCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeAggregateTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: legacyCameraCapabilities()
            )
        }
        var result: Result<DeviceMediaIndexResult, DeviceSessionReadOnlyError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchMediaIndex(query: DeviceMediaIndexQuery()) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "MEDIA_INDEX")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "MEDIA_INDEX" } == false)
    }

    @Test
    func aggregateConfigurationCommandRequiresDeclaredProtocolCapability() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeAggregateTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: legacyCameraCapabilities()
            )
        }
        var result: Result<[String: DeviceProtocolValue], DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.fetchRecordingConfiguration { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let topic, _)))? = result {
            #expect(errno == -5)
            #expect(topic == "RECORDING_CONFIG")
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == "RECORDING_CONFIG" } == false)
    }

    @Test
    func aggregateSettingsCommandsUsePessimisticDeviceResponses() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeAggregateTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var completedTopics: [String] = []

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.updateRecordingConfiguration(parameters: ["auto_overwrite": 0]) { result in
            if case .success(let payload) = result,
               payload["auto_overwrite"]?.intValue == 0 {
                completedTopics.append("RECORDING_CONFIG")
            }
        }
        session.updateSafetyConfiguration(parameters: ["event_notifications": 0]) { result in
            if case .success(let payload) = result,
               payload.object("notifications")?["event_notifications"]?.intValue == 0 {
                completedTopics.append("SAFETY_CONFIG")
            }
        }
        session.updateStoragePolicyConfiguration(parameters: ["auto_overwrite": 0]) { result in
            if case .success(let payload) = result,
               payload.object("general_policy")?["auto_overwrite"]?.intValue == 0 {
                completedTopics.append("STORAGE_POLICY_CONFIG")
            }
        }
        session.updateSystemPreferencesConfiguration(parameters: ["device_name": "Road Camera"]) { result in
            if case .success(let payload) = result,
               payload.object("device_identity")?["device_name"]?.stringValue == "Road Camera" {
                completedTopics.append("SYSTEM_PREFERENCES_CONFIG")
            }
        }
        session.updateWatermarkConfiguration(parameters: ["time_enabled": 0]) { result in
            if case .success(let payload) = result,
               payload["time_enabled"]?.intValue == 0 {
                completedTopics.append("WATERMARK_CONFIG")
            }
        }

        #expect(await waitForSessionState { completedTopics.count == 5 })
        #expect(Array(transport.sentMessages.map(\.topic).suffix(5)) == [
            "RECORDING_CONFIG",
            "SAFETY_CONFIG",
            "STORAGE_POLICY_CONFIG",
            "SYSTEM_PREFERENCES_CONFIG",
            "WATERMARK_CONFIG"
        ])
    }

    @Test
    func aggregateConfigurationPostsRejectEmptyParametersBeforeSending() async {
        await expectControlCommandRejectedForInvalidParameters(topic: "RECORDING_CONFIG") { session, completion in
            session.updateRecordingConfiguration(parameters: [:], completion: completion)
        }
        await expectControlCommandRejectedForInvalidParameters(topic: "STORAGE_POLICY_CONFIG") { session, completion in
            session.updateStoragePolicyConfiguration(parameters: [:], completion: completion)
        }
        await expectControlCommandRejectedForInvalidParameters(topic: "SAFETY_CONFIG") { session, completion in
            session.updateSafetyConfiguration(parameters: [:], completion: completion)
        }
        await expectControlCommandRejectedForInvalidParameters(topic: "SYSTEM_PREFERENCES_CONFIG") { session, completion in
            session.updateSystemPreferencesConfiguration(parameters: [:], completion: completion)
        }
    }

    @Test
    func settingsStoreFetchesAggregateConfigurationWhenOpeningSettingsRoutes() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "RECORDING_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "resolution": .object(["current": "720P"]),
                    "quality_priority": .object(["current": "storage"]),
                    "loop_recording": .object(["current": 5, "unit": "min"]),
                    "auto_overwrite": 0,
                    "start_behavior": "manual",
                    "audio_recording": 1,
                    "hdr_night_recording": 0,
                    "status_indicator": 0,
                    "recording_reminder": 1
                ])
            case "STORAGE_POLICY_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "sd": .object([
                        "status": "normal",
                        "format_required": 1,
                        "policy_editable": 0
                    ]),
                    "tf": .object(["used_gb": 12.5, "total_gb": 64.0]),
                    "maintenance": .object([
                        "format_supported": 0,
                        "estimated_remaining_recording_hours": 8.0,
                        "estimate_profile": "1080P_quality",
                        "auto_cleanup": .object(["enabled": 1])
                    ]),
                    "general_policy": .object([
                        "auto_overwrite": 0,
                        "locked_event_retention": "days:7"
                    ]),
                    "storage_allocation": .object(["reserved_space_for_events_percent": 30])
                ])
            case "SAFETY_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "collision": .object([
                        "g_sensor_sensitivity": .object(["current": "high"]),
                        "emergency_video_lock": 0
                    ]),
                    "parking": .object([
                        "parking_mode": 0,
                        "motion_detection": 0,
                        "impact_detection": 0
                    ]),
                    "event_recording": .object([
                        "clip_duration_sec": .object(["current": 60])
                    ]),
                    "notifications": .object(["event_notifications": 0])
                ])
            case "SYSTEM_PREFERENCES_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "device_identity": .object(["device_name": "Docs Camera"]),
                    "connectivity": .object(["ssid": "Docs_AP"]),
                    "software": .object([
                        "firmware_version": "v9.9.9",
                        "update_entry_enabled": 0
                    ]),
                    "localization": .object(["time_zone": "GMT+9"]),
                    "audio": .object([
                        "speaker_volume": .object(["current": "high"]),
                        "status_sounds": 0
                    ])
                ])
            case "WATERMARK_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "time_enabled": 0,
                    "plate_enabled": 1,
                    "plate_number": "DOCS123",
                    "position": "bottom_right"
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.deviceSettings)
        #expect(await waitForSessionState {
            store.devicePreferences.firmwareUpdateEntryEnabled == false
        })

        store.show(.recordingSettings)
        #expect(await waitForSessionState {
            store.recordingSettings.resolution == .hd &&
                store.recordingSettings.qualityPriority == .storage &&
                store.recordingSettings.loopDuration == .fiveMinutes &&
                store.recordingSettings.audioRecordingEnabled
        })

        store.show(.storagePolicy)
        #expect(await waitForSessionState {
                store.storagePolicy.usedSpaceGB == 12.5 &&
                store.storagePolicy.totalSpaceGB == 64.0 &&
                store.storagePolicy.autoCleanupEnabled &&
                store.storagePolicy.lockedEventRetention == .sevenDays &&
                store.storagePolicy.formatRequired &&
                store.storagePolicy.estimatedHoursRemaining == "Approx. 8.0 hours remaining at 1080P_quality." &&
                store.storagePolicy.formatSupported == false &&
                store.storagePolicy.policyEditable == false
        })

        store.show(.safetySettings)
        #expect(await waitForSessionState {
            store.safetySettings.gSensorSensitivity == .high &&
                store.safetySettings.eventClipDuration == .sixtySeconds &&
                store.safetySettings.eventNotificationsEnabled == false
        })

        store.show(.systemPreferences)
        #expect(await waitForSessionState {
            store.devicePreferences.deviceName == "Docs Camera" &&
                store.devicePreferences.connectionName == "Docs_AP" &&
                store.devicePreferences.firmwareVersion == "v9.9.9" &&
                store.devicePreferences.speakerVolume == .high &&
                store.devicePreferences.statusSoundsEnabled == false
        })

        store.show(.watermarkConfiguration)
        #expect(await waitForSessionState {
            store.watermarkConfiguration.timestampEnabled == false &&
                store.watermarkConfiguration.licensePlate == "DOCS123"
        })

        let configTopics = transport.sentMessages.map(\.topic).filter {
            [
                "RECORDING_CONFIG",
                "STORAGE_POLICY_CONFIG",
                "SAFETY_CONFIG",
                "SYSTEM_PREFERENCES_CONFIG",
                "WATERMARK_CONFIG"
            ].contains($0)
        }
        #expect(configTopics == [
            "SYSTEM_PREFERENCES_CONFIG",
            "RECORDING_CONFIG",
            "STORAGE_POLICY_CONFIG",
            "SAFETY_CONFIG",
            "SYSTEM_PREFERENCES_CONFIG",
            "WATERMARK_CONFIG"
        ])
    }

    @Test
    func settingsStorePrefersStateSyncWhenOpeningSettingsRoutes() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                switch request.parameters["scope"]?.stringValue {
                case "recording":
                    return makeTopicResponse(request, parameters: [
                        "scope": request.parameters["scope"] ?? "recording",
                        "sections": .object([
                            "recording": .object([
                                "resolution": .object(["current": "720P"]),
                                "quality_priority": .object(["current": "storage"]),
                                "loop_recording": .object(["current": 5, "unit": "min"]),
                                "auto_overwrite": 0,
                                "start_behavior": "manual",
                                "audio_recording": 1,
                                "hdr_night_recording": 0,
                                "status_indicator": 0,
                                "recording_reminder": 1
                            ])
                        ])
                    ])
                case "storage":
                    return makeTopicResponse(request, parameters: [
                        "scope": request.parameters["scope"] ?? "storage",
                        "sections": .object([
                            "storage": .object([
                                "sd": .object([
                                    "status": "normal",
                                    "format_required": 1,
                                    "policy_editable": 0
                                ]),
                                "tf": .object(["used_gb": 12.5, "total_gb": 64.0]),
                                "maintenance": .object([
                                    "format_supported": 0,
                                    "estimated_remaining_recording_hours": 8.0,
                                    "auto_cleanup": .object(["enabled": 1])
                                ]),
                                "general_policy": .object([
                                    "auto_overwrite": 0,
                                    "locked_event_retention": "days:7"
                                ]),
                                "storage_allocation": .object(["reserved_space_for_events_percent": 30])
                            ])
                        ])
                    ])
                case "safety":
                    return makeTopicResponse(request, parameters: [
                        "scope": request.parameters["scope"] ?? "safety",
                        "sections": .object([
                            "safety": .object([
                                "collision": .object([
                                    "g_sensor_sensitivity": .object(["current": "high"]),
                                    "emergency_video_lock": 0
                                ]),
                                "parking": .object([
                                    "parking_mode": 0,
                                    "motion_detection": 0,
                                    "impact_detection": 0
                                ]),
                                "event_recording": .object([
                                    "clip_duration_sec": .object(["current": 60])
                                ]),
                                "notifications": .object(["event_notifications": 0])
                            ])
                        ])
                    ])
                case "system_preferences":
                    return makeTopicResponse(request, parameters: [
                        "scope": request.parameters["scope"] ?? "system_preferences",
                        "sections": .object([
                            "system_preferences": .object([
                                "device_identity": .object(["device_name": "Docs Camera"]),
                                "connectivity": .object(["ssid": "Docs_AP"]),
                                "software": .object([
                                    "firmware_version": "v9.9.9",
                                    "update_entry_enabled": 0
                                ]),
                                "localization": .object(["time_zone": "GMT+9"]),
                                "audio": .object([
                                    "speaker_volume": .object(["current": "high"]),
                                    "status_sounds": 0
                                ])
                            ])
                        ])
                    ])
                case "watermark":
                    return makeTopicResponse(request, parameters: [
                        "scope": request.parameters["scope"] ?? "watermark",
                        "sections": .object([
                            "watermark": .object([
                                "time_enabled": 0,
                                "plate_enabled": 1,
                                "plate_number": "DOCS123",
                                "position": "bottom_right"
                            ])
                        ])
                    ])
                default:
                    return makeHandshakeResponse(request)
                }
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.deviceSettings)
        #expect(await waitForSessionState {
            store.devicePreferences.firmwareUpdateEntryEnabled == false
        })

        store.show(.recordingSettings)
        #expect(await waitForSessionState {
            store.recordingSettings.resolution == .hd &&
                store.recordingSettings.qualityPriority == .storage &&
                store.recordingSettings.loopDuration == .fiveMinutes &&
                store.recordingSettings.audioRecordingEnabled
        })

        store.show(.storagePolicy)
        #expect(await waitForSessionState {
            store.storagePolicy.usedSpaceGB == 12.5 &&
                store.storagePolicy.totalSpaceGB == 64.0 &&
                store.storagePolicy.autoCleanupEnabled &&
                store.storagePolicy.lockedEventRetention == .sevenDays &&
                store.storagePolicy.formatRequired &&
                store.storagePolicy.formatSupported == false &&
                store.storagePolicy.policyEditable == false
        })

        store.show(.safetySettings)
        #expect(await waitForSessionState {
            store.safetySettings.gSensorSensitivity == .high &&
                store.safetySettings.eventClipDuration == .sixtySeconds &&
                store.safetySettings.eventNotificationsEnabled == false
        })

        store.show(.systemPreferences)
        #expect(await waitForSessionState {
                store.devicePreferences.deviceName == "Docs Camera" &&
                store.devicePreferences.connectionName == "Docs_AP" &&
                store.devicePreferences.firmwareVersion == "v9.9.9" &&
                store.devicePreferences.firmwareUpdateEntryEnabled == false &&
                store.devicePreferences.speakerVolume == .high &&
                store.devicePreferences.statusSoundsEnabled == false
        })

        store.show(.watermarkConfiguration)
        #expect(await waitForSessionState {
            store.watermarkConfiguration.timestampEnabled == false &&
                store.watermarkConfiguration.licensePlate == "DOCS123"
        })

        let stateSyncScopes = transport.sentMessages.compactMap { message in
            message.topic == "STATE_SYNC" ? message.parameters["scope"]?.stringValue : nil
        }
        #expect(stateSyncScopes.suffix(6) == [
            "system_preferences",
            "recording",
            "storage",
            "safety",
            "system_preferences",
            "watermark"
        ])
        let configTopics = transport.sentMessages.map(\.topic).filter {
            [
                "RECORDING_CONFIG",
                "STORAGE_POLICY_CONFIG",
                "SAFETY_CONFIG",
                "SYSTEM_PREFERENCES_CONFIG",
                "WATERMARK_CONFIG"
            ].contains($0)
        }
        #expect(configTopics.isEmpty)
    }

    @Test
    func settingsStoreDisablesUnsupportedSystemPreferenceActionsFromStateSync() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "system_preferences",
                    "sections": .object([
                        "system_preferences": .object([
                            "device_identity": .object([
                                "device_name": "Docs Camera",
                                "device_name_editable": 0
                            ]),
                            "maintenance": .object(["factory_reset_supported": 0])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.systemPreferences)
        #expect(await waitForSessionState {
            store.devicePreferences.deviceName == "Docs Camera"
        })

        store.setRenameDeviceDraft("Blocked Camera")
        store.renameDevice(dismissRoute: false)
        #expect(store.devicePreferences.deviceName == "Docs Camera")

        store.updateWatermarkConfiguration(\.licensePlate, to: "KEEP123")
        store.restoreDefaultDeviceConfiguration()
        #expect(store.watermarkConfiguration.licensePlate == "KEEP123")
    }

    @Test
    func settingsStorePreservesLoadedSystemPreferenceLocalizationWhenSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var receivedSystemPreferencePost: [String: DeviceProtocolValue]?
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "system_preferences",
                    "sections": .object([
                        "system_preferences": .object([
                            "device_identity": .object(["device_name": "Docs Camera"]),
                            "connectivity": .object([
                                "ssid": "Docs_AP",
                                "status": "disconnected"
                            ]),
                            "localization": .object([
                                "time_zone": "GMT+9",
                                "language": "en-US",
                                "date_time_auto_sync": 0
                            ]),
                            "audio": .object([
                                "speaker_volume": .object(["current": "low"]),
                                "status_sounds": 0
                            ])
                        ])
                    ])
                ])
            case "SYSTEM_PREFERENCES_CONFIG":
                receivedSystemPreferencePost = request.parameters
                return makeTopicResponse(request, parameters: [
                    "device_identity": .object([
                        "device_name": request.parameters["device_name"] ?? "Docs Camera"
                    ]),
                    "connectivity": .object([
                        "ssid": "Docs_AP",
                        "status": "disconnected"
                    ]),
                    "localization": .object([
                        "time_zone": request.parameters["time_zone"] ?? "GMT+9",
                        "language": request.parameters["language"] ?? "en-US",
                        "date_time_auto_sync": request.parameters["date_time_auto_sync"] ?? 0
                    ]),
                    "audio": .object([
                        "speaker_volume": .object(["current": request.parameters["speaker_volume"] ?? "low"]),
                        "status_sounds": request.parameters["status_sounds"] ?? 0
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.systemPreferences)
        #expect(await waitForSessionState {
            store.devicePreferences.timeZone == "GMT+9" &&
                store.devicePreferences.speakerVolume == .low
        })
        let loadedFields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: store.devicePreferences).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        #expect(loadedFields["connectionStatus"] as? String == "disconnected")
        #expect(loadedFields["language"] as? String == "en-US")
        #expect(loadedFields["dateTimeAutoSyncEnabled"] as? Bool == false)

        store.updateDevicePreferences(\.statusSoundsEnabled, to: true)
        #expect(await waitForSessionState { receivedSystemPreferencePost != nil })
        #expect(receivedSystemPreferencePost?["language"]?.stringValue == "en-US")
        #expect(receivedSystemPreferencePost?["date_time_auto_sync"]?.intValue == 0)
        #expect(receivedSystemPreferencePost?["status_sounds"]?.intValue == 1)
    }

    @Test
    func settingsStoreUsesDeviceDeclaredSpeakerVolumeOptions() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "system_preferences",
                    "sections": .object([
                        "system_preferences": .object([
                            "audio": .object([
                                "speaker_volume": .object([
                                    "options": .array(["low", "high"]),
                                    "current": "high"
                                ]),
                                "status_sounds": 1
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.systemPreferences)
        #expect(await waitForSessionState { store.devicePreferences.speakerVolume == .high })

        let loadedFields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: store.devicePreferences).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        #expect(loadedFields["speakerVolumeOptions"] as? [SpeakerVolumeOption] == [.low, .high])
    }

    @Test
    func settingsStoreUsesDeviceDeclaredRecordingOptionsAndEstimate() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "recording",
                    "sections": .object([
                        "recording": .object([
                            "resolution": .object([
                                "options": .array(["720P", "WVGA"]),
                                "current": "WVGA"
                            ]),
                            "quality_priority": .object([
                                "options": .array(["storage"]),
                                "current": "storage"
                            ]),
                            "loop_recording": .object([
                                "options": .array([1, 5]),
                                "current": 5,
                                "unit": "min"
                            ]),
                            "auto_overwrite": 1,
                            "start_behavior": "manual",
                            "audio_recording": 0,
                            "hdr_night_recording": 0,
                            "status_indicator": 1,
                            "recording_reminder": 0,
                            "estimated_storage_per_hour_mb": 2048
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.recordingSettings)
        #expect(await waitForSessionState {
            store.recordingSettings.resolution == .wideVGA &&
                store.recordingSettings.qualityPriority == .storage &&
                store.recordingSettings.loopDuration == .fiveMinutes
        })

        let loadedFields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: store.recordingSettings).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        #expect(loadedFields["resolutionOptions"] as? [RecordingResolutionOption] == [.hd, .wideVGA])
        #expect(loadedFields["qualityPriorityOptions"] as? [RecordingQualityPriorityOption] == [.storage])
        #expect(loadedFields["loopDurationOptions"] as? [LoopRecordingDurationOption] == [.oneMinute, .fiveMinutes])
        #expect(loadedFields["estimatedStoragePerHour"] as? String == "Estimated storage per hour: ~2.0 GB")
    }

    @Test
    func settingsStoreUsesDeviceDeclaredSafetyOptions() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "safety",
                    "sections": .object([
                        "safety": .object([
                            "collision": .object([
                                "g_sensor_sensitivity": .object([
                                    "options": .array(["low", "high"]),
                                    "current": "high"
                                ]),
                                "emergency_video_lock": 1
                            ]),
                            "parking": .object([
                                "parking_mode": 1,
                                "motion_detection": 0,
                                "impact_detection": 1
                            ]),
                            "event_recording": .object([
                                "clip_duration_sec": .object([
                                    "options": .array([15, 60]),
                                    "current": 60
                                ])
                            ]),
                            "notifications": .object(["event_notifications": 0])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.safetySettings)
        #expect(await waitForSessionState {
            store.safetySettings.gSensorSensitivity == .high &&
                store.safetySettings.eventClipDuration == .sixtySeconds
        })

        let loadedFields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: store.safetySettings).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        #expect(loadedFields["gSensorSensitivityOptions"] as? [SafetySensitivityOption] == [.low, .high])
        #expect(loadedFields["eventClipDurationOptions"] as? [EventClipDurationOption] == [.fifteenSeconds, .sixtySeconds])
    }

    @Test
    func settingsStorePostsSafetyResetDefaultsAndAppliesFinalConfiguration() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var receivedSafetyPost: [String: DeviceProtocolValue]?
        transport.responseProvider = { request in
            switch request.topic {
            case "SAFETY_CONFIG":
                receivedSafetyPost = request.parameters
                return makeTopicResponse(request, parameters: [
                    "collision": .object([
                        "g_sensor_sensitivity": .object([
                            "options": .array(["low", "medium", "high"]),
                            "current": "low"
                        ]),
                        "emergency_video_lock": 0
                    ]),
                    "parking": .object([
                        "parking_mode": 0,
                        "motion_detection": 0,
                        "impact_detection": 0
                    ]),
                    "event_recording": .object([
                        "clip_duration_sec": .object([
                            "options": .array([15, 30, 60]),
                            "current": 15
                        ])
                    ]),
                    "notifications": .object(["event_notifications": 0])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.restoreSafetyDefaults()
        #expect(await waitForSessionState { receivedSafetyPost != nil })
        #expect(receivedSafetyPost?["reset_defaults"]?.intValue == 1)
        #expect(store.safetySettings.gSensorSensitivity == .low)
        #expect(store.safetySettings.parkingModeEnabled == false)
        #expect(store.safetySettings.eventClipDuration == .fifteenSeconds)
        #expect(store.safetySettings.eventNotificationsEnabled == false)
    }

    @Test
    func settingsStorePreservesStorageAutoCleanupRetentionWhenSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var receivedStoragePolicyPost: [String: DeviceProtocolValue]?
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "storage",
                    "sections": .object([
                        "storage": .object([
                            "sd": .object([
                                "status": "normal",
                                "format_required": 0,
                                "policy_editable": 1
                            ]),
                            "tf": .object(["used_gb": 10.0, "total_gb": 64.0]),
                            "maintenance": .object([
                                "format_supported": 1,
                                "estimated_remaining_recording_hours": 6.0,
                                "estimate_profile": "720P_storage",
                                "auto_cleanup": .object([
                                    "enabled": 1,
                                    "retention_days": 60
                                ])
                            ]),
                            "general_policy": .object([
                                "auto_overwrite": 1,
                                "locked_event_retention": "days:30"
                            ]),
                            "storage_allocation": .object(["reserved_space_for_events_percent": 25])
                        ])
                    ])
                ])
            case "STORAGE_POLICY_CONFIG":
                receivedStoragePolicyPost = request.parameters
                return makeTopicResponse(request, parameters: [
                    "sd": .object([
                        "status": "normal",
                        "format_required": 0,
                        "policy_editable": 1
                    ]),
                    "tf": .object(["used_gb": 10.0, "total_gb": 64.0]),
                    "maintenance": .object([
                        "format_supported": 1,
                        "estimated_remaining_recording_hours": 6.0,
                        "estimate_profile": "720P_storage",
                        "auto_cleanup": request.parameters["auto_cleanup"] ?? .object([
                            "enabled": 1,
                            "retention_days": 60
                        ])
                    ]),
                    "general_policy": .object([
                        "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
                        "locked_event_retention": request.parameters["locked_event_retention"] ?? "days:30"
                    ]),
                    "storage_allocation": .object([
                        "reserved_space_for_events_percent": request.parameters["reserved_space_for_events_percent"] ?? 25
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.storagePolicy)
        #expect(await waitForSessionState {
            store.storagePolicy.estimatedHoursRemaining == "Approx. 6.0 hours remaining at 720P_storage."
        })
        let loadedFields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: store.storagePolicy).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        #expect(loadedFields["autoCleanupRetentionDays"] as? Int == 60)

        store.updateStoragePolicy(\.autoOverwriteEnabled, to: false)
        #expect(await waitForSessionState { receivedStoragePolicyPost != nil })
        let postedAutoCleanup = receivedStoragePolicyPost?["auto_cleanup"]?.objectValue
        #expect(postedAutoCleanup?["enabled"]?.intValue == 1)
        #expect(postedAutoCleanup?["retention_days"]?.intValue == 60)
    }

    @Test
    func settingsStoreDoesNotPostStoragePolicyWhenDeviceDisablesPolicyEditing() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var receivedStoragePolicyPost: [String: DeviceProtocolValue]?
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "storage",
                    "sections": .object([
                        "storage": .object([
                            "sd": .object([
                                "online": 1,
                                "status": "normal",
                                "format_required": 0,
                                "policy_editable": 0
                            ]),
                            "tf": .object([
                                "used_gb": 10.0,
                                "total_gb": 64.0,
                                "usage_percent": 16
                            ]),
                            "maintenance": .object([
                                "format_supported": 1,
                                "auto_cleanup": .object([
                                    "enabled": 1,
                                    "retention_days": 60
                                ])
                            ]),
                            "general_policy": .object([
                                "auto_overwrite": 1,
                                "locked_event_retention": "forever"
                            ]),
                            "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                        ])
                    ])
                ])
            case "STORAGE_POLICY_CONFIG":
                receivedStoragePolicyPost = request.parameters
                return makeTopicResponse(request, parameters: [
                    "sd": .object(["online": 1, "status": "normal", "policy_editable": 0]),
                    "tf": .object(["used_gb": 10.0, "total_gb": 64.0, "usage_percent": 16]),
                    "maintenance": .object([
                        "format_supported": 1,
                        "auto_cleanup": .object([
                            "enabled": 1,
                            "retention_days": 60
                        ])
                    ]),
                    "general_policy": .object([
                        "auto_overwrite": 1,
                        "locked_event_retention": "forever"
                    ]),
                    "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.storagePolicy)
        #expect(await waitForSessionState {
            store.storagePolicy.policyEditable == false &&
                store.storagePolicy.autoOverwriteEnabled
        })

        store.updateStoragePolicy(\.autoOverwriteEnabled, to: false)
        #expect(await waitForSessionState(timeout: 0.2) { receivedStoragePolicyPost != nil } == false)
        #expect(store.storagePolicy.autoOverwriteEnabled)
    }

    @Test
    func settingsStoreClampsStorageReservedEventSpaceBeforeSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var receivedStoragePolicyPost: [String: DeviceProtocolValue]?
        transport.responseProvider = { request in
            switch request.topic {
            case "STORAGE_POLICY_CONFIG":
                receivedStoragePolicyPost = request.parameters
                return makeTopicResponse(request, parameters: [
                    "sd": .object(["online": 1, "status": "normal", "policy_editable": 1]),
                    "tf": .object(["used_gb": 10.0, "total_gb": 64.0]),
                    "maintenance": .object([
                        "format_supported": 1,
                        "auto_cleanup": request.parameters["auto_cleanup"] ?? .object([
                            "enabled": 1,
                            "retention_days": 30
                        ])
                    ]),
                    "general_policy": .object([
                        "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
                        "locked_event_retention": request.parameters["locked_event_retention"] ?? "forever"
                    ]),
                    "storage_allocation": .object([
                        "reserved_space_for_events_percent": request.parameters["reserved_space_for_events_percent"] ?? 20
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.updateStoragePolicy(\.reservedEventSpacePercent, to: 75)

        #expect(await waitForSessionState { receivedStoragePolicyPost != nil })
        #expect(receivedStoragePolicyPost?["reserved_space_for_events_percent"]?.intValue == 50)
        #expect(store.storagePolicy.reservedEventSpacePercent == 50)
    }

    @Test
    func settingsStoreNormalizesStorageAutoCleanupRetentionBeforeSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var receivedStoragePolicyPost: [String: DeviceProtocolValue]?
        transport.responseProvider = { request in
            switch request.topic {
            case "STORAGE_POLICY_CONFIG":
                receivedStoragePolicyPost = request.parameters
                return makeTopicResponse(request, parameters: [
                    "sd": .object(["online": 1, "status": "normal", "policy_editable": 1]),
                    "tf": .object(["used_gb": 10.0, "total_gb": 64.0]),
                    "maintenance": .object([
                        "format_supported": 1,
                        "auto_cleanup": request.parameters["auto_cleanup"] ?? .object([
                            "enabled": 1,
                            "retention_days": 30
                        ])
                    ]),
                    "general_policy": .object([
                        "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
                        "locked_event_retention": request.parameters["locked_event_retention"] ?? "forever"
                    ]),
                    "storage_allocation": .object([
                        "reserved_space_for_events_percent": request.parameters["reserved_space_for_events_percent"] ?? 20
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.updateStoragePolicy(\.autoCleanupRetentionDays, to: 45)

        #expect(await waitForSessionState { receivedStoragePolicyPost != nil })
        let postedAutoCleanup = receivedStoragePolicyPost?["auto_cleanup"]?.objectValue
        #expect(postedAutoCleanup?["retention_days"]?.intValue == 30)
        #expect(store.storagePolicy.autoCleanupRetentionDays == 30)
    }

    @Test
    func settingsStoreSyncsStorageAutoOverwriteToRecording() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STORAGE_POLICY_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "sd": .object(["online": 1, "status": "normal", "policy_editable": 1]),
                    "tf": .object(["used_gb": 10.0, "total_gb": 64.0]),
                    "maintenance": .object(["format_supported": 1]),
                    "general_policy": .object([
                        "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
                        "locked_event_retention": "forever"
                    ]),
                    "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })
        #expect(store.recordingSettings.autoOverwrite)

        store.updateStoragePolicy(\.autoOverwriteEnabled, to: false)
        #expect(await waitForSessionState { store.storagePolicy.autoOverwriteEnabled == false })
        #expect(store.recordingSettings.autoOverwrite == false)
    }

    @Test
    func settingsStoreRefreshesStorageSourcesAfterSuccessfulFormat() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ??
                makeStatusTopicResponse(request) ??
                makeFileTopicResponse(request) ??
                makeHandshakeResponse(request)
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })
        let baselineCount = transport.sentMessages.count

        store.formatStorageCard()
        #expect(await waitForSessionState {
            let topics = transport.sentMessages.dropFirst(baselineCount).map(\.topic)
            return topics.contains("FORMAT") &&
                topics.contains("SD_STATUS") &&
                topics.contains("TF_CAP") &&
                topics.contains("FILE_LIST")
        })

        let topics = transport.sentMessages.dropFirst(baselineCount).map(\.topic)
        #expect(topics.first == "FORMAT")
        #expect(topics.contains("SD_STATUS"))
        #expect(topics.contains("TF_CAP"))
        #expect(topics.contains("FILE_LIST"))
        #expect(store.storagePolicy.formatStage == .completed)
    }

    @Test
    func settingsStoreMarksFormatFailedWhenDeviceDeclinesFormat() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "FORMAT" {
                return makeTopicResponse(request, parameters: ["frm": 0])
            }
            return makeControlTopicResponse(request) ??
                makeStatusTopicResponse(request) ??
                makeFileTopicResponse(request) ??
                makeHandshakeResponse(request)
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.formatStorageCard()

        #expect(await waitForSessionState {
            store.storagePolicy.formatStage == .failed
        })
    }

    @Test
    func settingsStoreSyncsRecordingAutoOverwriteToStorage() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "RECORDING_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "resolution": .object(["current": "1080P"]),
                    "quality_priority": .object(["current": "balanced"]),
                    "loop_recording": .object(["current": 3, "unit": "min"]),
                    "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
                    "start_behavior": "auto",
                    "audio_recording": 1,
                    "hdr_night_recording": 1,
                    "status_indicator": 1,
                    "recording_reminder": 0
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })
        #expect(store.storagePolicy.autoOverwriteEnabled)

        store.updateRecordingSetting(\.autoOverwrite, to: false)
        #expect(await waitForSessionState { store.recordingSettings.autoOverwrite == false })
        #expect(store.storagePolicy.autoOverwriteEnabled == false)
    }

    @Test
    func settingsStoreUsesDeviceStorageUsagePercent() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "storage",
                    "sections": .object([
                        "storage": .object([
                            "sd": .object([
                                "status": "normal",
                                "format_required": 0,
                                "policy_editable": 1
                            ]),
                            "tf": .object([
                                "used_gb": 10.0,
                                "total_gb": 100.0,
                                "usage_percent": 58
                            ]),
                            "maintenance": .object(["format_supported": 1]),
                            "general_policy": .object([
                                "auto_overwrite": 1,
                                "locked_event_retention": "forever"
                            ]),
                            "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.storagePolicy)
        #expect(await waitForSessionState { store.storagePolicy.totalSpaceGB == 100.0 })
        #expect(store.storagePolicy.usageProgress == 0.58)
    }

    @Test
    func settingsStoreFallsBackWhenStorageStateSyncHasInvalidUsagePercent() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "storage",
                    "sections": .object([
                        "storage": .object([
                            "sd": .object([
                                "online": 1,
                                "status": "normal",
                                "format_required": 0,
                                "policy_editable": 1
                            ]),
                            "tf": .object([
                                "used_gb": 10.0,
                                "total_gb": 100.0,
                                "usage_percent": true
                            ]),
                            "maintenance": .object(["format_supported": 1]),
                            "general_policy": .object([
                                "auto_overwrite": 1,
                                "locked_event_retention": "forever"
                            ]),
                            "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                        ])
                    ])
                ])
            case "STORAGE_POLICY_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "sd": .object([
                        "online": 1,
                        "status": "normal",
                        "format_required": 0,
                        "policy_editable": 1
                    ]),
                    "tf": .object([
                        "used_gb": 58.0,
                        "total_gb": 100.0,
                        "usage_percent": 58
                    ]),
                    "maintenance": .object(["format_supported": 1]),
                    "general_policy": .object([
                        "auto_overwrite": 1,
                        "locked_event_retention": "forever"
                    ]),
                    "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.storagePolicy)
        #expect(await waitForSessionState {
            transport.sentMessages.contains { $0.topic == "STORAGE_POLICY_CONFIG" }
        })
        #expect(store.storagePolicy.usageProgress == 0.58)
    }

    @Test
    func settingsStoreUsesStorageOnlineFlagForMissingCard() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "storage",
                    "sections": .object([
                        "storage": .object([
                            "sd": .object([
                                "online": 0,
                                "format_required": 0,
                                "policy_editable": 0
                            ]),
                            "tf": .object([
                                "used_gb": 0.0,
                                "total_gb": 0.0,
                                "usage_percent": 0
                            ]),
                            "maintenance": .object(["format_supported": 0]),
                            "general_policy": .object([
                                "auto_overwrite": 0,
                                "locked_event_retention": "forever"
                            ]),
                            "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.storagePolicy)
        #expect(await waitForSessionState { store.storagePolicy.totalSpaceGB == 0.0 })
        #expect(store.storagePolicy.cardStatus == .noCard)
    }

    @Test
    func settingsStoreMapsStorageErrorCodeToLocalDescription() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "storage",
                    "sections": .object([
                        "storage": .object([
                            "sd": .object([
                                "online": 1,
                                "status": "error",
                                "error_code": "unsupported_card",
                                "error_message": "vendor raw unsupported card diagnostic",
                                "format_required": 0,
                                "policy_editable": 0
                            ]),
                            "tf": .object([
                                "used_gb": 0.0,
                                "total_gb": 0.0,
                                "usage_percent": 0
                            ]),
                            "maintenance": .object(["format_supported": 1]),
                            "general_policy": .object([
                                "auto_overwrite": 0,
                                "locked_event_retention": "forever"
                            ]),
                            "storage_allocation": .object(["reserved_space_for_events_percent": 20])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.storagePolicy)
        #expect(await waitForSessionState { store.storagePolicy.cardStatus == .error })
        let loadedFields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: store.storagePolicy).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        #expect(loadedFields["cardErrorDescription"] as? String == "The inserted SD card is not supported by this camera. Use a compatible card before recording.")
        #expect(loadedFields["cardErrorDescription"] as? String != "vendor raw unsupported card diagnostic")
    }

    @Test
    func settingsStorePreservesLoadedWatermarkPositionWhenSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "watermark",
                    "sections": .object([
                        "watermark": .object([
                            "time_enabled": 1,
                            "plate_enabled": 1,
                            "plate_number": "DOCS123",
                            "position": "top_left"
                        ])
                    ])
                ])
            case "WATERMARK_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "time_enabled": request.parameters["time_enabled"] ?? 1,
                    "plate_enabled": request.parameters["plate_enabled"] ?? 1,
                    "plate_number": request.parameters["plate_number"] ?? "DOCS123",
                    "position": request.parameters["position"] ?? "bottom_right"
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.show(.watermarkConfiguration)
        #expect(await waitForSessionState {
            store.watermarkConfiguration.licensePlate == "DOCS123"
        })

        store.saveWatermarkConfiguration()
        #expect(await waitForSessionState {
            transport.sentMessages.contains {
                $0.topic == "WATERMARK_CONFIG" && $0.operation == .post
            }
        })

        let watermarkPost = transport.sentMessages.last {
            $0.topic == "WATERMARK_CONFIG" && $0.operation == .post
        }
        #expect(watermarkPost?.parameters["position"]?.stringValue == "top_left")
    }

    @Test
    func settingsStoreLimitsWatermarkPlateNumberBeforeSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "WATERMARK_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "time_enabled": request.parameters["time_enabled"] ?? 1,
                    "plate_enabled": request.parameters["plate_enabled"] ?? 1,
                    "plate_number": request.parameters["plate_number"] ?? "",
                    "position": request.parameters["position"] ?? "bottom_right"
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.updateWatermarkConfiguration(\.licensePlate, to: "ABCDEFGH999")
        store.saveWatermarkConfiguration()

        #expect(await waitForSessionState {
            transport.sentMessages.contains {
                $0.topic == "WATERMARK_CONFIG" && $0.operation == .post
            }
        })
        let watermarkPost = transport.sentMessages.last {
            $0.topic == "WATERMARK_CONFIG" && $0.operation == .post
        }
        #expect(store.watermarkConfiguration.licensePlate == "ABCDEFGH")
        #expect(watermarkPost?.parameters["plate_number"]?.stringValue == "ABCDEFGH")
    }

    @Test
    func settingsStoreTrimsWatermarkPlateNumberBeforeSaving() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "WATERMARK_CONFIG":
                return makeTopicResponse(request, parameters: [
                    "time_enabled": request.parameters["time_enabled"] ?? 1,
                    "plate_enabled": request.parameters["plate_enabled"] ?? 1,
                    "plate_number": request.parameters["plate_number"] ?? "",
                    "position": request.parameters["position"] ?? "bottom_right"
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.updateWatermarkConfiguration(\.licensePlate, to: "  ABC123  ")
        store.saveWatermarkConfiguration()

        #expect(await waitForSessionState {
            transport.sentMessages.contains {
                $0.topic == "WATERMARK_CONFIG" && $0.operation == .post
            }
        })
        let watermarkPost = transport.sentMessages.last {
            $0.topic == "WATERMARK_CONFIG" && $0.operation == .post
        }
        #expect(store.watermarkConfiguration.licensePlate == "ABC123")
        #expect(watermarkPost?.parameters["plate_number"]?.stringValue == "ABC123")
    }

    @Test
    func statisticsStoreLoadsStatisticsStateSyncAndDeviceInfo() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "statistics",
                    "sections": .object([
                        "statistics": .object([
                            "storage_counts": .object([
                                "video_count": 3,
                                "photo_count": 1
                            ]),
                            "locked_counts": .object([
                                "video_locked": 1,
                                "photo_locked": 0
                            ]),
                            "device_totals": .object([
                                "total_size": 1_628_379_167,
                                "total_duration_sec": 3_600,
                                "usage_days": 12
                            ])
                        ])
                    ])
                ])
            case "DEVICE_INFO":
                return makeDeviceInfoTopicResponse(request)
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = StatisticsStore(deviceSession: session)

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.refresh()

        #expect(await waitForSessionState {
            store.statistics.videoCount == 3 &&
                store.statistics.photoCount == 1 &&
                store.statistics.lockedVideoCount == 1 &&
                store.statistics.totalSizeBytes == 1_628_379_167 &&
                store.deviceInfo.model == "C360-X1" &&
                store.deviceInfo.firmwareVersion == "v1.0.1"
        })
        let topics = transport.sentMessages.map(\.topic).filter {
            $0 == "STATE_SYNC" || $0 == "DEVICE_INFO"
        }
        #expect(topics == ["STATE_SYNC", "DEVICE_INFO"])
        #expect(transport.sentMessages.first { $0.topic == "STATE_SYNC" }?.parameters["scope"]?.stringValue == "statistics")
    }

    @Test
    func initialStateCoordinatorAppliesInitialStateSyncToFeatureStores() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "initial",
                    "sections": .object([
                        "home": .object([
                            "device": .object([
                                "date_value": "20260515103056"
                            ]),
                            "preview": .object([
                                "recording_status": 1,
                                "stream_source_type": "rtsp_pending_protocol"
                            ]),
                            "storage_summary": .object([
                                "left_mb": 4_000,
                                "total_mb": 22_222,
                                "usage_percent": 82.0
                            ]),
                            "recent_events": .array([])
                        ]),
                        "settings_home": .object([
                            "device_info": .object([
                                "device_name": "Initial Sync Camera",
                                "model": "C360-X1",
                                "serial_no": "C360X1202605140001",
                                "fw_version": "v1.2.3"
                            ]),
                            "categories": .array([
                                .object(["key": "recording", "supported": 1]),
                                .object(["key": "storage", "supported": 0])
                            ])
                        ]),
                        "statistics": .object([
                            "storage_counts": .object([
                                "video_count": 6,
                                "photo_count": 2
                            ]),
                            "locked_counts": .object([
                                "video_locked": 3,
                                "photo_locked": 1
                            ]),
                            "device_totals": .object([
                                "total_size": 2_048_000,
                                "total_duration_sec": 540,
                                "usage_days": 5
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        repository.store([makeKnownDevice(id: "112233445566778899", name: "Road Camera")])
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let recordingStore = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        let settingsStore = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        let statisticsStore = StatisticsStore(deviceSession: session)
        let coordinator = DeviceInitialStateCoordinator(
            deviceSession: session,
            recordingStore: recordingStore,
            settingsStore: settingsStore,
            statisticsStore: statisticsStore
        )

        startHandshake(session)

        #expect(await waitForSessionState(timeout: 3) {
            guard case .available(let summary) = recordingStore.storageState else {
                return false
            }

            return coordinator.didApplySnapshot &&
                recordingStore.previewState.statusTitle == "REC" &&
                summary.usageFraction == 0.82 &&
                settingsStore.devicePreferences.deviceName == "Initial Sync Camera" &&
                settingsStore.devicePreferences.firmwareVersion == "v1.2.3" &&
                settingsStore.isSettingsHomeCategorySupported(.storage) == false &&
                statisticsStore.statistics.videoCount == 6 &&
                statisticsStore.statistics.lockedVideoCount == 3 &&
                statisticsStore.deviceInfo.model == "C360-X1"
        })

        let initialStateSyncCount = transport.sentMessages.filter {
            $0.topic == "STATE_SYNC" && $0.parameters["scope"]?.stringValue == "initial"
        }.count
        #expect(initialStateSyncCount == 1)
    }

    @Test
    func initialStateCoordinatorFetchesOmittedStateSyncSections() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                switch request.parameters["scope"]?.stringValue {
                case "initial":
                    return makeTopicResponse(request, parameters: [
                        "scope": "initial",
                        "truncated": 1,
                        "omitted_sections": ["home", "settings_home", "statistics"],
                        "sections": .object([:])
                    ])
                case "home":
                    return makeTopicResponse(request, parameters: [
                        "scope": "home",
                        "sections": .object([
                            "home": .object([
                                "device": .object(["date_value": "20260515103056"]),
                                "preview": .object([
                                    "recording_status": 1,
                                    "stream_source_type": "rtsp_pending_protocol"
                                ]),
                                "storage_summary": .object([
                                    "left_mb": 4_000,
                                    "total_mb": 22_222,
                                    "usage_percent": 82.0
                                ]),
                                "recent_events": .array([])
                            ])
                        ])
                    ])
                case "settings_home":
                    return makeTopicResponse(request, parameters: [
                        "scope": "settings_home",
                        "sections": .object([
                            "settings_home": .object([
                                "device_info": .object([
                                    "device_name": "Omitted Sync Camera",
                                    "model": "C360-X1",
                                    "serial_no": "C360X1202605140001",
                                    "fw_version": "v1.2.4"
                                ]),
                                "categories": .array([
                                    .object(["key": "recording", "supported": 0])
                                ])
                            ])
                        ])
                    ])
                case "statistics":
                    return makeTopicResponse(request, parameters: [
                        "scope": "statistics",
                        "sections": .object([
                            "statistics": .object([
                                "storage_counts": .object([
                                    "video_count": 8,
                                    "photo_count": 3
                                ]),
                                "locked_counts": .object([
                                    "video_locked": 2,
                                    "photo_locked": 1
                                ]),
                                "device_totals": .object([
                                    "total_size": 4_096_000,
                                    "total_duration_sec": 900,
                                    "usage_days": 6
                                ])
                            ])
                        ])
                    ])
                default:
                    return makeTopicResponse(request, parameters: [
                        "scope": request.parameters["scope"] ?? "initial",
                        "sections": .object([:])
                    ])
                }
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        repository.store([makeKnownDevice(id: "112233445566778899", name: "Road Camera")])
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let recordingStore = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        let settingsStore = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        let statisticsStore = StatisticsStore(deviceSession: session)
        let coordinator = DeviceInitialStateCoordinator(
            deviceSession: session,
            recordingStore: recordingStore,
            settingsStore: settingsStore,
            statisticsStore: statisticsStore
        )

        startHandshake(session)

        let didLoadOmittedSections = await waitForSessionState(timeout: 3) {
            guard case .available(let summary) = recordingStore.storageState else {
                return false
            }

            return recordingStore.previewState.statusTitle == "REC" &&
                summary.usageFraction == 0.82 &&
                settingsStore.devicePreferences.deviceName == "Omitted Sync Camera" &&
                settingsStore.isSettingsHomeCategorySupported(.recording) == false &&
                statisticsStore.statistics.videoCount == 8 &&
                statisticsStore.deviceInfo.firmwareVersion == "v1.2.4" &&
                coordinator.didApplySnapshot
        }
        #expect(didLoadOmittedSections)
        if case .available(let summary) = recordingStore.storageState {
            #expect(recordingStore.previewState.statusTitle == "REC")
            #expect(summary.usageFraction == 0.82)
        } else {
            #expect(Bool(false))
        }
        #expect(settingsStore.devicePreferences.deviceName == "Omitted Sync Camera")
        #expect(settingsStore.isSettingsHomeCategorySupported(.recording) == false)
        #expect(statisticsStore.statistics.videoCount == 8)
        #expect(statisticsStore.deviceInfo.firmwareVersion == "v1.2.4")
        #expect(coordinator.didApplySnapshot)

        let stateSyncScopes = transport.sentMessages.compactMap { message in
            message.topic == "STATE_SYNC" ? message.parameters["scope"]?.stringValue : nil
        }
        #expect(stateSyncScopes.contains("initial"))
        #expect(stateSyncScopes.contains("home"))
        #expect(stateSyncScopes.contains("settings_home"))
        #expect(stateSyncScopes.contains("statistics"))
    }

    @Test
    func initialStateCoordinatorRefreshesInitialStateAfterRecoveryHandshake() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        var initialSyncCount = 0
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                if request.parameters["scope"]?.stringValue == "initial" {
                    initialSyncCount += 1
                }

                let deviceName = initialSyncCount >= 2 ? "Recovered Sync Camera" : "Initial Sync Camera"
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "initial",
                    "sections": .object([
                        "settings_home": .object([
                            "device_info": .object([
                                "device_name": .string(deviceName),
                                "model": "C360-X1",
                                "serial_no": "C360X1202605140001",
                                "fw_version": "v1.2.3"
                            ]),
                            "categories": .array([
                                .object(["key": "recording", "supported": 1])
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        repository.store([makeKnownDevice(id: "112233445566778899", name: "Road Camera")])
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let recordingStore = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        let settingsStore = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )
        let statisticsStore = StatisticsStore(deviceSession: session)
        let coordinator = DeviceInitialStateCoordinator(
            deviceSession: session,
            recordingStore: recordingStore,
            settingsStore: settingsStore,
            statisticsStore: statisticsStore
        )

        startHandshake(session)

        #expect(await waitForSessionState(timeout: 3) {
            coordinator.didApplySnapshot &&
                settingsStore.devicePreferences.deviceName == "Initial Sync Camera"
        })

        transport.pushDisconnect()
        #expect(await waitForSessionState { failedError(from: session.state) == .connectionLost })
        session.send(.startRecovery)
        session.send(.recoverySucceeded)

        #expect(await waitForSessionState(timeout: 3) {
            settingsStore.devicePreferences.deviceName == "Recovered Sync Camera"
        })

        let initialStateSyncCount = transport.sentMessages.filter {
            $0.topic == "STATE_SYNC" && $0.parameters["scope"]?.stringValue == "initial"
        }.count
        #expect(initialStateSyncCount == 2)
    }

    @Test
    func settingsStoreFetchesSettingsHomeStateSyncWhenPreparingDeviceSettings() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "settings_home",
                    "sections": .object([
                        "settings_home": .object([
                            "device_info": .object([
                                "device_name": "Docs Settings Camera",
                                "model": "C360-X1",
                                "serial_no": "C360X1202605140001",
                                "uuid": "112233445566778899",
                                "fw_version": "v1.2.3",
                                "protocol_version": "1.2"
                            ]),
                            "categories": .array([
                                .object(["key": "recording", "supported": 1]),
                                .object(["key": "storage", "supported": 0])
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.prepareDeviceSettings(for: nil)

        #expect(await waitForSessionState {
            store.devicePreferences.deviceName == "Docs Settings Camera" &&
                store.devicePreferences.firmwareVersion == "v1.2.3"
        })
        let stateSyncMessages = transport.sentMessages.filter { $0.topic == "STATE_SYNC" }
        #expect(stateSyncMessages.count == 1)
        #expect(stateSyncMessages.first?.parameters["scope"]?.stringValue == "settings_home")

        store.show(.recordingSettings)
        #expect(store.route == .recordingSettings)
        store.dismissRoute()

        store.show(.storagePolicy)
        #expect(store.route == nil)
    }

    @Test
    func settingsStoreFetchesWifiStateSyncWhenPreparingNetworkIdentity() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "wifi",
                    "sections": .object([
                        "wifi": .object([
                            "ssid": "Docs_WiFi_AP",
                            "status": 1
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.prepareNetworkIdentity()

        #expect(await waitForSessionState(timeout: 3) { store.networkIdentity.networkName == "Docs_WiFi_AP" })
        #expect(store.devicePreferences.connectionName == "Docs_WiFi_AP")
        #expect(store.networkIdentity.statusCode == 1)
        let networkTopics = transport.sentMessages.map(\.topic).filter {
            $0 == "STATE_SYNC" || $0 == "AP_SSID_INFO"
        }
        #expect(networkTopics == ["STATE_SYNC"])
        #expect(transport.sentMessages.last?.parameters["scope"]?.stringValue == "wifi")
    }

    @Test
    func settingsStoreRejectsInvalidWifiPasswordBeforePostingAccessPointIdentity() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.updateNetworkIdentity(\.networkName, to: "Docs_WiFi_AP")
        store.updateNetworkIdentity(\.password, to: "short")
        store.commitNetworkIdentityChanges()

        try? await Task.sleep(nanoseconds: 100_000_000)
        let networkTopics = transport.sentMessages.map(\.topic).filter { $0 == "AP_SSID_INFO" }
        #expect(networkTopics.isEmpty)
        #expect(store.devicePreferences.connectionName != "Docs_WiFi_AP")
    }

    @Test
    func settingsStoreDisconnectsSessionAfterSuccessfulWifiIdentityChange() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = SettingsStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        store.updateNetworkIdentity(\.networkName, to: "Docs_WiFi_AP")
        store.updateNetworkIdentity(\.password, to: "12345678")
        #expect(store.commitNetworkIdentityChanges())

        #expect(await waitForSessionState {
            transport.sentMessages.contains {
                $0.topic == "AP_SSID_INFO" && $0.operation == .post
            }
        })
        #expect(await waitForSessionState { session.state == .disconnected })
        #expect(await waitForSessionState {
            transport.sentMessages.contains { $0.topic == "CTP_CMD_EXITAPP" }
        })
        #expect(transport.disconnectCount == 1)
    }

    @Test
    func apConnectionFailedMovesSessionToFailed() async {
        let session = DeviceSession()
        session.send(.startAPConnection(ssid: "Cam360_AP"))
        #expect(session.state == .apConnecting)

        session.send(.apConnectionFailed(reason: "Wi-Fi not found"))

        #expect(failedError(from: session.state) == .apConnectionFailed(reason: "Wi-Fi not found"))
    }

    @Test
    func operationFailedMovesSessionToFailed() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        session.send(.startOperation(.livePreview))
        #expect(session.state == .busy(operation: .livePreview, deviceInfo: makeTestDeviceInfo()))

        session.send(.operationFailed(.timeout))

        #expect(failedError(from: session.state) == .timeout)
    }

    @Test
    func recoveryFailedMovesSessionToFailed() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        transport.pushDisconnect()
        #expect(await waitForSessionState { failedError(from: session.state) == .connectionLost })

        session.send(.startRecovery)
        if case .recovering = session.state {} else {
            #expect(Bool(false))
        }

        session.send(.recoveryFailed(.timeout))

        #expect(failedError(from: session.state) == .timeout)
    }

    @Test
    func recoverySucceededRestartsProtocolHandshake() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })
        let appAccessCountBeforeRecovery = transport.sentMessages.filter { $0.topic == "APP_ACCESS" }.count

        transport.pushDisconnect()
        #expect(await waitForSessionState { failedError(from: session.state) == .connectionLost })
        session.send(.startRecovery)
        if case .recovering = session.state {} else {
            #expect(Bool(false))
        }

        session.send(.recoverySucceeded)

        #expect(await waitForSessionState { session.state.isConnected })
        let appAccessCountAfterRecovery = transport.sentMessages.filter { $0.topic == "APP_ACCESS" }.count
        #expect(appAccessCountAfterRecovery == appAccessCountBeforeRecovery + 1)
    }

    @Test
    func playbackStoreLoadsFirstPlaybackResourceWhenSessionBecomesReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeFileTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        let store = PlaybackStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.playbackResource != nil })
        #expect(store.title == "REC00001.AVI")
        #expect(store.selectedFileInfo?.path == "/DCIMA/REC00001.AVI")
        #expect(store.playbackResource?.rtspURL == "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI")
        #expect(store.message == "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI · Transport TCP · Auth digest · 1 session · seek 1000ms · keepalive 20s · 180s")
        #expect(store.lastLoadError == nil)
        #expect(store.isLoading == false)
        #expect(Array(transport.sentMessages.map(\.topic).suffix(3)) == [
            "FILE_LIST",
            "FILE_INFO",
            "FILE_DOWNLOAD_URL"
        ])
    }

    @Test
    func playbackStoreIgnoresStalePlaybackResourceAfterDisconnect() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            if request.topic == "FILE_DOWNLOAD_URL" {
                return nil
            }
            return makeFileTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        let store = PlaybackStore(deviceSession: session)

        startHandshake(session)
        #expect(await waitForSessionState { transport.sentMessages.last?.topic == "FILE_DOWNLOAD_URL" })
        guard let request = transport.sentMessages.last,
              let staleResponse = makeFileTopicResponse(request) else {
            #expect(Bool(false))
            return
        }

        session.send(.disconnect)
        transport.push(staleResponse)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(store.playbackResource == nil)
        #expect(store.selectedFileInfo == nil)
        #expect(store.lastLoadError == nil)
        #expect(store.isLoading == false)
        #expect(store.message == "当前没有可显示的设备录像或本地媒体。")
    }

    @Test
    func eventsStoreLoadsMediaIndexEventsWhenSessionBecomesReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeAggregateTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        let store = EventsStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.recentEvents.isEmpty == false })
        #expect(store.recentEvents.first?.title == "Collision Detected")
        #expect(store.recentEvents.first?.titleKey == "event.collision_detected")
        #expect(store.recentEvents.first?.size == 712_345_678)
        #expect(store.recentEvents.first?.thumbReady == true)
        #expect(store.feedState == .available)
        let mediaIndexRequest = transport.sentMessages.last { $0.topic == "MEDIA_INDEX" }
        #expect(mediaIndexRequest?.parameters["event_only"]?.intValue == 1)
        #expect(mediaIndexRequest?.parameters["page_size"]?.intValue == 20)
        #expect(transport.sentMessages.contains { $0.topic == "RECENT_EVENTS" } == false)
    }

    @Test
    func eventsStoreFiltersMediaIndexEventsBySelectedFilter() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "MEDIA_INDEX":
                return makeTopicResponse(request, parameters: [
                    "filters": .object(request.parameters),
                    "summary": .object(["total_count": 3, "event_count": 3, "locked_count": 1]),
                    "groups": .array([
                        .object([
                            "group_key": "2023-06-10",
                            "items": .array([
                                makeMediaIndexItemObject(),
                                .object([
                                    "path": "/DCIMA/REC00002.AVI",
                                    "name": "REC00002.AVI",
                                    "media_type": "video",
                                    "event_type": "parking",
                                    "title_key": "event.parking_incident",
                                    "title": "Parking Incident",
                                    "start_time": "2023-06-10 20:15:12",
                                    "duration_sec": 20,
                                    "locked": 1,
                                    "thumb_ready": 1
                                ]),
                                .object([
                                    "path": "/DCIMA/REC00003.AVI",
                                    "name": "REC00003.AVI",
                                    "media_type": "video",
                                    "event_type": "manual",
                                    "title_key": "event.manual_save",
                                    "title": "Manual Save",
                                    "start_time": "2023-06-10 21:15:12",
                                    "duration_sec": 10,
                                    "locked": 0,
                                    "thumb_ready": 0
                                ])
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = EventsStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.recentEvents.count == 3 })
        #expect(store.visibleEvents.map(\.eventType) == ["impact", "parking", "manual"])

        store.selectedFilter = .parking

        #expect(store.visibleEvents.map(\.eventType) == ["parking"])
    }

    @Test
    func recordingStoreUsesHomeStateSyncRecentEventsWhenSessionBecomesReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "home",
                    "sections": .object([
                        "home": .object([
                            "recent_events": .array([
                                .object([
                                    "event_id": "home-event-1",
                                    "path": "/DCIMA/PARKING0001.AVI",
                                    "media_type": "video",
                                    "event_type": "parking",
                                    "title": "Parking Incident",
                                    "start_time": "2026-05-29 09:15:00",
                                    "duration_sec": 45,
                                    "locked": 1
                                ])
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        repository.store([makeKnownDevice(id: "112233445566778899", name: "Road Camera")])
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)

        #expect(await waitForSessionState { store.recentEvents.first?.title == "Parking Incident" })
        let aggregateTopics = transport.sentMessages.map(\.topic).filter {
            $0 == "STATE_SYNC" || $0 == "RECENT_EVENTS"
        }
        #expect(aggregateTopics == ["STATE_SYNC"])
    }

    @Test
    func recordingStoreConsumesHomeStateSyncPreviewAndStorageSummary() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "home",
                    "sections": .object([
                        "home": .object([
                            "device": .object([
                                "date_value": "20260515103056"
                            ]),
                            "preview": .object([
                                "entry_enabled": 1,
                                "recording_status": 1,
                                "stream_source_type": "rtsp_pending_protocol"
                            ]),
                            "storage_summary": .object([
                                "left_mb": 4_000,
                                "total_mb": 22_222,
                                "usage_percent": 82.0
                            ]),
                            "recent_events": .array([])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        repository.store([makeKnownDevice(id: "112233445566778899", name: "Road Camera")])
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)

        #expect(await waitForSessionState {
            guard case .available(let summary) = store.storageState else {
                return false
            }

            return store.previewState == RecordingPreviewState(
                statusTitle: "REC",
                resolutionTitle: "RTSP pending",
                timestampText: "2026-05-15 10:30:56"
            ) &&
            summary.usedCapacityText == "17.8 GB" &&
            summary.totalCapacityText == "21.7 GB" &&
            summary.usageFraction == 0.82
        })
    }

    @Test
    func recordingStoreReducesRecentEventsLimitWhenDeviceReportsResourceLimit() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "STATE_SYNC":
                return makeTopicResponse(request, parameters: [
                    "scope": request.parameters["scope"] ?? "home",
                    "sections": .object(["home": .object([:])])
                ])
            case "RECENT_EVENTS":
                let limit = request.parameters["limit"]?.intValue ?? 4
                if limit > 2 {
                    return makeTopicResponse(request, parameters: [:], errno: -7)
                }

                let items = (0..<limit).map { index in
                    DeviceProtocolValue.object([
                        "event_id": .string("evt-\(index)"),
                        "path": .string("/DCIMA/REC0000\(index).AVI"),
                        "media_type": .string("video"),
                        "event_type": .string(index == 0 ? "impact" : "motion"),
                        "title_key": .string(index == 0 ? "event.collision_detected" : "event.motion_detected"),
                        "title": .string(index == 0 ? "Collision Detected" : "Motion Detected"),
                        "start_time": .string("2026-05-29 09:1\(index):00"),
                        "duration_sec": .int(30),
                        "locked": .int(index == 0 ? 1 : 0)
                    ])
                }

                return makeTopicResponse(request, parameters: [
                    "limit": .int(limit),
                    "total_recent_count": .int(4),
                    "items": .array(items)
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let defaults = UserDefaults.ephemeral
        let repository = UserDefaultsKnownDeviceRepository(userDefaults: defaults)
        repository.store([makeKnownDevice(id: "112233445566778899", name: "Road Camera")])
        let preferenceStore = UserDefaultsAppPreferenceStore(userDefaults: defaults)
        let store = RecordingStore(
            knownDeviceRepository: repository,
            appPreferenceStore: preferenceStore,
            deviceSession: session
        )

        startHandshake(session)

        #expect(await waitForSessionState { store.deviceRecentEvents.count == 2 })
        let recentEventLimits = transport.sentMessages
            .filter { $0.topic == "RECENT_EVENTS" }
            .compactMap { $0.parameters["limit"]?.intValue }
        #expect(recentEventLimits == [4, 2])
        #expect(store.recentEvents.map(\.title) == ["Collision Detected", "Motion Detected"])
    }

    @Test
    func galleryStoreLoadsMediaIndexWhenSessionBecomesReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeAggregateTopicResponse(request) ?? makeFileTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        let store = GalleryStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.items.isEmpty == false })
        #expect(store.items.first?.title == "Collision Detected")
        #expect(store.items.first?.kind == .event)
        #expect(await waitForSessionState { store.items.first?.thumbnailImageBase64 == validTestThumbnailBase64 })
        #expect(transport.sentMessages.contains { $0.topic == "MEDIA_INDEX" })
        #expect(transport.sentMessages.contains { $0.topic == "THUMB_LIST" })
    }

    @Test
    func galleryStoreLoadsVideoAndPhotoMediaIndexesWhenSessionBecomesReady() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "MEDIA_INDEX":
                let mediaType = request.parameters["media_type"]?.stringValue ?? "video"
                let item: DeviceProtocolValue
                if mediaType == "photo" {
                    item = .object([
                        "path": "/DCIMA/IMG00004.JPG",
                        "name": "IMG00004.JPG",
                        "media_type": "photo",
                        "event_type": "photo",
                        "title_key": "event.photo",
                        "start_time": "2023-06-10 19:45:30",
                        "duration_sec": 0,
                        "thumb_ready": 0,
                        "locked": 0
                    ])
                } else {
                    item = .object([
                        "path": "/DCIMA/REC00001.AVI",
                        "name": "REC00001.AVI",
                        "media_type": "video",
                        "event_type": "normal",
                        "title_key": "event.normal_recording",
                        "start_time": "2023-06-10 19:15:12",
                        "duration_sec": 30,
                        "thumb_ready": 0,
                        "locked": 0
                    ])
                }

                return makeTopicResponse(request, parameters: [
                    "filters": .object(request.parameters),
                    "summary": .object(["total_count": 1, "event_count": 0, "locked_count": 0]),
                    "groups": .array([
                        .object([
                            "group_key": "2023-06-10",
                            "items": .array([item])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = GalleryStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.items.count == 2 })
        let mediaIndexTypes = transport.sentMessages
            .filter { $0.topic == "MEDIA_INDEX" }
            .compactMap { $0.parameters["media_type"]?.stringValue }
        #expect(mediaIndexTypes == ["video", "photo"])
        store.selectFilter(.videos)
        #expect(store.visibleSections.first?.items.first?.title == "Normal Recording")
        store.selectFilter(.photos)
        #expect(store.visibleSections.first?.items.first?.title == "Photo")
    }

    @Test
    func galleryStoreBatchesThumbnailListRequestsAtProtocolLimit() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "MEDIA_INDEX":
                let mediaType = request.parameters["media_type"]?.stringValue ?? "video"
                let fileExtension = mediaType == "photo" ? "JPG" : "AVI"
                let itemCount = mediaType == "photo" ? 5 : 20
                let items = (0..<itemCount).map { index in
                    DeviceProtocolValue.object([
                        "path": .string("/DCIMA/\(mediaType.uppercased())\(index).\(fileExtension)"),
                        "name": .string("\(mediaType.uppercased())\(index).\(fileExtension)"),
                        "media_type": .string(mediaType),
                        "event_type": .string(mediaType == "photo" ? "photo" : "normal"),
                        "title_key": .string(mediaType == "photo" ? "event.photo" : "event.normal_recording"),
                        "start_time": .string("2023-06-10 19:15:12"),
                        "duration_sec": .int(mediaType == "photo" ? 0 : 30),
                        "thumb_ready": .int(1),
                        "locked": .int(0)
                    ])
                }

                return makeTopicResponse(request, parameters: [
                    "filters": .object(request.parameters),
                    "summary": .object(["total_count": .int(itemCount), "event_count": 0, "locked_count": 0]),
                    "groups": .array([
                        .object([
                            "group_key": "2023-06-10",
                            "items": .array(items)
                        ])
                    ])
                ])
            case "THUMB_LIST":
                let paths = request.parameters["paths"]?.arrayValue?.compactMap(\.stringValue) ?? []
                return makeTopicResponse(request, parameters: [
                    "thumbs": .array(paths.map { path in
                        .object([
                            "path": .string(path),
                            "format": .string("JPEG"),
                            "width": .int(320),
                            "height": .int(180),
                            "size": .int(4),
                            "image_base64": .string(validTestThumbnailBase64)
                        ])
                    })
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = GalleryStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.thumbnailsByPath.count == 25 })
        let thumbnailPathBatches = transport.sentMessages
            .filter { $0.topic == "THUMB_LIST" }
            .map { $0.parameters["paths"]?.arrayValue?.compactMap(\.stringValue) ?? [] }
        #expect(thumbnailPathBatches.map(\.count) == [20, 5])
        #expect(thumbnailPathBatches.allSatisfy { $0.count <= 20 })
    }

    @Test
    func galleryStoreReducesThumbnailListBatchWhenDeviceReportsResourceLimit() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "MEDIA_INDEX":
                let mediaType = request.parameters["media_type"]?.stringValue ?? "video"
                let itemCount = mediaType == "video" ? 20 : 0
                let items = (0..<itemCount).map { index in
                    DeviceProtocolValue.object([
                        "path": .string("/DCIMA/REC\(index).AVI"),
                        "name": .string("REC\(index).AVI"),
                        "media_type": .string("video"),
                        "event_type": .string("normal"),
                        "title_key": .string("event.normal_recording"),
                        "start_time": .string("2023-06-10 19:15:12"),
                        "duration_sec": .int(30),
                        "thumb_ready": .int(1),
                        "locked": .int(0)
                    ])
                }

                return makeTopicResponse(request, parameters: [
                    "filters": .object(request.parameters),
                    "summary": .object(["total_count": .int(itemCount), "event_count": 0, "locked_count": 0]),
                    "groups": .array([
                        .object([
                            "group_key": "2023-06-10",
                            "items": .array(items)
                        ])
                    ])
                ])
            case "THUMB_LIST":
                let paths = request.parameters["paths"]?.arrayValue?.compactMap(\.stringValue) ?? []
                if paths.count > 10 {
                    return makeTopicResponse(request, parameters: [:], errno: -7)
                }

                return makeTopicResponse(request, parameters: [
                    "thumbs": .array(paths.map { path in
                        .object([
                            "path": .string(path),
                            "format": .string("JPEG"),
                            "width": .int(320),
                            "height": .int(180),
                            "size": .int(4),
                            "image_base64": .string(validTestThumbnailBase64)
                        ])
                    })
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = GalleryStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.thumbnailsByPath.count == 20 })
        let thumbnailPathBatches = transport.sentMessages
            .filter { $0.topic == "THUMB_LIST" }
            .map { $0.parameters["paths"]?.arrayValue?.compactMap(\.stringValue) ?? [] }
        #expect(thumbnailPathBatches.map(\.count) == [20, 10, 10])
    }

    @Test
    func galleryStoreTreatsMediaIndexPhotoItemsAsPhotos() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "MEDIA_INDEX":
                return makeTopicResponse(request, parameters: [
                    "filters": .object(request.parameters),
                    "summary": .object(["total_count": 1, "event_count": 0, "locked_count": 0]),
                    "groups": .array([
                        .object([
                            "group_key": "2023-06-10",
                            "items": .array([
                                .object([
                                    "path": "/DCIMA/SNAP0001.JPG",
                                    "name": "SNAP0001.JPG",
                                    "media_type": "photo",
                                    "event_type": "photo",
                                    "title_key": "event.photo",
                                    "start_time": "2023-06-10 19:20:12",
                                    "duration_sec": 0,
                                    "thumb_ready": 0,
                                    "locked": 0
                                ])
                            ])
                        ])
                    ])
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = GalleryStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState { store.items.count == 1 })
        #expect(store.items.first?.title == "Photo")
        #expect(store.items.first?.kind == .photo)
        #expect(store.items.first?.thumbnailSymbol == "camera.fill")
        store.selectFilter(.photos)
        #expect(store.visibleSections.first?.items.first?.kind == .photo)
        store.selectFilter(.events)
        #expect(store.visibleSections.isEmpty)
    }

    @Test
    func galleryStoreFallsBackToThumbGetWhenThumbListOmitsReadyItem() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            switch request.topic {
            case "MEDIA_INDEX":
                return makeTopicResponse(request, parameters: [
                    "filters": .object(request.parameters),
                    "summary": .object(["total_count": 2, "event_count": 1, "locked_count": 1]),
                    "groups": .array([
                        .object([
                            "group_key": "2023-06-10",
                            "items": .array([
                                makeMediaIndexItemObject(),
                                .object([
                                    "path": "/DCIMA/REC00002.AVI",
                                    "name": "REC00002.AVI",
                                    "media_type": "video",
                                    "event_type": "normal",
                                    "title": "REC00002.AVI",
                                    "start_time": "2023-06-10 19:20:12",
                                    "duration_sec": 45,
                                    "thumb_ready": 1,
                                    "locked": 0
                                ])
                            ])
                        ])
                    ])
                ])
            case "THUMB_LIST":
                return makeTopicResponse(request, parameters: [
                    "thumbs": .array([makeDeviceThumbnailParameters()])
                ])
            case "THUMB_GET":
                return makeTopicResponse(request, parameters: [
                    "path": .string("/DCIMA/REC00002.AVI"),
                    "format": .string("JPEG"),
                    "width": .int(320),
                    "height": .int(180),
                    "size": .int(4),
                    "image_base64": .string(alternateTestThumbnailBase64)
                ])
            default:
                return makeHandshakeResponse(request)
            }
        }
        let store = GalleryStore(deviceSession: session)

        startHandshake(session)

        #expect(await waitForSessionState {
            store.items.count == 2 &&
            store.items.last?.thumbnailImageBase64 == alternateTestThumbnailBase64
        })
        #expect(transport.sentMessages.contains {
            $0.topic == "THUMB_GET" &&
            $0.parameters["path"]?.stringValue == "/DCIMA/REC00002.AVI"
        })
    }

    @Test
    func protocolEventsUpdateSessionDeviceStatus() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        transport.push(makeProtocolEvent(topic: "SD_STATUS", parameters: ["online": 2]))
        transport.push(makeProtocolEvent(topic: "BAT_STATUS", parameters: ["level": 3]))
        transport.push(makeProtocolEvent(
            topic: "VIDEO_CTRL",
            parameters: ["status": 1, "path": "/DCIMA/REC00008.AVI"]
        ))
        transport.push(makeProtocolEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "format-task-0001",
                "type": "format",
                "progress": 45,
                "status": "processing"
            ]
        ))

        #expect(await waitForSessionState {
            session.deviceStatus.recordingState?.path == "/DCIMA/REC00008.AVI"
        })
        #expect(session.deviceStatus.sdCardOnline == 2)
        #expect(session.deviceStatus.batteryLevel == 3)
        #expect(session.deviceStatus.recordingState?.isRecording == true)
        #expect(session.deviceStatus.progressEvents.values.contains {
            $0.topic == "FORMAT_PROGRESS" &&
                $0.taskID == "format-task-0001" &&
                $0.progress == 45
        })
    }

    @Test
    func protocolEventsRejectInvalidStatusFieldValues() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        transport.push(makeProtocolEvent(topic: "SD_STATUS", parameters: ["online": 2]))
        transport.push(makeProtocolEvent(topic: "BAT_STATUS", parameters: ["level": 3]))
        #expect(await waitForSessionState {
            session.deviceStatus.sdCardOnline == 2 &&
                session.deviceStatus.batteryLevel == 3
        })

        transport.push(makeProtocolEvent(topic: "SD_STATUS", parameters: ["online": true]))
        transport.push(makeProtocolEvent(topic: "BAT_STATUS", parameters: ["level": 5]))

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(session.deviceStatus.sdCardOnline == 2)
        #expect(session.deviceStatus.batteryLevel == 3)
    }

    @Test
    func progressEventsRejectDocumentedInvalidFields() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        transport.push(makeProtocolEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "download-valid",
                "type": "transfer",
                "path": "/DCIMA/REC00008.AVI",
                "progress": 20,
                "speed": 2048,
                "status": "processing"
            ]
        ))

        #expect(await waitForSessionState {
            session.deviceStatus.latestProgressEvent?.taskID == "download-valid"
        })

        transport.push(makeProtocolEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "",
                "type": "format",
                "progress": 10,
                "status": "processing"
            ]
        ))
        transport.push(makeProtocolEvent(
            topic: "UPGRADE_PROGRESS",
            parameters: [
                "task_id": "upgrade-invalid",
                "type": "upgrade",
                "progress": 101,
                "stage": "verifying",
                "status": "queued"
            ]
        ))
        transport.push(makeProtocolEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "download-invalid",
                "type": "transfer",
                "path": "",
                "progress": 60,
                "speed": -1,
                "status": "processing"
            ]
        ))
        transport.push(makeProtocolEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "format-wrong-type",
                "type": "transfer",
                "progress": 30,
                "status": "processing"
            ]
        ))
        transport.push(makeProtocolEvent(
            topic: "UPGRADE_PROGRESS",
            parameters: [
                "task_id": "upgrade-wrong-type",
                "type": "format",
                "progress": 40,
                "stage": "downloading",
                "status": "processing"
            ]
        ))
        transport.push(makeProtocolEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "download-wrong-type",
                "type": "upgrade",
                "path": "/DCIMA/REC00009.AVI",
                "progress": 50,
                "speed": 1024,
                "status": "processing"
            ]
        ))

        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(session.deviceStatus.latestProgressEvent?.taskID == "download-valid")
        #expect(session.deviceStatus.progressEvents[""] == nil)
        #expect(session.deviceStatus.progressEvents["upgrade-invalid"] == nil)
        #expect(session.deviceStatus.progressEvents["download-invalid"] == nil)
        #expect(session.deviceStatus.progressEvents["FORMAT_PROGRESS#format-wrong-type"] == nil)
        #expect(session.deviceStatus.progressEvents["UPGRADE_PROGRESS#upgrade-wrong-type"] == nil)
        #expect(session.deviceStatus.progressEvents["DOWNLOAD_PROGRESS#download-wrong-type"] == nil)
    }

    @Test
    func progressEventsAreSeparatedByTopicAndTaskID() async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeHandshakeResponse(request)
        }

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        transport.push(makeProtocolEvent(
            topic: "FORMAT_PROGRESS",
            parameters: [
                "task_id": "shared-task",
                "type": "format",
                "progress": 45,
                "status": "processing"
            ]
        ))
        transport.push(makeProtocolEvent(
            topic: "DOWNLOAD_PROGRESS",
            parameters: [
                "task_id": "shared-task",
                "type": "transfer",
                "path": "/DCIMA/REC00008.AVI",
                "progress": 20,
                "speed": 2048,
                "status": "processing"
            ]
        ))

        #expect(await waitForSessionState {
            session.deviceStatus.latestProgressEvent?.topic == "DOWNLOAD_PROGRESS"
        })
        #expect(session.deviceStatus.progressEvents.values.contains {
            $0.topic == "FORMAT_PROGRESS" && $0.taskID == "shared-task"
        })
        #expect(session.deviceStatus.progressEvents.values.contains {
            $0.topic == "DOWNLOAD_PROGRESS" && $0.taskID == "shared-task"
        })
        #expect(session.deviceStatus.progressEvents.count == 2)
    }

    private func expectControlCommandBlocked<Success>(
        topic: String,
        cameraCapabilities: [String: DeviceProtocolValue],
        send: (DeviceSession, @escaping (Result<Success, DeviceSessionCommandError>) -> Void) -> Void
    ) async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: cameraCapabilities
            )
        }
        var result: Result<Success, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        send(session) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let responseTopic, _)))? = result {
            #expect(errno == -5)
            #expect(responseTopic == topic)
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == topic } == false)
    }

    private func expectControlCommandRejectedForInvalidParameters<Success>(
        topic: String,
        send: (DeviceSession, @escaping (Result<Success, DeviceSessionCommandError>) -> Void) -> Void
    ) async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var result: Result<Success, DeviceSessionCommandError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        send(session) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let responseTopic, _)))? = result {
            #expect(errno == -2)
            #expect(responseTopic == topic)
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == topic } == false)
    }

    private func expectReadOnlyCommandBlocked<Success>(
        topic: String,
        cameraCapabilities: [String: DeviceProtocolValue],
        send: (DeviceSession, @escaping (Result<Success, DeviceSessionReadOnlyError>) -> Void) -> Void
    ) async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeControlTopicResponse(request) ?? makeHandshakeResponse(
                request,
                cameraCapabilities: cameraCapabilities
            )
        }
        var result: Result<Success, DeviceSessionReadOnlyError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        send(session) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let responseTopic, _)))? = result {
            #expect(errno == -5)
            #expect(responseTopic == topic)
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == topic } == false)
    }

    private func expectReadOnlyCommandRejectedForInvalidParameters<Success>(
        topic: String,
        send: (DeviceSession, @escaping (Result<Success, DeviceSessionReadOnlyError>) -> Void) -> Void
    ) async {
        let transport = SessionFakeDeviceProtocolTransport()
        let session = makeSession(transport: transport)
        transport.responseProvider = { request in
            makeFileTopicResponse(request) ?? makeHandshakeResponse(request)
        }
        var result: Result<Success, DeviceSessionReadOnlyError>?

        startHandshake(session)
        #expect(await waitForSessionState { session.state.isConnected })

        send(session) { commandResult in
            result = commandResult
        }

        #expect(await waitForSessionState { result != nil })
        if case .failure(.protocolFailure(.deviceError(let errno, let responseTopic, _)))? = result {
            #expect(errno == -2)
            #expect(responseTopic == topic)
        } else {
            #expect(Bool(false))
        }
        #expect(transport.sentMessages.contains { $0.topic == topic } == false)
    }
}

private func makeSession(
    transport: SessionFakeDeviceProtocolTransport,
    handshakeCommandTimeout: TimeInterval = 3
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
    errno: Int = 0,
    appAccessParameters: [String: DeviceProtocolValue] = [:],
    protocolVersion: String = "1.2",
    cameraCapabilities: [String: DeviceProtocolValue]? = nil
) -> DeviceProtocolMessage {
    DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: errno,
        parameters: responseParameters(
            for: request.topic,
            protocolVersion: protocolVersion,
            cameraCapabilities: cameraCapabilities
        ).merging(
            request.topic == "APP_ACCESS" ? appAccessParameters : [:]
        ) { current, _ in current }
    )
}

private func makeHeartbeatResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage {
    DeviceProtocolMessage(
        topic: "HEARTBEAT",
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: 0,
        parameters: [
            "ack": true,
            "seq": request.parameters["seq"] ?? 0
        ]
    )
}

private func makeProtocolEvent(
    topic: String,
    parameters: [String: DeviceProtocolValue],
    errno: Int = 0
) -> DeviceProtocolMessage {
    DeviceProtocolMessage(
        topic: topic,
        operation: .notify,
        messageID: "evt-\(topic.lowercased())",
        notifyType: .event,
        errno: errno,
        parameters: parameters
    )
}

private func makeTopicResponse(
    _ request: DeviceProtocolMessage,
    parameters: [String: DeviceProtocolValue],
    errno: Int = 0
) -> DeviceProtocolMessage {
    DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: errno,
        parameters: parameters
    )
}

private func responseParameters(
    for topic: String,
    protocolVersion: String = "1.2",
    cameraCapabilities: [String: DeviceProtocolValue]? = nil
) -> [String: DeviceProtocolValue] {
    switch topic {
    case "PROTOCOL_VERSION":
        return ["protocol_ver": .string(protocolVersion)]
    case "UUID":
        return ["uuid": "112233445566778899"]
    case "FW_VERSION":
        return ["ver": "v1.0.1"]
    case "SD_STATUS":
        return ["online": 1]
    case "BAT_STATUS":
        return ["level": 4]
    case "TF_CAP":
        return [
            "left": 4_000,
            "total": 22_222
        ]
    case "CAMERA_CAPABILITY":
        return [
            "capabilities": .object(cameraCapabilities ?? defaultCameraCapabilities())
        ]
    default:
        return [:]
    }
}

private func defaultCameraCapabilities() -> [String: DeviceProtocolValue] {
    var capabilities = legacyCameraCapabilities()
    capabilities["protocol"] = .object([
        "inline_media_base64": true,
        "state_sync_supported": true,
        "media_index_supported": true,
        "recent_events_supported": true,
        "aggregate_config_supported": true
    ])
    capabilities["video"] = .object([
        "supported": true,
        "resolutions": ["4K", "2K", "1080P", "720P", "WVGA"],
        "codecs": ["H.264"],
        "maxFps": 60,
        "loop_modes": ["off", "1min", "3min", "5min", "10min"]
    ])
    capabilities["photo"] = .object([
        "supported": true,
        "resolutions": ["VGA", "1.3M", "2M", "3M", "5M", "8M", "10M", "12M"],
        "qualities": ["low", "middle", "high"]
    ])
    capabilities["image"] = .object([
        "wdr": true,
        "exposure_options": [-2, 0, 2],
        "mirror": true,
        "flip": true,
        "light_frequency": ["50Hz", "60Hz"],
        "tv_mode": ["PAL", "NTSC"],
        "anti_tremor": true,
        "ir_switch": true,
        "snapshot_transport": ["base64"]
    ])
    capabilities["audio"] = .object([
        "supported": true,
        "mic_switchable": true,
        "speaker_volume": true,
        "speech": true,
        "key_voice": true
    ])
    capabilities["parking"] = .object([
        "supported": true,
        "modes": ["off", "timelapse", "normal"],
        "monitor_time_options": [0, 6, 12, 24, 48, 96],
        "voltage_protection": [11.8, 12.0, 12.2, 12.5],
        "guard_switch": true,
        "collision_sensitivity": [0, 1, 2, 3]
    ])
    capabilities["gps"] = .object([
        "supported": true,
        "realtime_data": true,
        "video_overlay": true
    ])
    capabilities["file"] = .object([
        "lock": true,
        "unlock": false,
        "delete_locked": false,
        "thumbnail": true,
        "download": true,
        "thumbnail_transport": ["base64"]
    ])
    capabilities["system"] = .object([
        "wifi_config": true,
        "wifi_ssid_editable": true,
        "wifi_pwd_editable": true,
        "factory_reset": true,
        "auto_shutdown": true,
        "screen_protect": true,
        "hour_type": [12, 24]
    ])
    return capabilities
}

private func legacyCameraCapabilities() -> [String: DeviceProtocolValue] {
    [
        "video": .object(["supported": true]),
        "file": .object(["thumbnail": true, "download": true]),
        "system": .object(["wifi_config": true])
    ]
}

private func makeFileTopicResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage? {
    let parameters: [String: DeviceProtocolValue]

    switch request.topic {
    case "FILE_LIST":
        parameters = [
            "type": "video",
            "total": 1,
            "page": 1,
            "page_size": 20,
            "files": .array([makeDeviceFileItemParameters()])
        ]
    case "FILE_INFO":
        parameters = makeDeviceFileInfoParameters()
    case "FILE_DOWNLOAD_URL":
        parameters = [
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
    case "THUMB_LIST":
        parameters = [
            "thumbs": .array([makeDeviceThumbnailParameters()])
        ]
    case "THUMB_GET":
        parameters = makeDeviceThumbnailObject()
    default:
        return nil
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

private func makeDeviceInfoTopicResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage? {
    guard request.topic == "DEVICE_INFO" else {
        return nil
    }

    return DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: 0,
        parameters: [
            "device_name": "Camera 360",
            "model": "C360-X1",
            "serial_no": "C360X1202605140001",
            "uuid": "112233445566778899",
            "fw_version": "v1.0.1",
            "protocol_version": "1.2"
        ]
    )
}

private func makeRealtimeGPSDataTopicResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage? {
    guard request.topic == "VI_GPS_RTDATA" else {
        return nil
    }

    return DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: 0,
        parameters: [
            "info": "2022/05/27 21:20:29 N:22.525370 E:114.429984 0.00 km/h 0.00 25.70 8"
        ]
    )
}

private func makeControlTopicResponse(
    _ request: DeviceProtocolMessage,
    errno: Int = 0
) -> DeviceProtocolMessage? {
    let parameters: [String: DeviceProtocolValue]

    switch request.topic {
    case "VIDEO_CTRL":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 0) : 0,
            "path": request.operation == .post ? "/DCIMA/REC99999.AVI" : ""
        ]
    case "VIDEO_SIZE":
        parameters = [
            "str": request.parameters["str"] ?? "4K;2K;1080P",
            "val": request.operation == .post ? (request.parameters["val"] ?? 2) : 1
        ]
    case "VIDEO_LOOP":
        parameters = [
            "cyc": request.operation == .post ? (request.parameters["cyc"] ?? 2) : 1
        ]
    case "VIDEO_MIC":
        parameters = [
            "mic": request.operation == .post ? (request.parameters["mic"] ?? 0) : 1
        ]
    case "VIDEO_WDR":
        parameters = [
            "wdr": request.operation == .post ? (request.parameters["wdr"] ?? 1) : 1
        ]
    case "VIDEO_EXP":
        parameters = [
            "exp": request.operation == .post ? (request.parameters["exp"] ?? 6) : 6
        ]
    case "GRA_SEN":
        parameters = [
            "gra": request.operation == .post ? (request.parameters["gra"] ?? 2) : 2
        ]
    case "MOVE_CHECK":
        parameters = [
            "mot": request.operation == .post ? (request.parameters["mot"] ?? 1) : 1
        ]
    case "MONITOR_MODE":
        parameters = [
            "mode": request.operation == .post ? (request.parameters["mode"] ?? 1) : 1
        ]
    case "MONITOR_TIME":
        parameters = [
            "gaplen": request.operation == .post ? (request.parameters["gaplen"] ?? 12) : 12
        ]
    case "VOLTAGE_PRO":
        parameters = [
            "vpr": request.operation == .post ? (request.parameters["vpr"] ?? 1) : 1
        ]
    case "VIDEO_DATE":
        parameters = [
            "dat": request.operation == .post ? (request.parameters["dat"] ?? 1) : 1
        ]
    case "MIRROR_HOR":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "FLIP_VER":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "AUTO_SHUTDOWN":
        parameters = [
            "aff": request.operation == .post ? (request.parameters["aff"] ?? 1) : 1
        ]
    case "SCREEN_PRO":
        parameters = [
            "pro": request.operation == .post ? (request.parameters["pro"] ?? 2) : 2
        ]
    case "VIDEO_PARAM":
        parameters = [
            "w": request.operation == .post ? (request.parameters["w"] ?? 1280) : 1280,
            "h": request.operation == .post ? (request.parameters["h"] ?? 720) : 720,
            "format": request.operation == .post ? (request.parameters["format"] ?? 1) : 1
        ]
    case "PHOTO_RESO":
        parameters = [
            "reso": request.operation == .post ? (request.parameters["reso"] ?? "12M") : "12M"
        ]
    case "PHOTO_QUALITY":
        parameters = [
            "quality": request.operation == .post ? (request.parameters["quality"] ?? "high") : "high"
        ]
    case "PHOTO_DATE":
        parameters = [
            "date": request.operation == .post ? (request.parameters["date"] ?? 1) : 1
        ]
    case "TV_MODE":
        parameters = [
            "mode": request.operation == .post ? (request.parameters["mode"] ?? "PAL") : "PAL"
        ]
    case "VIDEO_PAR_CAR":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "VIDEO_PAR_VSIX":
        parameters = [
            "level": request.operation == .post ? (request.parameters["level"] ?? 2) : 2
        ]
    case "VIDEO_INV":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "VIDEO_SYNC":
        parameters = [
            "sync": request.operation == .post ? (request.parameters["sync"] ?? 1) : 1
        ]
    case "VIDEO_RDER":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "LIGHT_FRE":
        parameters = [
            "freq": request.operation == .post ? (request.parameters["freq"] ?? "50Hz") : "50Hz"
        ]
    case "SPEAKER_VOLUME":
        parameters = [
            "volume": request.operation == .post ? (request.parameters["volume"] ?? 5) : 5
        ]
    case "SPEECH":
        parameters = [
            "speech": request.operation == .post ? (request.parameters["speech"] ?? 1) : 1
        ]
    case "KEY_VOICE":
        parameters = [
            "voice": request.operation == .post ? (request.parameters["voice"] ?? 1) : 1
        ]
    case "ANTI_TREMOR":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "EDOG_VOICE":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "IR_SWITCH":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 1) : 1
        ]
    case "SNAPSHOT_CTRL":
        parameters = [
            "snapshot_id": "snap-1",
            "status": "ok"
        ]
    case "SNAPSHOT_DATA":
        parameters = [
            "snapshot_id": "snap-1",
            "format": "JPEG",
            "width": .int(1280),
            "height": .int(720),
            "size": .int(24_000),
            "create_time": "20260429103000",
            "image_base64": .string(validTestSnapshotBase64)
        ]
    case "DATE_TIME":
        parameters = [
            "date": request.parameters["date"] ?? "",
            "tz_offset_min": request.parameters["tz_offset_min"] ?? 0
        ]
    case "HOUR_TYPE":
        parameters = [
            "type": request.operation == .post ? (request.parameters["type"] ?? 24) : 24
        ]
    case "FILE_DELETE":
        parameters = [
            "path": request.parameters["path"] ?? "",
            "deleted": 1
        ]
    case "FILE_LOCK":
        parameters = [
            "file": request.parameters["file"] ?? "",
            "status": request.parameters["status"] ?? 1
        ]
    case "AP_SSID_INFO":
        parameters = [
            "ssid": request.operation == .post ? (request.parameters["ssid"] ?? "Cam360_New") : "Cam360_AP",
            "pwd": request.operation == .post ? (request.parameters["pwd"] ?? "12345678") : "********",
            "status": 1
        ]
    case "FORMAT":
        parameters = [
            "frm": 1
        ]
    case "SYSTEM_DEFAULT":
        parameters = [
            "def": request.parameters["def"] ?? 1
        ]
    case "UPGRADE_CHECK":
        parameters = [
            "current_version": "v1.0.1",
            "latest_version": request.parameters["latest_version"] ?? "v1.1.0",
            "has_update": 1,
            "upgrade_allowed": 1,
            "reason": "ok",
            "release_notes": request.parameters["release_notes"] ?? .array([])
        ]
    case "UPGRADE_CTRL":
        parameters = [
            "task_id": "upgrade-task-20260514-0001",
            "accepted": 1,
            "status": "queued",
            "target_version": request.parameters["target_version"] ?? "v1.1.0"
        ]
    default:
        return nil
    }

    return DeviceProtocolMessage(
        topic: request.topic,
        operation: .notify,
        messageID: "dev-\(request.messageID)",
        notifyType: .response,
        replyTo: request.messageID,
        errno: errno,
        parameters: parameters
    )
}

private func makeStatusTopicResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage? {
    let parameters: [String: DeviceProtocolValue]

    switch request.topic {
    case "SD_STATUS":
        parameters = ["online": 1]
    case "BAT_STATUS":
        parameters = ["level": 4]
    case "TF_CAP":
        parameters = [
            "left": 4_000,
            "total": 22_222
        ]
    default:
        return nil
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

private func makeAggregateTopicResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage? {
    let parameters: [String: DeviceProtocolValue]

    switch request.topic {
    case "STATE_SYNC":
        parameters = [
            "scope": request.parameters["scope"] ?? "initial",
            "sections": .object([
                "home": .object([
                    "recent_events": .array([makeRecentEventObject()])
                ])
            ])
        ]
    case "RECENT_EVENTS":
        parameters = [
            "limit": request.parameters["limit"] ?? 4,
            "total_recent_count": 1,
            "items": .array([makeRecentEventObject()])
        ]
    case "MEDIA_INDEX":
        parameters = [
            "filters": .object(request.parameters),
            "summary": .object(["total_count": 1, "event_count": 1, "locked_count": 1]),
            "groups": .array([
                .object([
                    "group_key": "2023-06-10",
                    "items": .array([makeMediaIndexItemObject()])
                ])
            ])
        ]
    case "RECORDING_CONFIG":
        parameters = [
            "resolution": .object(["current": "1080P"]),
            "quality_priority": .object(["current": "balanced"]),
            "loop_recording": .object(["current": 3, "unit": "min"]),
            "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
            "start_behavior": "auto",
            "audio_recording": 1,
            "hdr_night_recording": 1,
            "status_indicator": 1,
            "recording_reminder": 0,
            "estimated_storage_per_hour_mb": 4200
        ]
    case "SAFETY_CONFIG":
        parameters = [
            "collision": .object([
                "g_sensor_sensitivity": .object(["current": "medium"]),
                "emergency_video_lock": 1
            ]),
            "parking": .object([
                "parking_mode": 1,
                "motion_detection": 1,
                "impact_detection": 1
            ]),
            "event_recording": .object([
                "clip_duration_sec": .object(["current": 30])
            ]),
            "notifications": .object([
                "event_notifications": request.parameters["event_notifications"] ?? 1
            ])
        ]
    case "STORAGE_POLICY_CONFIG":
        parameters = [
            "sd": .object(["online": 1, "status": "normal", "policy_editable": 1]),
            "tf": .object(["used_gb": 74.2, "total_gb": 128.0, "usage_percent": 58]),
            "maintenance": .object([
                "estimated_remaining_recording_hours": 5.5,
                "auto_cleanup": .object(["enabled": 0, "retention_days": 30])
            ]),
            "general_policy": .object([
                "auto_overwrite": request.parameters["auto_overwrite"] ?? 1,
                "locked_event_retention": "forever"
            ]),
            "storage_allocation": .object(["reserved_space_for_events_percent": 20])
        ]
    case "SYSTEM_PREFERENCES_CONFIG":
        parameters = [
            "device_identity": .object([
                "device_name": request.parameters["device_name"] ?? "Road Camera",
                "device_name_editable": 1
            ]),
            "connectivity": .object(["ssid": "Cam360_AP", "status": "connected"]),
            "software": .object(["firmware_version": "v1.0.1"]),
            "localization": .object(["time_zone": "UTC+8", "language": "zh-CN", "date_time_auto_sync": 1]),
            "audio": .object(["speaker_volume": .object(["current": "medium"]), "status_sounds": 1])
        ]
    case "WATERMARK_CONFIG":
        parameters = [
            "time_enabled": request.parameters["time_enabled"] ?? 1,
            "plate_enabled": 1,
            "plate_number": "AB1234CD",
            "position": "bottom_right"
        ]
    default:
        return nil
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

private func makeRecentEventObject() -> DeviceProtocolValue {
    .object([
        "event_id": "evt-1",
        "path": "/DCIMA/REC00001.AVI",
        "event_type": "impact",
        "title_key": "event.collision_detected",
        "title": "Collision Detected",
        "create_time": "20230610191512",
        "duration": 30,
        "locked": 1
    ])
}

private func makeMediaIndexItemObject() -> DeviceProtocolValue {
    .object([
        "path": "/DCIMA/REC00001.AVI",
        "name": "REC00001.AVI",
        "media_type": "video",
        "event_type": "impact",
        "record_type": "impact",
        "title_key": "event.collision_detected",
        "title": "Collision Detected",
        "start_time": "2023-06-10 19:15:12",
        "create_time": "20230610191512",
        "duration_sec": 30,
        "duration": 30,
        "resolution": "1080P",
        "size": 712_345_678,
        "locked": 1,
        "thumb_ready": 1,
        "has_thumbnail": 1
    ])
}

private func makeDeviceFileItemParameters() -> DeviceProtocolValue {
    .object([
        "name": "REC00001.AVI",
        "path": "/DCIMA/REC00001.AVI",
        "size": 524_288_000,
        "duration": 180,
        "resolution": "1920x1080",
        "create_time": "20230607103056",
        "has_thumbnail": true,
        "locked": 1,
        "type": "normal"
    ])
}

private func makeDeviceFileInfoParameters() -> [String: DeviceProtocolValue] {
    guard case .object(let parameters) = makeDeviceFileItemParameters() else {
        return [:]
    }

    return parameters.merging([
        "codec": "H.264",
        "bitrate": 8_000_000,
        "framerate": 30,
        "gps_data": "2022/05/27 21:20:29 N:22.525370 E:114.429984"
    ]) { _, new in new }
}

private func makeDeviceThumbnailParameters() -> DeviceProtocolValue {
    .object(makeDeviceThumbnailObject())
}

private func makeDeviceThumbnailObject() -> [String: DeviceProtocolValue] {
    [
        "path": "/DCIMA/REC00001.AVI",
        "format": "JPEG",
        "width": 320,
        "height": 180,
        "size": 18_342,
        "image_base64": .string(validTestThumbnailBase64)
    ]
}

private func makeTestDeviceInfo() -> DeviceInfo {
    DeviceInfo(
        id: "112233445566778899",
        name: "Road Camera",
        firmwareVersion: "v1.0.1",
        capabilities: [.livePreview, .playback, .download, .settings]
    )
}

private func failedError(from state: DeviceSessionState) -> DeviceError? {
    if case .failed(let error) = state {
        return error
    }
    return nil
}

private extension Result where Failure == DeviceSessionCommandError {
    var failureMessage: String? {
        if case .failure(let error) = self {
            return error.message
        }
        return nil
    }
}

private extension Dictionary where Key == String, Value == DeviceProtocolValue {
    func object(_ key: String) -> [String: DeviceProtocolValue]? {
        self[key]?.objectValue
    }
}

@MainActor
private func waitForSessionState(
    timeout: TimeInterval = 3,
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
