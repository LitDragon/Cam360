import Foundation

enum DeviceSessionEvent: Equatable {
    case startAPConnection(ssid: String)
    case apConnectionSucceeded
    case apConnectionFailed(reason: String)
    case startHandshake
    case handshakeSucceeded(DeviceInfo)
    case handshakeFailed(reason: String)
    case startOperation(Operation)
    case operationCompleted
    case operationFailed(DeviceError)
    case connectionLost
    case startRecovery
    case recoverySucceeded
    case recoveryFailed(DeviceError)
    case disconnect
    case reset
}
