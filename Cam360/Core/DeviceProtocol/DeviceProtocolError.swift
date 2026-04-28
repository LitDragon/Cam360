import Foundation

enum DeviceProtocolError: Error, Equatable {
    case invalidFrame
    case encodeFailed
    case decodeFailed
    case transportDisconnected
    case requestTimedOut(topic: String)
    case deviceError(errno: Int, topic: String, parameters: [String: DeviceProtocolValue])
    case responseWithoutRequest(replyTo: String)
    case transportFailed(String)
}
