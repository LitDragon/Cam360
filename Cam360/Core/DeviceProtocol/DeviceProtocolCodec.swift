import Foundation

struct DeviceProtocolCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func encode(_ message: DeviceProtocolMessage) throws -> Data {
        do {
            var data = try encoder.encode(message)
            data.append(0x0A)
            return data
        } catch {
            throw DeviceProtocolError.encodeFailed
        }
    }

    func decode(_ data: Data) throws -> DeviceProtocolMessage {
        let trimmed = data.trimmedASCIIWhitespaceAndNewlines()
        guard trimmed.isEmpty == false else {
            throw DeviceProtocolError.invalidFrame
        }

        do {
            return try decoder.decode(DeviceProtocolMessage.self, from: trimmed)
        } catch {
            throw DeviceProtocolError.decodeFailed
        }
    }
}

private extension Data {
    func trimmedASCIIWhitespaceAndNewlines() -> Data {
        var lowerBound = startIndex
        var upperBound = endIndex

        while lowerBound < upperBound, self[lowerBound].isASCIIWhitespaceOrNewline {
            formIndex(after: &lowerBound)
        }

        while upperBound > lowerBound {
            let previousIndex = index(before: upperBound)
            guard self[previousIndex].isASCIIWhitespaceOrNewline else {
                break
            }
            upperBound = previousIndex
        }

        return self[lowerBound..<upperBound]
    }
}

private extension UInt8 {
    var isASCIIWhitespaceOrNewline: Bool {
        self == 0x20 || self == 0x09 || self == 0x0A || self == 0x0D
    }
}
