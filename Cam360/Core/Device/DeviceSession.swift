import Foundation
import Combine

final class DeviceSession: ObservableObject {
    @Published private(set) var state: DeviceSessionState = .idle
    @Published private(set) var currentOperation: Operation?

    private var previousStateBeforeRecovery: DeviceSessionState?

    func send(_ event: DeviceSessionEvent) {
        rememberRecoveryStateIfNeeded(for: event)

        let nextState = transition(from: state, event: event)
        if nextState != state {
            state = nextState
        }

        updateDerivedState(for: nextState)
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

        case (.ready(let deviceInfo), .startOperation(let operation)):
            return .busy(operation: operation, deviceInfo: deviceInfo)

        case (.busy(operation: _, deviceInfo: let deviceInfo), .operationCompleted):
            return .ready(deviceInfo)

        case (.busy, .operationFailed(let error)):
            return .failed(error)

        case (_, .connectionLost):
            return .failed(.connectionLost)

        case (.failed, .startRecovery):
            return .recovering(previousState: previousStateBeforeRecovery ?? .idle)

        case (.recovering, .recoverySucceeded):
            let recoveredState = previousStateBeforeRecovery ?? .idle
            previousStateBeforeRecovery = nil
            return recoveredState

        case (.recovering, .recoveryFailed(let error)):
            return .failed(error)

        case (.ready, .disconnect), (.busy, .disconnect), (.failed, .disconnect), (.recovering, .disconnect):
            return .disconnected

        case (_, .reset):
            previousStateBeforeRecovery = nil
            return .idle

        default:
            return state
        }
    }

    private func rememberRecoveryStateIfNeeded(for event: DeviceSessionEvent) {
        switch event {
        case .connectionLost, .operationFailed:
            previousStateBeforeRecovery = recoverableState(from: state)
        case .startAPConnection, .reset, .disconnect:
            previousStateBeforeRecovery = nil
        default:
            break
        }
    }

    private func recoverableState(from state: DeviceSessionState) -> DeviceSessionState? {
        switch state {
        case .ready(let deviceInfo):
            return .ready(deviceInfo)
        case .busy(operation: _, deviceInfo: let deviceInfo):
            return .ready(deviceInfo)
        case .recovering(let previousState):
            return previousState
        default:
            return nil
        }
    }

    private func updateDerivedState(for state: DeviceSessionState) {
        switch state {
        case .busy(operation: let operation, deviceInfo: _):
            currentOperation = operation
        default:
            currentOperation = nil
        }
    }
}
