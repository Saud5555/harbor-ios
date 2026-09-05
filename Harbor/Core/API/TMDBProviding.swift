import Foundation

protocol TMDBKeyValidating: AnyObject, Sendable {
    func validate(apiKey: String) async throws
}

protocol TMDBCollectionLoading: AnyObject, Sendable {
    func collection(
        apiKey: String,
        definition: TMDBCollectionDefinition,
        region: String
    ) async throws -> [Meta]
}

protocol TMDBServiceLoading: AnyObject, Sendable {
    func serviceCatalog(
        apiKey: String,
        provider: TMDBStreamingProvider,
        region: String,
        page: Int
    ) async throws -> TMDBServiceCatalog
}

extension TMDBServiceLoading {
    func serviceCatalog(
        apiKey: String,
        provider: TMDBStreamingProvider,
        region: String
    ) async throws -> TMDBServiceCatalog {
        try await serviceCatalog(
            apiKey: apiKey,
            provider: provider,
            region: region,
            page: 1
        )
    }
}

protocol TMDBDetailLoading: AnyObject, Sendable {
    func detailMeta(apiKey: String, meta: Meta) async throws -> Meta
}

extension TMDBClient:
    TMDBKeyValidating,
    TMDBCollectionLoading,
    TMDBServiceLoading,
    TMDBDetailLoading {}
