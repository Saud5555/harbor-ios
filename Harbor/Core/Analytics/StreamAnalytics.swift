import Foundation

/// Produces the shared, privacy-safe analytics shape for a selected stream.
enum StreamAnalytics {
    static func selectionParameters(
        stream: ScoredStream,
        position: Int?,
        target: StreamTarget,
        availableAddons: [Addon],
        url: URL,
        analytics: AnalyticsService = .shared
    ) -> HarborAnalyticsParameters {
        var parameters = analytics.mediaParameters(
            mediaType: target.type,
            mediaId: target.metaId,
            source: target.analyticsSource,
            playbackSessionId: target.playbackSessionId,
            seasonNumber: target.seasonNumber,
            episodeNumber: target.episodeNumber
        )
        if let position {
            parameters[.streamPosition] = .int(position)
        }
        parameters[.quality] = .string(qualityToken(stream.parsed.resolution))
        parameters[.resolution] = .string(resolutionToken(stream.parsed.resolution))
        if let codec = stream.parsed.codec {
            parameters[.codec] = .string(codec.lowercased())
        }
        if let container = containerToken(url: url) {
            parameters[.container] = .string(container)
        }
        if let streamType = streamTypeToken(for: stream, url: url) {
            parameters[.streamType] = .string(streamType)
        }
        parameters[.providerType] = .string(
            providerType(for: stream, availableAddons: availableAddons).rawValue
        )
        return parameters
    }

    static func qualityToken(_ resolution: ResolutionRank) -> String {
        switch resolution {
        case .uhd2160: return "uhd"
        case .fhd1080: return "fhd"
        case .hd720: return "hd"
        case .sd: return "sd"
        case .unknown: return "unknown"
        }
    }

    static func resolutionToken(_ resolution: ResolutionRank) -> String {
        switch resolution {
        case .uhd2160: return "2160p"
        case .fhd1080: return "1080p"
        case .hd720: return "720p"
        case .sd: return "sd"
        case .unknown: return "unknown"
        }
    }

    static func containerToken(url: URL) -> String? {
        let supported = Set(["mkv", "mp4", "webm", "avi", "mov", "m3u8", "ts"])
        let value = url.pathExtension.lowercased()
        return supported.contains(value) ? value : nil
    }

    static func streamTypeToken(for stream: ScoredStream, url: URL) -> String? {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return scheme
        }
        if let infoHash = stream.raw.infoHash, !infoHash.isEmpty {
            return "torrent"
        }
        return nil
    }

    static func providerType(
        for stream: ScoredStream,
        availableAddons: [Addon]
    ) -> HarborAddonType {
        guard let id = stream.raw.addonId,
              let addon = availableAddons.first(where: { $0.id == id })
        else { return .unknown }
        return addon.flags?.official == true ? .official : .thirdParty
    }
}
