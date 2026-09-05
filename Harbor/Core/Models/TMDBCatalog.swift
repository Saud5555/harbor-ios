import Foundation

enum TMDBMediaKind: String, CaseIterable, Sendable {
    case movie
    case series = "tv"

    var harborType: String {
        switch self {
        case .movie: return "movie"
        case .series: return "series"
        }
    }
}

struct TMDBStreamingProvider: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let providerIDs: [Int]
    let tintHex: String
    let shortMark: String

    static let all: [TMDBStreamingProvider] = [
        .init(id: "netflix", name: "Netflix", providerIDs: [8], tintHex: "E50914", shortMark: "N"),
        .init(id: "disney", name: "Disney+", providerIDs: [337], tintHex: "0E47A1", shortMark: "D+"),
        .init(id: "prime", name: "Prime Video", providerIDs: [9, 119], tintHex: "00A8E1", shortMark: "prime"),
        .init(id: "apple", name: "Apple TV+", providerIDs: [350], tintHex: "FFFFFF", shortMark: "tv+"),
        .init(id: "max", name: "Max", providerIDs: [1899, 384], tintHex: "9B6CFF", shortMark: "max"),
        .init(id: "hulu", name: "Hulu", providerIDs: [15], tintHex: "1CE783", shortMark: "hulu"),
    ]
}

struct TMDBServiceCatalog {
    let movies: [Meta]
    let series: [Meta]
}

struct TMDBCollectionDefinition: Identifiable, Sendable {
    enum Endpoint: Sendable {
        case trendingAll
        case topRated(TMDBMediaKind)
        case discover(TMDBMediaKind)
    }

    let id: String
    let title: String
    let subtitle: String
    let endpoint: Endpoint
    let parameters: [String: String]

    static func requestedCollections(now: Date = Date()) -> [TMDBCollectionDefinition] {
        let recentDocumentaryStart = dateString(daysFrom: now, offset: -540)
        let recentDramaStart = dateString(daysFrom: now, offset: -365)
        let today = dateString(daysFrom: now, offset: 0)

        return [
            .init(
                id: "trending-week",
                title: "Trending This Week",
                subtitle: "What people are watching now",
                endpoint: .trendingAll,
                parameters: [:]
            ),
            .init(
                id: "top-rated",
                title: "Top Rated",
                subtitle: "The audience favorites",
                endpoint: .topRated(.movie),
                parameters: [:]
            ),
            .init(
                id: "award-winning",
                title: "Award Winning",
                subtitle: "Acclaimed modern cinema",
                endpoint: .discover(.movie),
                parameters: [
                    "vote_average.gte": "8.0",
                    "vote_count.gte": "2500",
                    "sort_by": "vote_average.desc",
                ]
            ),
            .init(
                id: "top-history",
                title: "Top Rated History",
                subtitle: "Remarkable stories from the past",
                endpoint: .discover(.movie),
                parameters: [
                    "with_genres": "36",
                    "vote_average.gte": "7.2",
                    "vote_count.gte": "300",
                    "sort_by": "vote_average.desc",
                ]
            ),
            .init(
                id: "new-documentary-series",
                title: "New Documentary Series",
                subtitle: "Recent real stories",
                endpoint: .discover(.series),
                parameters: [
                    "with_genres": "99",
                    "first_air_date.gte": recentDocumentaryStart,
                    "first_air_date.lte": today,
                    "vote_count.gte": "20",
                    "sort_by": "popularity.desc",
                ]
            ),
            .init(
                id: "top-action",
                title: "Top Rated Action",
                subtitle: "Big-screen adrenaline",
                endpoint: .discover(.movie),
                parameters: [
                    "with_genres": "28",
                    "vote_average.gte": "7.2",
                    "vote_count.gte": "1200",
                    "sort_by": "vote_average.desc",
                ]
            ),
            .init(
                id: "new-drama",
                title: "New in Drama",
                subtitle: "Fresh dramatic releases",
                endpoint: .discover(.movie),
                parameters: [
                    "with_genres": "18",
                    "primary_release_date.gte": recentDramaStart,
                    "primary_release_date.lte": today,
                    "vote_count.gte": "75",
                    "sort_by": "popularity.desc",
                ]
            ),
            .init(
                id: "adventure-scifi",
                title: "Adventure + Sci-Fi",
                subtitle: "Journeys beyond the known",
                endpoint: .discover(.movie),
                parameters: [
                    "with_genres": "12|878",
                    "vote_average.gte": "6.8",
                    "vote_count.gte": "800",
                    "sort_by": "popularity.desc",
                ]
            ),
            .init(
                id: "best-80s",
                title: "Best of the 80s",
                subtitle: "Essentials from 1980–1989",
                endpoint: .discover(.movie),
                parameters: [
                    "primary_release_date.gte": "1980-01-01",
                    "primary_release_date.lte": "1989-12-31",
                    "vote_average.gte": "7.2",
                    "vote_count.gte": "500",
                    "sort_by": "vote_count.desc",
                ]
            ),
            .init(
                id: "documentary-animation",
                title: "Documentary + Animation",
                subtitle: "True stories, illustrated",
                endpoint: .discover(.movie),
                parameters: [
                    "with_genres": "99|16",
                    "vote_count.gte": "30",
                    "sort_by": "popularity.desc",
                ]
            ),
            .init(
                id: "cult-classics",
                title: "Cult Classics",
                subtitle: "Beloved and unforgettable",
                endpoint: .discover(.movie),
                parameters: [
                    "primary_release_date.lte": "2005-12-31",
                    "vote_average.gte": "7.5",
                    "vote_count.gte": "600",
                    "sort_by": "vote_count.desc",
                ]
            ),
        ]
    }

    private static func dateString(daysFrom date: Date, offset: Int) -> String {
        HarborDate.calendarDate(byAddingDays: offset, to: date)
    }
}
