import Testing
import Foundation
@testable import Cam360

struct DeviceSessionTests {
    @Test
    func initialStateIsIdle() {
        let session = DeviceSession()

        #expect(session.state == .idle)
        #expect(session.currentOperation == nil)
    }

    @Test
    func startAPConnectionTransitionsToApConnecting() {
        let session = DeviceSession()

        session.send(.startAPConnection(ssid: "Cam360_AP"))

        #expect(session.state == .apConnecting)
    }

    @Test
    func apConnectionSucceededTransitionsToHandshaking() {
        let session = DeviceSession()
        session.send(.startAPConnection(ssid: "Cam360_AP"))

        session.send(.apConnectionSucceeded)

        #expect(session.state == .handshaking)
    }

    @Test
    func apConnectionFailedTransitionsToFailed() {
        let session = DeviceSession()
        session.send(.startAPConnection(ssid: "Cam360_AP"))

        session.send(.apConnectionFailed(reason: "wrong password"))

        #expect(session.state == .failed(.apConnectionFailed(reason: "wrong password")))
    }

    @Test
    func handshakeSucceededTransitionsToReady() {
        let session = DeviceSession()
        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)

        let deviceInfo = DeviceInfo(
            id: "test-device",
            name: "Test Camera",
            firmwareVersion: "1.0.0",
            capabilities: [.livePreview, .playback]
        )
        session.send(.handshakeSucceeded(deviceInfo))

        if case .ready(let info) = session.state {
            #expect(info.id == "test-device")
            #expect(info.capabilities.contains(.livePreview))
        } else {
            Issue.record("Expected state to be .ready")
        }
    }

    @Test
    func startOperationFromReadyTransitionsToBusy() {
        let session = DeviceSession()
        enterReadyState(session)

        session.send(.startOperation(.livePreview))

        if case .busy(let op) = session.state {
            #expect(op == .livePreview)
        } else {
            Issue.record("Expected state to be .busy")
        }
    }

    @Test
    func operationCompletedReturnsToReady() {
        let session = DeviceSession()
        enterReadyState(session)
        session.send(.startOperation(.livePreview))

        session.send(.operationCompleted)

        if case .ready = session.state {
            #expect(true)
        } else {
            Issue.record("Expected state to return to .ready")
        }
    }

    @Test
    func connectionLostFromReadyTransitionsToFailed() {
        let session = DeviceSession()
        enterReadyState(session)

        session.send(.connectionLost)

        #expect(session.state == .failed(.connectionLost))
    }

    @Test
    func disconnectTransitionsToDisconnected() {
        let session = DeviceSession()
        enterReadyState(session)

        session.send(.disconnect)

        #expect(session.state == .disconnected)
    }

    @Test
    func resetFromAnyStateReturnsToIdle() {
        let session = DeviceSession()
        enterReadyState(session)

        session.send(.reset)

        #expect(session.state == .idle)
    }

    @Test
    func startRecoveryFromFailedTransitionsToRecovering() {
        let session = DeviceSession()
        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionFailed(reason: "timeout"))
        #expect(session.state == .failed(.apConnectionFailed(reason: "timeout")))

        session.send(.startRecovery)

        #expect(session.state == .recovering(.idle))
    }

    @Test
    func readyStateIsConnected() {
        let session = DeviceSession()
        enterReadyState(session)

        #expect(session.state.isConnected == true)
    }

    @Test
    func idleStateIsNotConnected() {
        let session = DeviceSession()

        #expect(session.state.isConnected == false)
    }

    @Test
    func readyStateCanStartOperation() {
        let session = DeviceSession()
        enterReadyState(session)

        #expect(session.state.canStartOperation == true)
    }

    @Test
    func busyStateCannotStartAnotherOperation() {
        let session = DeviceSession()
        enterReadyState(session)
        session.send(.startOperation(.livePreview))

        #expect(session.state.canStartOperation == false)
    }

    private func enterReadyState(_ session: DeviceSession) {
        session.send(.startAPConnection(ssid: "Cam360_AP"))
        session.send(.apConnectionSucceeded)
        session.send(.handshakeSucceeded(DeviceInfo(
            id: "test",
            name: "Test",
            firmwareVersion: "1.0",
            capabilities: []
        )))
    }
}
