import Foundation

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// Decodes valid elements without rejecting an entire Stremio collection when
/// one legacy record contains fields this client does not understand.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        while !container.isAtEnd {
            let element = try container.decode(FailableDecodable<Element>.self)
            if let value = element.value {
                decoded.append(value)
            }
        }
        elements = decoded
    }
}
