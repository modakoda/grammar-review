import Foundation

struct LSPFrameDecoder {
    static let separator = Data("\r\n\r\n".utf8)

    private var buffer = Data()

    mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var messages: [Data] = []
        while let headerEnd = buffer.range(of: Self.separator) {
            let header = String(bytes: buffer[buffer.startIndex..<headerEnd.lowerBound], encoding: .utf8)
            guard let length = header.flatMap(Self.contentLength(in:)) else {
                buffer.removeSubrange(buffer.startIndex..<headerEnd.upperBound)
                continue
            }
            guard buffer.distance(from: headerEnd.upperBound, to: buffer.endIndex) >= length else { break }
            let bodyEnd = buffer.index(headerEnd.upperBound, offsetBy: length)
            messages.append(Data(buffer[headerEnd.upperBound..<bodyEnd]))
            buffer.removeSubrange(buffer.startIndex..<bodyEnd)
        }
        return messages
    }

    static func contentLength(in header: String) -> Int? {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else { continue }
            return Int(parts[1].trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 0 ? $0 : nil }
        }
        return nil
    }

    static func frame(_ body: Data) -> Data {
        Data("Content-Length: \(body.count)\r\n\r\n".utf8) + body
    }
}
