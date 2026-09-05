import Combine
import Foundation

@MainActor
final class DetailViewModel: ObservableObject {
    @Published private(set) var fullMeta: Meta?
    @Published private(set) var isLoading = false
    @Published private(set) var isBookmarked = false

    let navigation: MetaNavigation

    private let library: LibraryStore
    private let auth: AuthStore
    private let tmdbSettings: TMDBSettingsStore
    private let addonClient: AddonClient
    private let tmdbClient: TMDBDetailLoading
    private var librarySubscription: AnyCancellable?

    init(
        navigation: MetaNavigation,
        library: LibraryStore = .shared,
        auth: AuthStore = .shared,
        tmdbSettings: TMDBSettingsStore = .shared,
        addonClient: AddonClient = .shared,
        tmdbClient: TMDBDetailLoading = TMDBClient.shared
    ) {
        self.navigation = navigation
        self.library = library
        self.auth = auth
        self.tmdbSettings = tmdbSettings
        self.addonClient = addonClient
        self.tmdbClient = tmdbClient

        refreshBookmarkFlag()
        librarySubscription = library.$items.sink { [weak self] _ in
            self?.refreshBookmarkFlag()
        }
    }

    var displayMeta: Meta { fullMeta ?? navigation.meta }

    var story: String? {
        [fullMeta?.description, navigation.meta.description]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var episodeTargetMeta: Meta {
        let meta = displayMeta
        return Meta(
            id: meta.id,
            type: meta.type,
            name: meta.name,
            poster: meta.poster ?? navigation.meta.poster,
            background: meta.background ?? navigation.meta.background,
            logo: meta.logo,
            description: meta.description,
            releaseInfo: meta.releaseInfo,
            imdbRating: meta.imdbRating,
            genres: meta.genres,
            runtime: meta.runtime,
            country: meta.country,
            network: meta.network,
            videos: meta.videos
        )
    }

    var videos: [MetaVideo] {
        (fullMeta?.videos ?? navigation.meta.videos ?? [])
            .sorted { ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0) }
    }

    var seasons: [Int] {
        Array(Set(videos.compactMap(\.season))).sorted()
    }

    func load() async {
        guard fullMeta == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if navigation.meta.id.hasPrefix("tmdb:"), tmdbSettings.hasAPIKey {
            fullMeta = try? await tmdbClient.detailMeta(
                apiKey: tmdbSettings.apiKey,
                meta: navigation.meta
            )
        } else {
            fullMeta = try? await addonClient.metaDetail(
                base: navigation.base,
                type: navigation.meta.type,
                id: navigation.meta.id
            )
        }
        refreshBookmarkFlag()
    }

    func toggleBookmark() async {
        guard let authKey = auth.authKey else { return }
        await library.toggleBookmark(authKey: authKey, meta: displayMeta)
    }

    func isEpisodeWatched(_ video: MetaVideo) -> Bool {
        guard let item = library.item(id: navigation.meta.id),
              let state = item.state else { return false }
        guard (state.flaggedWatched ?? 0) > 0,
              let coordinates = EpisodeCoordinates(videoID: state.videoId) else { return false }
        return video.season == coordinates.season && video.episode == coordinates.episode
    }

    private func refreshBookmarkFlag() {
        isBookmarked = library.item(id: displayMeta.id)?.isBookmarked
            ?? library.item(id: navigation.meta.id)?.isBookmarked
            ?? false
    }
}
