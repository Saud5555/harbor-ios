import Foundation

struct Rail: Identifiable {
    let id: String
    let title: String
    let type: String
    var metas: [Meta]
    let base: String
    let catalogId: String
    let extras: [String: String]?
}

struct CatalogSearchResponse {
    enum Status: String {
        case success
        case partial
        case failure
    }

    let results: [Meta]
    let status: Status
    let errorCategory: HarborAnalyticsErrorCategory?
}
