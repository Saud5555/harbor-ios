import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var rails: [Rail] = []
    @Published private(set) var isLoading = false

    private var loadedOnce = false
    private var requestID = UUID()

    func loadIfNeeded() async {
        guard !loadedOnce else { return }
        await load()
    }

    func load(forceAddonRefresh: Bool = false) async {
        let requestID = UUID()
        self.requestID = requestID
        isLoading = true
        defer {
            if self.requestID == requestID {
                isLoading = false
                loadedOnce = true
            }
        }

        let addons = await CatalogStore.shared.gatherAddons(
            authKey: AuthStore.shared.authKey,
            force: forceAddonRefresh
        )
        let built = CatalogStore.shared.buildRails(from: addons, maxRails: 10)
        guard !built.isEmpty else { return }

        var pages = Array(repeating: [Meta](), count: built.count)
        var publishedInitialRail = false
        await withTaskGroup(of: (Int, [Meta]).self) { group in
            for (index, rail) in built.enumerated() {
                group.addTask {
                    let metas = try? await AddonClient.shared.catalogPage(
                        base: rail.base,
                        type: rail.type,
                        id: rail.catalogId,
                        extras: rail.extras ?? [:]
                    )
                    return (index, metas ?? [])
                }
            }
            for await (index, metas) in group {
                guard self.requestID == requestID else { return }
                guard index < pages.count else { continue }
                pages[index] = Array(metas.prefix(24))
                if rails.isEmpty, !publishedInitialRail,
                   built[index].base == AddonClient.cinemetaBase,
                   !pages[index].isEmpty {
                    var firstRail = built[index]
                    firstRail.metas = pages[index]
                    rails = [firstRail]
                    publishedInitialRail = true
                }
            }
        }

        let loaded = built.enumerated().compactMap { index, rail -> Rail? in
            guard !pages[index].isEmpty else { return nil }
            var populated = rail
            populated.metas = pages[index]
            return populated
        }
        guard self.requestID == requestID else { return }
        // Keep the last good catalog snapshot if a refresh temporarily fails.
        guard !loaded.isEmpty else { return }
        rails = loaded
    }
}
