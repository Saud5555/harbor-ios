import Combine
import Foundation

@MainActor
final class TMDBServiceViewModel: ObservableObject {
    @Published private(set) var catalog = TMDBServiceCatalog(movies: [], series: [])
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var requestID = UUID()
    private let client: TMDBServiceLoading

    init(client: TMDBServiceLoading = TMDBClient.shared) {
        self.client = client
    }

    func load(provider: TMDBStreamingProvider, apiKey: String, region: String) async {
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
            let loaded = try await client.serviceCatalog(
                apiKey: apiKey,
                provider: provider,
                region: region
            )
            guard self.requestID == requestID else { return }
            catalog = loaded
            errorMessage = nil
        } catch {
            guard self.requestID == requestID else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "TMDB is unavailable."
        }
    }
}
