import Foundation

struct DeviceProtocolFrameBuffer {
    static let maxControlFrameBytes = 64 * 1024
    static let maxMediaFrameBytes = 768 * 1024

    private var buffer = Data()
    private let codec: DeviceProtocolCodec

    init(codec: DeviceProtocolCodec = DeviceProtocolCodec()) {
        self.codec = codec
    }

    var bufferedByteCount: Int {
        buffer.count
    }

    static func allowsExtendedMediaResponseFrame(topic: String) -> Bool {
        ["THUMB_GET", "THUMB_LIST", "SNAPSHOT_DATA"].contains(topic)
    }

    mutating func append(
        _ data: Data,
        maximumControlFrameBytes: Int = Self.maxControlFrameBytes,
        maximumMediaFrameBytes: Int = Self.maxMediaFrameBytes,
        maximumBufferedFrameBytes: Int = Self.maxControlFrameBytes
    ) -> [Result<DeviceProtocolMessage, DeviceProtocolError>] {
        buffer.append(data)
        var results: [Result<DeviceProtocolMessage, DeviceProtocolError>] = []

        while let separatorIndex = buffer.firstIndex(of: 0x0A) {
            let frame = buffer[..<separatorIndex]
            let frameByteCount = frame.count + 1
            buffer.removeSubrange(...separatorIndex)

            guard frame.contains(where: { $0.isASCIIWhitespaceOrNewline == false }) else {
                continue
            }

            guard frameByteCount <= maximumMediaFrameBytes else {
                buffer.removeAll()
                return [.failure(.invalidFrame)]
            }

            do {
                let message = try codec.decode(Data(frame))
                guard frameByteCount <= maximumControlFrameBytes || message.allowsExtendedMediaResponseFrame else {
                    buffer.removeAll()
                    return [.failure(.invalidFrame)]
                }
                results.append(.success(message))
            } catch let error as DeviceProtocolError {
                if frameByteCount > maximumControlFrameBytes {
                    buffer.removeAll()
                    return [.failure(.invalidFrame)]
                }
                results.append(.failure(error))
            } catch {
                if frameByteCount > maximumControlFrameBytes {
                    buffer.removeAll()
                    return [.failure(.invalidFrame)]
                }
                results.append(.failure(.decodeFailed))
            }
        }

        if buffer.count > maximumBufferedFrameBytes {
            buffer.removeAll()
            results.append(.failure(.invalidFrame))
        }

        return results
    }

    mutating func clear() {
        buffer.removeAll()
    }
}

private extension DeviceProtocolMessage {
    var allowsExtendedMediaResponseFrame: Bool {
        operation == .notify
            && notifyType == .response
            && DeviceProtocolFrameBuffer.allowsExtendedMediaResponseFrame(topic: topic)
    }
}
