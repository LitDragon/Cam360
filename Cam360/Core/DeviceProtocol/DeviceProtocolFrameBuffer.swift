import Foundation

struct DeviceProtocolFrameBuffer {
    private var buffer = Data()
    private let codec: DeviceProtocolCodec

    init(codec: DeviceProtocolCodec = DeviceProtocolCodec()) {
        self.codec = codec
    }

    var bufferedByteCount: Int {
        buffer.count
    }

    mutating func append(_ data: Data) -> [Result<DeviceProtocolMessage, DeviceProtocolError>] {
        buffer.append(data)
        var results: [Result<DeviceProtocolMessage, DeviceProtocolError>] = []

        while let separatorIndex = buffer.firstIndex(of: 0x0A) {
            let frame = buffer[..<separatorIndex]
            buffer.removeSubrange(...separatorIndex)

            guard frame.contains(where: { $0.isASCIIWhitespaceOrNewline == false }) else {
                continue
            }

            do {
                results.append(.success(try codec.decode(Data(frame))))
            } catch let error as DeviceProtocolError {
                results.append(.failure(error))
            } catch {
                results.append(.failure(.decodeFailed))
            }
        }

        return results
    }

    mutating func clear() {
        buffer.removeAll()
    }
}
