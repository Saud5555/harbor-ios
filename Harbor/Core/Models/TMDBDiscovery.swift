import Foundation

struct TMDBShelf: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let metas: [Meta]
}

struct TMDBGenreDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let movieGenreID: Int
    let tintHex: String
    let symbol: String

    var collection: TMDBCollectionDefinition {
        TMDBCollectionDefinition(
            id: "genre-\(id)",
            title: name,
            subtitle: "Popular \(name.lowercased()) movies",
            endpoint: .discover(.movie),
            parameters: [
                "with_genres": String(movieGenreID),
                "vote_count.gte": "100",
                "sort_by": "popularity.desc",
            ]
        )
    }

    static let all: [TMDBGenreDefinition] = [
        .init(id: "action", name: "Action", movieGenreID: 28, tintHex: "A43B2B", symbol: "bolt.fill"),
        .init(id: "adventure", name: "Adventure", movieGenreID: 12, tintHex: "26734D", symbol: "map.fill"),
        .init(id: "animation", name: "Animation", movieGenreID: 16, tintHex: "267A8A", symbol: "sparkles"),
        .init(id: "comedy", name: "Comedy", movieGenreID: 35, tintHex: "B77A22", symbol: "face.smiling.fill"),
        .init(id: "crime", name: "Crime", movieGenreID: 80, tintHex: "604431", symbol: "building.columns.fill"),
        .init(id: "documentary", name: "Documentary", movieGenreID: 99, tintHex: "32684A", symbol: "camera.fill"),
        .init(id: "drama", name: "Drama", movieGenreID: 18, tintHex: "355F91", symbol: "theatermasks.fill"),
        .init(id: "family", name: "Family", movieGenreID: 10751, tintHex: "718A2D", symbol: "figure.2.and.child.holdinghands"),
        .init(id: "fantasy", name: "Fantasy", movieGenreID: 14, tintHex: "743E86", symbol: "wand.and.stars"),
        .init(id: "history", name: "History", movieGenreID: 36, tintHex: "805D35", symbol: "clock.fill"),
        .init(id: "horror", name: "Horror", movieGenreID: 27, tintHex: "5B2525", symbol: "moon.stars.fill"),
        .init(id: "mystery", name: "Mystery", movieGenreID: 9648, tintHex: "605E28", symbol: "magnifyingglass"),
        .init(id: "romance", name: "Romance", movieGenreID: 10749, tintHex: "9B3F61", symbol: "heart.fill"),
        .init(id: "scifi", name: "Sci-Fi", movieGenreID: 878, tintHex: "57459B", symbol: "atom"),
        .init(id: "thriller", name: "Thriller", movieGenreID: 53, tintHex: "285A68", symbol: "waveform.path.ecg"),
        .init(id: "western", name: "Western", movieGenreID: 37, tintHex: "986332", symbol: "sun.horizon.fill"),
    ]
}
