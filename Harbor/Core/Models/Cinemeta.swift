import Foundation

/// The built-in metadata addon used when a Stremio account has no equivalent.
enum Cinemeta {
    static let manifest = AddonManifest(
        id: "com.linvo.cinemeta",
        name: "Cinemeta",
        version: "3.0",
        description: "Official Stremio metadata for movies and series.",
        logo: "https://images.metahub.space/logo/medium/tt5491982/img",
        background: nil,
        contactEmail: nil,
        types: ["movie", "series"],
        resources: [
            .detailed(AddonResourceDef(name: "catalog", types: ["movie", "series"], idPrefixes: ["tt"])),
            .detailed(AddonResourceDef(name: "meta", types: ["movie", "series"], idPrefixes: ["tt"])),
        ],
        catalogs: [
            AddonCatalogDef(type: "movie", id: "top", name: "Trending Movies", extra: searchExtras),
            AddonCatalogDef(type: "series", id: "top", name: "Trending Series", extra: searchExtras),
            AddonCatalogDef(type: "movie", id: "popular", name: "Popular Movies", extra: nil),
            AddonCatalogDef(type: "series", id: "popular", name: "Popular Series", extra: nil),
            AddonCatalogDef(type: "movie", id: "year", name: "New Movies", extra: nil),
            AddonCatalogDef(type: "series", id: "year", name: "New Series", extra: nil),
        ],
        idPrefixes: ["tt"],
        behaviorHints: nil
    )

    private static let searchExtras = [
        AddonCatalogExtra(name: "search", isRequired: false, options: nil),
        AddonCatalogExtra(name: "skip", isRequired: false, options: nil),
    ]
}
