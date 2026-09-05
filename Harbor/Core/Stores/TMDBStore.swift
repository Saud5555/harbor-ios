import Combine
import Foundation

@MainActor
final class TMDBCatalogStore: ObservableObject {
    static let shared = TMDBCatalogStore()

    @Published private(set) var homeTrending: [Meta] = []
    @Published private(set) var shelves: [TMDBShelf] = []
    @Published private(set) var isLoadingHome = false
    @Published private(set) var isLoadingDiscovery = false
    @Published private(set) var errorMessage: String?

    private var homeSignature: String?
    private var discoverySignature: String?
    private var homeRequestID = UUID()
    private var discoveryRequestID = UUID()
    private let client: TMDBCollectionLoading

    init(client: TMDBCollectionLoading = TMDBClient.shared) {
        self.client = client
    }

    func loadHome(apiKey: String, region: String, force: Bool = false) async {
        let signature = "\(apiKey)|\(region)"
        guard !apiKey.isEmpty else {
            homeRequestID = UUID()
            homeTrending = []
            homeSignature = nil
            isLoadingHome = false
            return
        }
        guard force || homeSignature != signature else { return }
        let requestID = UUID()
        homeRequestID = requestID
        isLoadingHome = true
        defer {
            if homeRequestID == requestID {
                isLoadingHome = false
            }
        }
        guard let trending = TMDBCollectionDefinition.requestedCollections().first else { return }
        do {
            let metas = try await client.collection(
                apiKey: apiKey,
                definition: trending,
                region: region
            )
            guard homeRequestID == requestID else { return }
            guard !metas.isEmpty else { return }
            homeTrending = Array(metas.prefix(10))
            homeSignature = signature
            errorMessage = nil
        } catch {
            guard homeRequestID == requestID else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "TMDB is unavailable."
        }
    }

    func loadDiscovery(apiKey: String, region: String, force: Bool = false) async {
        let signature = "\(apiKey)|\(region)"
        guard !apiKey.isEmpty else {
            discoveryRequestID = UUID()
            shelves = []
            discoverySignature = nil
            isLoadingDiscovery = false
            return
        }
        guard force || discoverySignature != signature else { return }
        let requestID = UUID()
        discoveryRequestID = requestID
        isLoadingDiscovery = true
        defer {
            if discoveryRequestID == requestID {
                isLoadingDiscovery = false
            }
        }

        let definitions = TMDBCollectionDefinition.requestedCollections()
        var loaded = Array<[Meta]?>(repeating: nil, count: definitions.count)
        await withTaskGroup(of: (Int, [Meta]).self) { group in
            for (index, definition) in definitions.enumerated() {
                group.addTask {
                    let metas = try? await client.collection(
                        apiKey: apiKey,
                        definition: definition,
                        region: region
                    )
                    return (index, metas ?? [])
                }
            }
            for await (index, metas) in group {
                guard index < loaded.count else { continue }
                loaded[index] = metas
            }
        }

        let populated = definitions.enumerated().compactMap { index, definition -> TMDBShelf? in
            guard let metas = loaded[index], !metas.isEmpty else { return nil }
            return TMDBShelf(
                id: definition.id,
                title: definition.title,
                subtitle: definition.subtitle,
                metas: Array(metas.prefix(24))
            )
        }
        guard discoveryRequestID == requestID else { return }
        guard !populated.isEmpty else {
            errorMessage = "TMDB did not return any discovery collections."
            return
        }
        shelves = populated
        discoverySignature = signature
        errorMessage = nil
    }

    func reset() {
        homeRequestID = UUID()
        discoveryRequestID = UUID()
        homeTrending = []
        shelves = []
        isLoadingHome = false
        isLoadingDiscovery = false
        homeSignature = nil
        discoverySignature = nil
        errorMessage = nil
    }
}
