import Combine
import Foundation

@MainActor
final class TMDBCollectionViewModel: ObservableObject {
    @Published private(set) var metas: [Meta] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var requestID = UUID()
    private let client: TMDBCollectionLoading

    init(client: TMDBCollectionLoading = TMDBClient.shared) {
        self.client = client
    }

    func load(definition: TMDBCollectionDefinition, apiKey: String, region: String) async {
        guard !apiKey.isEmpty else { return }
        let requestID = UUID()
        self.requestID = requestID
        isLoading = true
        defer {
            if self.requestID == requestID {
                isLoading = false
            }
        }
        do {
            let loaded = try await client.collection(
                apiKey: apiKey,
                definition: definition,
                region: region
            )
            guard self.requestID == requestID else { return }
            metas = loaded
            errorMessage = nil
        } catch {
            guard self.requestID == requestID else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "TMDB is unavailable."
        }
    }
}
