import Foundation

indirect enum DeviceSessionState: Equatable {
    case idle
    case apConnecting
    case handshaking
    case ready(DeviceInfo)
    case busy(Operation)
    case recovering(previousState: DeviceSessionState)
    case failed(DeviceError)
    case disconnected

    var isConnected: Bool {
        switch self {
        case .ready, .busy:
            return true
        default:
            return false
        }
    }

    var canStartOperation: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
}

struct DeviceInfo: Equatable {
    let id: String
    let name: String
    let firmwareVersion: String
    let capabilities: Set<DeviceCapability>
}

enum DeviceCapability: String, Equatable, Codable {
    case livePreview
    case playback
    case download
    case settings
}

enum DeviceError: Error, Equatable {
    case apConnectionFailed(reason: String)
    case handshakeFailed(reason: String)
    case connectionLost
    case timeout
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .apConnectionFailed(let reason):
            return "热点连接失败: \(reason)"
        case .handshakeFailed(let reason):
            return "设备握手失败: \(reason)"
        case .connectionLost:
            return "连接已断开"
        case .timeout:
            return "连接超时"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

enum Operation: Equatable {
    case livePreview
    case playback(recordingId: String)
    case download(recordingId: String)
    case updateSettings
}
