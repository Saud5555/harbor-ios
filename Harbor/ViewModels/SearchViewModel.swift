import Combine
import Foundation

enum CatalogSearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case movie = "Movies"
    case series = "Series"

    var id: String { rawValue }
    var analyticsValue: String {
        switch self {
        case .all: return "all"
        case .movie: return "movie"
        case .series: return "series"
        }
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [Meta] = []
    @Published private(set) var isSearching = false
    @Published private(set) var hasSearched = false
    @Published var scope: CatalogSearchScope = .all

    private var debounceTask: Task<Void, Never>?
    private var pageTask: Task<Void, Never>?
    private var nextSkip = 50
    private var canLoadMore = false

    var visibleResults: [Meta] {
        switch scope {
        case .all: return results
        case .movie: return results.filter { $0.type == "movie" }
        case .series: return results.filter { $0.type == "series" }
        }
    }

    func queryChanged() {
        debounceTask?.cancel()
        pageTask?.cancel()
        nextSkip = 50
        canLoadMore = false
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            results = []
            hasSearched = false
            isSearching = false
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(query: q, skip: 0, appending: false)
            await loadUntilScopeHasResults(query: q)
        }
    }

    func scopeChanged() {
        guard hasSearched, !isSearching, visibleResults.isEmpty, canLoadMore else { return }
        pageTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        pageTask = Task {
            await loadUntilScopeHasResults(query: q)
        }
    }

    func loadMoreIfNeeded(current: Meta) {
        guard let last = visibleResults.last, current.id == last.id, current.type == last.type,
              !isSearching, canLoadMore else { return }
        pageTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let skip = nextSkip
        pageTask = Task {
            await search(query: q, skip: skip, appending: true)
            await loadUntilScopeHasResults(query: q)
        }
    }

    private func loadUntilScopeHasResults(query requestedQuery: String) async {
        while !Task.isCancelled,
              query.trimmingCharacters(in: .whitespacesAndNewlines) == requestedQuery,
              visibleResults.isEmpty,
              canLoadMore {
            let skip = nextSkip
            await search(query: requestedQuery, skip: skip, appending: true)
        }
    }

    private func search(query requestedQuery: String, skip: Int, appending: Bool) async {
        isSearching = true
        defer {
            if query.trimmingCharacters(in: .whitespacesAndNewlines) == requestedQuery {
                isSearching = false
            }
        }
        hasSearched = true
        let startedAt = Date()
        let operationToken = appending ? nil : AnalyticsService.shared.beginOperation(.catalog)
        defer {
            if let operationToken {
                AnalyticsService.shared.endOperation(operationToken)
            }
        }
        if !appending {
            AnalyticsService.shared.log(.searchSubmitted, parameters: [
                .queryLength: .int(requestedQuery.count),
                .searchScope: .string(scope.analyticsValue),
            ])
        }
        let response = await CatalogStore.shared.search(query: requestedQuery, skip: skip)
        guard !Task.isCancelled,
              query.trimmingCharacters(in: .whitespacesAndNewlines) == requestedQuery
        else { return }
        let found = response.results
        var seen = appending ? Set(results.map { "\($0.id)|\($0.type)" }) : Set<String>()
        let unique = found.filter { meta in
            seen.insert("\(meta.id)|\(meta.type)").inserted
        }
        if appending {
            results += unique
            canLoadMore = !unique.isEmpty
            nextSkip += 50
        } else {
            results = unique
            nextSkip = 50
            canLoadMore = !unique.isEmpty
            logInitialSearchOutcome(
                response: response,
                queryLength: requestedQuery.count,
                durationMs: AnalyticsService.milliseconds(since: startedAt)
            )
        }
    }

    private func logInitialSearchOutcome(
        response: CatalogSearchResponse,
        queryLength: Int,
        durationMs: Int
    ) {
        var parameters: HarborAnalyticsParameters = [
            .queryLength: .int(queryLength),
            .resultCount: .int(response.results.count),
            .searchScope: .string(scope.analyticsValue),
            .searchDurationMs: .int(durationMs),
        ]
        switch response.status {
        case .failure:
            let category = response.errorCategory ?? .unknown
            parameters[.errorType] = .string(category.rawValue)
            AnalyticsService.shared.log(.searchFailed, parameters: parameters)
        case .partial where response.results.isEmpty:
            let category = response.errorCategory ?? .unknown
            parameters[.errorType] = .string(category.rawValue)
            AnalyticsService.shared.log(.searchFailed, parameters: parameters)
        case .success where response.results.isEmpty:
            AnalyticsService.shared.log(.searchNoResults, parameters: parameters)
        case .success, .partial:
            parameters[.resultType] = .string(response.status.rawValue)
            AnalyticsService.shared.log(.searchResultsReturned, parameters: parameters)
        }
    }
}
