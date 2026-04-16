import Foundation

final class DeviceSession: ObservableObject {
    @Published private(set) var state: DeviceSessionState = .idle
    @Published private(set) var currentOperation: Operation?

    private var previousStateBeforeRecovery: DeviceSessionState?

    func send(_ event: DeviceSessionEvent) {
        let nextState = transition(from: state, event: event)
        if nextState != state {
            state = nextState
        }
    }

    private func transition(from state: DeviceSessionState, event: DeviceSessionEvent) -> DeviceSessionState {
        switch (state, event) {
        case (.idle, .startAPConnection):
            return .apConnecting

        case (.apConnecting, .apConnectionSucceeded):
            return .handshaking

        case (.apConnecting, .apConnectionFailed(let reason)):
            return .failed(.apConnectionFailed(reason: reason))

        case (.handshaking, .startHandshake):
            return .handshaking

        case (.handshaking, .handshakeSucceeded(let deviceInfo)):
            return .ready(deviceInfo)

        case (.handshaking, .handshakeFailed(let reason)):
            return .failed(.handshakeFailed(reason: reason))

        case (.ready, .startOperation(let operation)):
            return .busy(operation)

        case (.busy, .operationCompleted):
            if let prev = previousStateBeforeRecovery {
                previousStateBeforeRecovery = nil
                return prev
            }
            return .ready(extractDeviceInfo(from: state))

        case (.busy, .operationFailed(let error)):
            return .failed(error)

        case (_, .connectionLost):
            return .failed(.connectionLost)

        case (.failed, .startRecovery):
            if case .ready(let info) = stateForRecovery(from: state) {
                previousStateBeforeRecovery = .ready(info)
            }
            return .recovering(previousStateBeforeRecovery ?? .idle)

        case (.recovering, .recoverySucceeded):
            return previousStateBeforeRecovery ?? .idle

        case (.recovering, .recoveryFailed(let error)):
            return .failed(error)

        case (.ready, .disconnect), (.busy, .disconnect), (.failed, .disconnect), (.recovering, .disconnect):
            return .disconnected

        case (_, .reset):
            return .idle

        default:
            return state
        }
    }

    private func stateForRecovery(from state: DeviceSessionState) -> DeviceSessionState {
        return state
    }

    private func extractDeviceInfo(from state: DeviceSessionState) -> DeviceInfo {
        if case .ready(let info) = state {
            return info
        }
        return DeviceInfo(id: "", name: "", firmwareVersion: "", capabilities: [])
    }
}
