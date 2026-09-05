import Foundation

enum TMDBClientError: LocalizedError {
    case invalidKey
    case invalidURL
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Enter a valid TMDB v3 API key."
        case .invalidURL: return "Harbor could not create the TMDB request."
        case .invalidResponse: return "TMDB returned an unreadable response."
        case .http(401): return "TMDB rejected this API key."
        case .http(429): return "TMDB is temporarily rate limiting requests."
        case .http(let code): return "TMDB request failed (HTTP \(code))."
        }
    }
}

final class TMDBClient: @unchecked Sendable {
    static let shared = TMDBClient()

    private static let apiBase = "https://api.themoviedb.org/3"
    private static let imageBase = "https://image.tmdb.org/t/p"

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.requestCachePolicy = .returnCacheDataElseLoad
            self.session = URLSession(configuration: configuration)
        }
    }

    func validate(apiKey: String) async throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TMDBClientError.invalidKey }
        let _: TMDBConfiguration = try await request(path: "configuration", apiKey: trimmed)
    }

    func collection(
        apiKey: String,
        definition: TMDBCollectionDefinition,
        region: String
    ) async throws -> [Meta] {
        let effectiveRegion = Self.normalizedRegion(region)
        switch definition.endpoint {
        case .trendingAll:
            let page: TMDBPage<TMDBCatalogItem> = try await request(
                path: "trending/all/week",
                apiKey: apiKey,
                parameters: ["page": "1"]
            )
            return page.results.compactMap { item in
                guard let kind = item.resolvedKind else { return nil }
                return item.meta(kind: kind)
            }
        case .topRated(let kind):
            let page: TMDBPage<TMDBCatalogItem> = try await request(
                path: "\(kind.rawValue)/top_rated",
                apiKey: apiKey,
                parameters: ["page": "1", "region": effectiveRegion]
            )
            return page.results.compactMap { $0.meta(kind: kind) }
        case .discover(let kind):
            var parameters = definition.parameters
            parameters["page"] = "1"
            parameters["include_adult"] = "false"
            if kind == .movie { parameters["region"] = effectiveRegion }
            let page: TMDBPage<TMDBCatalogItem> = try await request(
                path: "discover/\(kind.rawValue)",
                apiKey: apiKey,
                parameters: parameters
            )
            return page.results.compactMap { $0.meta(kind: kind) }
        }
    }

    func serviceCatalog(
        apiKey: String,
        provider: TMDBStreamingProvider,
        region: String,
        page: Int = 1
    ) async throws -> TMDBServiceCatalog {
        let effectiveRegion = Self.normalizedRegion(region)
        let providerIDs = provider.providerIDs.map(String.init).joined(separator: "|")
        let common = [
            "page": String(page),
            "sort_by": "popularity.desc",
            "vote_count.gte": "100",
            "watch_region": effectiveRegion,
            "with_watch_monetization_types": "flatrate",
            "with_watch_providers": providerIDs,
        ]
        async let moviePage: TMDBPage<TMDBCatalogItem> = request(
            path: "discover/movie",
            apiKey: apiKey,
            parameters: common.merging(["region": effectiveRegion]) { current, _ in current }
        )
        async let seriesPage: TMDBPage<TMDBCatalogItem> = request(
            path: "discover/tv",
            apiKey: apiKey,
            parameters: common
        )
        let (movies, series) = try await (moviePage, seriesPage)
        return TMDBServiceCatalog(
            movies: movies.results.compactMap { $0.meta(kind: .movie) },
            series: series.results.compactMap { $0.meta(kind: .series) }
        )
    }

    func detailMeta(apiKey: String, meta: Meta) async throws -> Meta {
        guard let reference = TMDBReference(metaID: meta.id) else { return meta }
        let detail: TMDBDetail = try await request(
            path: "\(reference.kind.rawValue)/\(reference.id)",
            apiKey: apiKey,
            parameters: ["append_to_response": "external_ids"]
        )
        let stableID = detail.externalIDs?.imdbID.flatMap { $0.isEmpty ? nil : $0 } ?? meta.id
        var videos: [MetaVideo]? = meta.videos
        if reference.kind == .series {
            videos = await seriesVideos(
                apiKey: apiKey,
                tmdbID: reference.id,
                stableSeriesID: stableID,
                seasons: detail.seasons ?? []
            )
        }
        return Meta(
            id: stableID,
            type: reference.kind.harborType,
            name: detail.title ?? detail.name ?? meta.name,
            poster: Self.imageURL(detail.posterPath, size: "w500") ?? meta.poster,
            background: Self.imageURL(detail.backdropPath, size: "w1280") ?? meta.background,
            logo: meta.logo,
            description: detail.overview ?? meta.description,
            releaseInfo: Self.year(detail.releaseDate ?? detail.firstAirDate) ?? meta.releaseInfo,
            imdbRating: Self.rating(detail.voteAverage) ?? meta.imdbRating,
            genres: detail.genres?.map(\.name) ?? meta.genres,
            runtime: Self.runtime(detail.runtime ?? detail.episodeRunTime?.first) ?? meta.runtime,
            country: detail.originCountry?.first ?? meta.country,
            network: detail.networks?.first?.name ?? meta.network,
            videos: videos
        )
    }

    private func seriesVideos(
        apiKey: String,
        tmdbID: Int,
        stableSeriesID: String,
        seasons: [TMDBSeasonSummary]
    ) async -> [MetaVideo] {
        let seasonNumbers = seasons
            .map(\.seasonNumber)
            .filter { $0 > 0 }
            .prefix(30)
        return await withTaskGroup(of: [MetaVideo].self) { group in
            for seasonNumber in seasonNumbers {
                group.addTask { [self] in
                    guard let season: TMDBSeasonDetail = try? await request(
                        path: "tv/\(tmdbID)/season/\(seasonNumber)",
                        apiKey: apiKey
                    ) else { return [] }
                    return season.episodes.map { episode in
                        MetaVideo(
                            id: "\(stableSeriesID):\(seasonNumber):\(episode.episodeNumber)",
                            name: episode.name,
                            title: episode.name,
                            season: seasonNumber,
                            episode: episode.episodeNumber,
                            released: Self.date(episode.airDate),
                            thumbnail: Self.imageURL(episode.stillPath, size: "w780"),
                            overview: episode.overview
                        )
                    }
                }
            }
            var all: [MetaVideo] = []
            for await season in group { all += season }
            return all.sorted {
                ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0)
            }
        }
    }

    private func request<T: Decodable>(
        path: String,
        apiKey: String,
        parameters: [String: String] = [:]
    ) async throws -> T {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw TMDBClientError.invalidKey }
        guard var components = URLComponents(string: "\(Self.apiBase)/\(path)") else {
            throw TMDBClientError.invalidURL
        }
        var query = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        query.append(URLQueryItem(name: "api_key", value: trimmedKey))
        components.queryItems = query.sorted { $0.name < $1.name }
        guard let url = components.url else { throw TMDBClientError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try HTTPResponse.validate(
            response,
            invalidResponse: TMDBClientError.invalidResponse,
            httpError: { TMDBClientError.http($0) }
        )
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TMDBClientError.invalidResponse
        }
    }

    static func imageURL(_ path: String?, size: String) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return "\(imageBase)/\(size)\(path)"
    }

    static func year(_ value: String?) -> String? {
        guard let value, value.count >= 4 else { return nil }
        return String(value.prefix(4))
    }

    static func rating(_ value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        return String(format: "%.1f", value)
    }

    private static func runtime(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(minutes)m"
    }

    private static func date(_ value: String?) -> Date? {
        HarborDate.parseCalendarDate(value)
    }

    private static func normalizedRegion(_ region: String) -> String {
        region.uppercased() == "UK" ? "GB" : region.uppercased()
    }
}
