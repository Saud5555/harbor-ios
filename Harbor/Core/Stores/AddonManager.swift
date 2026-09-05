import Combine
import Foundation

@MainActor
final class AddonManager: ObservableObject {
    static let shared = AddonManager()

    /// Cloud-only collection (no synthesized Cinemeta).
    @Published private(set) var cloudAddons: [Addon] = []
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private init() {}

    var syncedStreamAddons: [Addon] {
        cloudAddons.filter { $0.manifest.advertises(resource: "stream") }
    }

    var syncedSubtitleAddons: [Addon] {
        cloudAddons.filter { $0.manifest.advertises(resource: "subtitles") }
    }

    func hasEmbeddedDebridConfiguration(_ addon: Addon) -> Bool {
        let transport = (addon.transportUrl.removingPercentEncoding ?? addon.transportUrl).lowercased()
        return DebridProvider.allCases.contains { transport.contains("\($0.queryName)=") }
    }

    func applySyncedAddons(_ addons: [Addon], authKey: String) {
        guard AuthStore.shared.authKey == authKey else { return }
        cloudAddons = addons
        errorMessage = nil
    }

    func reset() {
        cloudAddons = []
        isLoading = false
        statusMessage = nil
        errorMessage = nil
    }

    func reload(authKey: String) async {
        guard AuthStore.shared.authKey == authKey else { return }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer {
            if AuthStore.shared.authKey == authKey {
                isLoading = false
            }
        }
        do {
            let loaded = try await AddonClient.shared.addonCollection(authKey: authKey)
            guard AuthStore.shared.authKey == authKey else { return }
            cloudAddons = loaded
            CatalogStore.shared.invalidate()
        } catch {
            guard AuthStore.shared.authKey == authKey else { return }
            errorMessage = error.localizedDescription
        }
    }

    func remove(authKey: String, addon: Addon) async {
        guard AuthStore.shared.authKey == authKey, isRemovable(addon) else { return }
        errorMessage = nil
        statusMessage = nil
        let updated = cloudAddons.filter { $0.id != addon.id }
        do {
            try await AddonClient.shared.setAddonCollection(authKey: authKey, addons: updated)
            guard AuthStore.shared.authKey == authKey else { return }
            cloudAddons = updated
            statusMessage = "Removed \(addon.displayName)"
            CatalogStore.shared.invalidate()
        } catch {
            guard AuthStore.shared.authKey == authKey else { return }
            errorMessage = error.localizedDescription
        }
    }

    func installFromURL(authKey: String, rawURL: String) async -> Bool {
        guard AuthStore.shared.authKey == authKey else { return false }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsed.host != nil
        else {
            errorMessage = "Enter a full manifest URL (https://…)"
            return false
        }
        let transportURL = AddonClient.baseURL(for: trimmed) + "/manifest.json"
        return await install(
            authKey: authKey,
            transportURL: transportURL,
            replacing: {
                AddonClient.baseURL(for: $0.transportUrl) == AddonClient.baseURL(for: transportURL)
            },
            successMessage: { "Installed \($0.name)" },
            errorPrefix: "Could not install addon"
        )
    }

    func installTorrentio(authKey: String) async -> Bool {
        guard AuthStore.shared.authKey == authKey else { return false }
        let configParts = DebridProvider.allCases.compactMap { provider -> String? in
            guard let key = DebridProvider.loadKey(provider), !key.isEmpty else { return nil }
            return "\(provider.queryName)=\(key.trimmingCharacters(in: .whitespaces))"
        }
        let base = "https://torrentio.strem.fun"
        let transportUrl = configParts.isEmpty ? base + "/manifest.json" : base + "/" + configParts.joined(separator: "|") + "/manifest.json"

        return await install(
            authKey: authKey,
            transportURL: transportUrl,
            replacing: { $0.transportUrl.lowercased().contains("torrentio.strem.fun") },
            successMessage: { _ in
                configParts.isEmpty
                    ? "Installed Torrentio (no debrid keys)"
                    : "Installed Torrentio with \(configParts.count) debrid key(s)"
            },
            errorPrefix: "Torrentio install failed"
        )
    }

    func isRemovable(_ addon: Addon) -> Bool {
        !(addon.flags?.protected ?? false) && !(addon.flags?.official ?? false)
    }

    private func install(
        authKey: String,
        transportURL: String,
        replacing shouldReplace: (Addon) -> Bool,
        successMessage: (AddonManifest) -> String,
        errorPrefix: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer {
            if AuthStore.shared.authKey == authKey {
                isLoading = false
            }
        }

        do {
            let manifest = try await AddonClient.shared.manifest(transportUrl: transportURL)
            guard AuthStore.shared.authKey == authKey else { return false }
            var updated = cloudAddons.filter { !shouldReplace($0) }
            updated.append(Addon(
                transportUrl: transportURL,
                manifest: manifest,
                flags: AddonFlags(official: false, protected: false)
            ))
            try await AddonClient.shared.setAddonCollection(authKey: authKey, addons: updated)
            guard AuthStore.shared.authKey == authKey else { return false }
            cloudAddons = updated
            statusMessage = successMessage(manifest)
            CatalogStore.shared.invalidate()
            return true
        } catch {
            guard AuthStore.shared.authKey == authKey else { return false }
            errorMessage = "\(errorPrefix): \(error.localizedDescription)"
            return false
        }
    }
}
