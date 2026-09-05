import Foundation

struct TMDBReference {
    let kind: TMDBMediaKind
    let id: Int

    init?(metaID: String) {
        let components = metaID.split(separator: ":")
        guard components.count == 3,
              components[0] == "tmdb",
              let kind = TMDBMediaKind(rawValue: String(components[1])),
              let id = Int(components[2])
        else { return nil }
        self.kind = kind
        self.id = id
    }
}

struct TMDBConfiguration: Decodable {}

struct TMDBPage<Item: Decodable>: Decodable {
    let results: [Item]
}

struct TMDBCatalogItem: Decodable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let genreIDs: [Int]?
    let originCountry: [String]?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case mediaType = "media_type"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIDs = "genre_ids"
        case originCountry = "origin_country"
    }

    var resolvedKind: TMDBMediaKind? {
        switch mediaType {
        case "movie": return .movie
        case "tv": return .series
        default: return nil
        }
    }

    func meta(kind: TMDBMediaKind) -> Meta? {
        guard let displayName = title ?? name, !displayName.isEmpty else { return nil }
        return Meta(
            id: "tmdb:\(kind.rawValue):\(id)",
            type: kind.harborType,
            name: displayName,
            poster: TMDBClient.imageURL(posterPath, size: "w500"),
            background: TMDBClient.imageURL(backdropPath, size: "w1280"),
            logo: nil,
            description: overview,
            releaseInfo: TMDBClient.year(releaseDate ?? firstAirDate),
            imdbRating: TMDBClient.rating(voteAverage),
            genres: genreIDs?.compactMap { TMDBGenre.name(id: $0, kind: kind) },
            runtime: nil,
            country: originCountry?.first,
            network: nil,
            videos: nil
        )
    }
}

enum TMDBGenre {
    private static let movie: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History",
        27: "Horror", 10402: "Music", 9648: "Mystery", 10749: "Romance", 878: "Sci-Fi",
        53: "Thriller", 10752: "War", 37: "Western",
    ]
    private static let series: [Int: String] = [
        10759: "Action & Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 10762: "Kids", 9648: "Mystery",
        10763: "News", 10764: "Reality", 10765: "Sci-Fi & Fantasy", 10766: "Soap",
        10767: "Talk", 10768: "War & Politics", 37: "Western",
    ]

    static func name(id: Int, kind: TMDBMediaKind) -> String? {
        kind == .movie ? movie[id] : series[id]
    }
}

struct TMDBDetail: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let originCountry: [String]?
    let genres: [TMDBNamedValue]?
    let networks: [TMDBNamedValue]?
    let seasons: [TMDBSeasonSummary]?
    let externalIDs: TMDBExternalIDs?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, runtime, genres, networks, seasons
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case episodeRunTime = "episode_run_time"
        case originCountry = "origin_country"
        case externalIDs = "external_ids"
    }
}

struct TMDBNamedValue: Decodable {
    let name: String
}

struct TMDBExternalIDs: Decodable {
    let imdbID: String?

    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
    }
}

struct TMDBSeasonSummary: Decodable {
    let seasonNumber: Int

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
    }
}

struct TMDBSeasonDetail: Decodable {
    let episodes: [TMDBEpisode]
}

struct TMDBEpisode: Decodable {
    let episodeNumber: Int
    let name: String?
    let overview: String?
    let airDate: String?
    let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case name, overview
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }
}
