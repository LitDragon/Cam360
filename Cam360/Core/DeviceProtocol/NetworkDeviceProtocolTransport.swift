import Foundation
import Network

final class NetworkDeviceProtocolTransport: DeviceProtocolTransport {
    var onReceiveData: ((Data) -> Void)?
    var onDisconnect: ((Error?) -> Void)?

    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.cam360.network-device-protocol-transport")
    private var connection: NWConnection?

    init(host: String, port: UInt16 = 8765) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port) ?? 8765
    }

    func connect(completion: @escaping (Result<Void, DeviceProtocolError>) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            let connection = NWConnection(host: self.host, port: self.port, using: .tcp)
            var hasCompleted = false
            self.connection = connection

            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    guard hasCompleted == false else {
                        return
                    }
                    hasCompleted = true
                    completion(.success(()))
                    self?.receiveNext()
                case .failed(let error):
                    guard hasCompleted == false else {
                        self?.onDisconnect?(error)
                        return
                    }
                    hasCompleted = true
                    completion(.failure(.transportFailed(error.localizedDescription)))
                case .cancelled:
                    self?.onDisconnect?(nil)
                default:
                    break
                }
            }

            connection.start(queue: self.queue)
        }
    }

    func send(_ data: Data, completion: @escaping (Result<Void, DeviceProtocolError>) -> Void) {
        queue.async { [weak self] in
            guard let connection = self?.connection else {
                completion(.failure(.transportDisconnected))
                return
            }

            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    completion(.failure(.transportFailed(error.localizedDescription)))
                } else {
                    completion(.success(()))
                }
            })
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            self?.connection?.cancel()
            self?.connection = nil
        }
    }

    private func receiveNext() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }

            if let data, data.isEmpty == false {
                self.onReceiveData?(data)
            }

            if let error {
                self.onDisconnect?(error)
                return
            }

            if isComplete {
                self.onDisconnect?(nil)
                return
            }

            self.receiveNext()
        }
    }
}
