import Foundation

/// Season and episode coordinates encoded at the end of a Stremio video ID.
struct EpisodeCoordinates: Equatable, Hashable {
    let season: Int
    let episode: Int

    init?(videoID: String?) {
        guard let videoID else { return nil }
        let parts = videoID.split(separator: ":")
        guard parts.count >= 3,
              let season = Int(parts[parts.count - 2]),
              let episode = Int(parts[parts.count - 1])
        else { return nil }
        self.season = season
        self.episode = episode
    }

    var label: String { "S\(season) · E\(episode)" }
}
