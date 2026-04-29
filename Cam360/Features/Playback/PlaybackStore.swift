import Combine

final class PlaybackStore: ObservableObject {
    @Published private(set) var title = "没有可播放内容"
    @Published private(set) var message = "当前没有可显示的设备录像或本地媒体。"
    @Published private(set) var isLoading = false
    @Published private(set) var selectedFileInfo: DeviceFileInfo?
    @Published private(set) var playbackResource: DeviceFilePlaybackResource?
    @Published private(set) var lastLoadError: String?

    private let deviceSession: DeviceSession?
    private var lastLoadedDeviceID: String?
    private var loadGeneration = 0
    private var cancellables: Set<AnyCancellable> = []

    init(deviceSession: DeviceSession? = nil) {
        self.deviceSession = deviceSession
        bindDeviceSession()
    }

    private func bindDeviceSession() {
        deviceSession?.$state
            .sink { [weak self] state in
                self?.syncDeviceSessionState(state)
            }
            .store(in: &cancellables)
    }

    private func syncDeviceSessionState(_ state: DeviceSessionState) {
        switch state {
        case .ready(let deviceInfo):
            guard lastLoadedDeviceID != deviceInfo.id else {
                return
            }
            lastLoadedDeviceID = deviceInfo.id
            loadFirstPlaybackResource()
        case .idle, .apConnecting, .handshaking, .failed, .disconnected:
            invalidatePlaybackResource()
        case .busy, .recovering:
            break
        }
    }

    private func loadFirstPlaybackResource() {
        guard let deviceSession else {
            return
        }

        let generation = nextLoadGeneration()
        isLoading = true
        lastLoadError = nil

        deviceSession.fetchFileList(query: DeviceFileListQuery(type: .video, page: 1, pageSize: 1)) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            switch result {
            case .success(let page):
                guard let file = page.files.first else {
                    self.applyEmptyPlaybackState()
                    return
                }
                self.title = file.name
                self.message = file.path
                self.loadPlaybackDetails(path: file.path, generation: generation)
            case .failure(.staleSession):
                break
            case .failure(let error):
                self.applyPlaybackError(error.message)
            }
        }
    }

    private func loadPlaybackDetails(path: String, generation: Int) {
        guard let deviceSession else {
            return
        }

        deviceSession.fetchFileInfo(path: path) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            if case .success(let info) = result {
                self.selectedFileInfo = info
                self.title = info.item.name
            }
        }

        deviceSession.fetchPlaybackResource(path: path) { [weak self] result in
            guard let self, self.isCurrentLoad(generation) else {
                return
            }

            self.isLoading = false
            switch result {
            case .success(let resource):
                self.playbackResource = resource
                self.lastLoadError = nil
                self.message = Self.message(for: resource)
            case .failure(.staleSession):
                break
            case .failure(let error):
                self.applyPlaybackError(error.message)
            }
        }
    }

    private func applyEmptyPlaybackState() {
        isLoading = false
        selectedFileInfo = nil
        playbackResource = nil
        lastLoadError = nil
        title = "没有可播放内容"
        message = "设备当前没有可显示的录像。"
    }

    private func applyPlaybackError(_ errorMessage: String) {
        isLoading = false
        selectedFileInfo = nil
        playbackResource = nil
        lastLoadError = errorMessage
        title = "回放加载失败"
        message = errorMessage
    }

    private func invalidatePlaybackResource() {
        lastLoadedDeviceID = nil
        loadGeneration += 1
        applyEmptyPlaybackState()
        message = "当前没有可显示的设备录像或本地媒体。"
    }

    private func nextLoadGeneration() -> Int {
        loadGeneration += 1
        return loadGeneration
    }

    private func isCurrentLoad(_ generation: Int) -> Bool {
        generation == loadGeneration
    }

    private static func message(for resource: DeviceFilePlaybackResource) -> String {
        var parts = [resource.rtspURL]
        if let transport = resource.transport {
            parts.append("Transport \(transport)")
        }
        if let duration = resource.duration {
            parts.append("\(duration)s")
        }
        return parts.joined(separator: " · ")
    }
}
