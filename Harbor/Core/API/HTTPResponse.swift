import Foundation

/// Shared transport validation. Services retain their own public error types.
enum HTTPResponse {
    static func validate(
        _ response: URLResponse,
        invalidResponse: Error = StremioAPIError.decoding,
        httpError: (Int) -> Error = { StremioAPIError.http($0) }
    ) throws {
        guard let http = response as? HTTPURLResponse else { throw invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw httpError(http.statusCode) }
    }

    static func url(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

enum JSONObject {
    static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StremioAPIError.decoding
        }
        return object
    }
}
