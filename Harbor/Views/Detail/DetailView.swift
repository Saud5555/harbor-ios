import SwiftUI
import UIKit

struct DetailView: View {
    let nav: MetaNavigation

    @StateObject private var viewModel: DetailViewModel
    @State private var selectedSeason: Int?
    @State private var didLogOpen = false
    @State private var moviePlaybackSessionId = UUID()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(nav: MetaNavigation) {
        self.nav = nav
        _viewModel = StateObject(wrappedValue: DetailViewModel(navigation: nav))
    }

    private var displayMeta: Meta { viewModel.displayMeta }

    private var story: String? {
        viewModel.story
    }

    private var adaptiveLayout: HarborAdaptiveLayout {
        .resolve(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private var episodeTargetMeta: Meta {
        viewModel.episodeTargetMeta
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHeroView(
                    meta: displayMeta,
                    fallbackPoster: nav.meta.poster,
                    background: viewModel.fullMeta?.background ?? nav.meta.background,
                    story: story,
                    layout: adaptiveLayout
                )
                actionRow
                aboutSection
                if displayMeta.type == "series" {
                    episodesSection
                }
                Color.clear.frame(height: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: StreamTarget.self) { target in
            StreamsSheet(target: target)
        }
        .task { await viewModel.load() }
        .onAppear {
            AnalyticsService.shared.setCurrentScreen(.detail, screenClass: "DetailView")
            if !didLogOpen {
                didLogOpen = true
                AnalyticsService.shared.log(
                    displayMeta.type == "series" ? .seriesOpened : .movieOpened,
                    parameters: AnalyticsService.shared.mediaParameters(
                        mediaType: displayMeta.type,
                        mediaId: displayMeta.id,
                        source: nav.source
                    )
                )
            }
        }
    }

    private func toggleBookmark() {
        Task {
            await viewModel.toggleBookmark()
        }
    }

    // MARK: - Sections

    private var actionRow: some View {
        HStack(spacing: 10) {
            if displayMeta.type == "movie" {
                NavigationLink(value: StreamTarget(
                    metaId: displayMeta.id,
                    type: displayMeta.type,
                    title: displayMeta.name,
                    videoId: nil,
                    base: nav.base,
                    metaName: displayMeta.name,
                    poster: displayMeta.poster ?? nav.meta.poster,
                    background: displayMeta.background ?? nav.meta.background,
                    analyticsSource: nav.source,
                    playbackSessionId: moviePlaybackSessionId
                )) {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HarborPrimaryButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    AnalyticsService.shared.log(
                        .playClicked,
                        parameters: AnalyticsService.shared.mediaParameters(
                            mediaType: displayMeta.type,
                            mediaId: displayMeta.id,
                            source: nav.source,
                            playbackSessionId: moviePlaybackSessionId
                        )
                    )
                    let usedSessionId = moviePlaybackSessionId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if moviePlaybackSessionId == usedSessionId {
                            moviePlaybackSessionId = UUID()
                        }
                    }
                })
            }

            Button(action: toggleBookmark) {
                Label(
                    viewModel.isBookmarked ? "Saved" : "Watchlist",
                    systemImage: viewModel.isBookmarked ? "checkmark" : "plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(HarborSecondaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, adaptiveLayout == .pad ? 6 : 14)
    }

    @ViewBuilder
    private var aboutSection: some View {
        if let description = story {
            VStack(alignment: .leading, spacing: 6) {
                HarborSectionHeader(title: "About", subtitle: "Story and details")
                Text(description)
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("harbor.detail.story")
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
    }

    // MARK: - Episodes

    private var videos: [MetaVideo] {
        viewModel.videos
    }

    private var seasons: [Int] {
        viewModel.seasons
    }

    private var activeSeason: Int {
        selectedSeason ?? seasons.first ?? 1
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HarborSectionHeader(
                title: "Episodes",
                subtitle: "Season \(activeSeason)"
            )
                .padding(.horizontal, 16)

            if seasons.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(seasons, id: \.self) { season in
                            HarborFilterPill(
                                title: "Season \(season)",
                                selected: season == activeSeason
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSeason = season
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if viewModel.isLoading && videos.isEmpty {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if videos.isEmpty {
                Text("Episode information is not available for this series.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(videos.filter { ($0.season ?? 1) == activeSeason }) { video in
                        EpisodeRow(
                            video: video,
                            meta: episodeTargetMeta,
                            watched: isEpisodeWatched(video),
                            base: nav.base,
                            source: nav.source
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 18)
    }

    private func isEpisodeWatched(_ video: MetaVideo) -> Bool {
        viewModel.isEpisodeWatched(video)
    }
}
