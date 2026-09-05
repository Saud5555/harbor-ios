import Foundation

actor SubtitleFileCache {
    static let shared = SubtitleFileCache()

    private var files: [URL: URL] = [:]

    func file(for remoteURL: URL) async throws -> URL {
        if let cached = files[remoteURL], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        try HTTPResponse.validate(response)
        guard !data.isEmpty else { throw StremioAPIError.decoding }

        let supported = ["srt", "vtt", "ass", "ssa", "sub"]
        let remoteExtension = remoteURL.pathExtension.lowercased()
        let fileExtension = supported.contains(remoteExtension) ? remoteExtension : "srt"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HarborSubtitles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let localURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try data.write(to: localURL, options: .atomic)
        files[remoteURL] = localURL
        return localURL
    }
}
