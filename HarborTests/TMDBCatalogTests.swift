import Foundation
import XCTest
@testable import Harbor

final class TMDBCatalogTests: XCTestCase {
    func testRequestedDiscoverCollectionsMatchProductContract() {
        let collections = TMDBCollectionDefinition.requestedCollections(
            now: Date(timeIntervalSince1970: 1_788_134_400)
        )
        XCTAssertEqual(
            collections.map(\.title),
            [
                "Trending This Week",
                "Top Rated",
                "Award Winning",
                "Top Rated History",
                "New Documentary Series",
                "Top Rated Action",
                "New in Drama",
                "Adventure + Sci-Fi",
                "Best of the 80s",
                "Documentary + Animation",
                "Cult Classics",
            ]
        )
        XCTAssertEqual(collections.count, Set(collections.map(\.id)).count)
    }

    func testStreamingProviderCatalogIncludesNetflixUSProviderID() throws {
        let netflix = try XCTUnwrap(TMDBStreamingProvider.all.first { $0.id == "netflix" })
        XCTAssertEqual(netflix.name, "Netflix")
        XCTAssertEqual(netflix.providerIDs, [8])
    }

    func testGenreCatalogContainsRequestedCombinationGenres() {
        let genres = Dictionary(uniqueKeysWithValues: TMDBGenreDefinition.all.map { ($0.name, $0.movieGenreID) })
        XCTAssertEqual(genres["Adventure"], 12)
        XCTAssertEqual(genres["Animation"], 16)
        XCTAssertEqual(genres["Documentary"], 99)
        XCTAssertEqual(genres["Drama"], 18)
        XCTAssertEqual(genres["History"], 36)
        XCTAssertEqual(genres["Sci-Fi"], 878)
    }

    @MainActor
    func testCatalogStoreDiscardsAStaleRegionResponse() async {
        let store = TMDBCatalogStore(client: DelayedTMDBCollectionLoader())

        let slowRequest = Task {
            await store.loadHome(apiKey: "key", region: "US", force: true)
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
        let currentRequest = Task {
            await store.loadHome(apiKey: "key", region: "GB", force: true)
        }
        await slowRequest.value
        await currentRequest.value

        XCTAssertEqual(store.homeTrending.first?.name, "GB result")
        XCTAssertFalse(store.isLoadingHome)
    }
}

private final class DelayedTMDBCollectionLoader: @unchecked Sendable, TMDBCollectionLoading {
    func collection(
        apiKey _: String,
        definition _: TMDBCollectionDefinition,
        region: String
    ) async throws -> [Meta] {
        let delay: UInt64 = region == "US" ? 100_000_000 : 1_000_000
        try await Task.sleep(nanoseconds: delay)
        return [Meta(
            id: "tmdb:movie:1",
            type: "movie",
            name: "\(region) result",
            poster: nil,
            background: nil,
            logo: nil,
            description: nil,
            releaseInfo: nil,
            imdbRating: nil,
            genres: nil,
            runtime: nil,
            country: nil,
            network: nil,
            videos: nil
        )]
    }
}
