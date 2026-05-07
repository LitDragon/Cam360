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
            if case .success(let thumbnail) = result, thumbnail.imageBase64 == "base64-jpeg" {
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
        #expect(snapshot?.imageBase64 == "base64-snapshot")
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
        #expect(store.message == "rtsp://192.168.169.1:554/playback/DCIMA/REC00001.AVI · Transport TCP · 180s")
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
            "session_timeout": 60
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

private func makeControlTopicResponse(_ request: DeviceProtocolMessage) -> DeviceProtocolMessage? {
    let parameters: [String: DeviceProtocolValue]

    switch request.topic {
    case "VIDEO_CTRL":
        parameters = [
            "status": request.operation == .post ? (request.parameters["status"] ?? 0) : 0,
            "path": request.operation == .post ? "/DCIMA/REC99999.AVI" : ""
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
            "width": 1280,
            "height": 720,
            "size": 24_000,
            "create_time": "20260429103000",
            "image_base64": "base64-snapshot"
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
        "image_base64": "base64-jpeg"
    ]
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
