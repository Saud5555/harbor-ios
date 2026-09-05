import SwiftUI

struct TMDBCollectionView: View {
    let definition: TMDBCollectionDefinition

    @StateObject private var viewModel = TMDBCollectionViewModel()
    @ObservedObject private var settings = TMDBSettingsStore.shared
    @AppStorage("harbor.region") private var region = "US"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 148 : 108), spacing: 14)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HarborPageHeader(
                    title: definition.title,
                    eyebrow: "Discover",
                    subtitle: definition.subtitle
                )
                .padding(.horizontal, 20)

                collectionContent
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle(definition.title)
        .harborNavigationChrome()
        .task {
            await viewModel.load(
                definition: definition,
                apiKey: settings.apiKey,
                region: region
            )
        }
    }

    @ViewBuilder
    private var collectionContent: some View {
        if viewModel.isLoading && viewModel.metas.isEmpty {
            ProgressView().tint(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
        } else if let error = viewModel.errorMessage, viewModel.metas.isEmpty {
            ContentUnavailableCompat(
                icon: "wifi.exclamationmark",
                title: "Couldn’t load collection",
                message: error
            )
            .frame(minHeight: 320)
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(viewModel.metas) { meta in
                    NavigationLink(value: MetaNavigation(meta: meta, base: nil, source: .search)) {
                        PosterCard(meta: meta, width: horizontalSizeClass == .regular ? 148 : 108)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct TMDBServiceView: View {
    private enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case series = "Series"

        var id: String { rawValue }
    }

    let provider: TMDBStreamingProvider

    @StateObject private var viewModel = TMDBServiceViewModel()
    @ObservedObject private var settings = TMDBSettingsStore.shared
    @AppStorage("harbor.region") private var region = "US"
    @State private var scope: Scope = .all
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                serviceHeader
                scopePicker
                catalogContent
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle(provider.name)
        .harborNavigationChrome()
        .task {
            await viewModel.load(
                provider: provider,
                apiKey: settings.apiKey,
                region: region
            )
        }
    }

    @ViewBuilder
    private var catalogContent: some View {
        if !settings.hasAPIKey {
            TMDBKeyPrompt()
                .padding(.horizontal, 20)
        } else if viewModel.isLoading && viewModel.catalog.movies.isEmpty
                    && viewModel.catalog.series.isEmpty {
            ProgressView().tint(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 90)
        } else if let error = viewModel.errorMessage,
                  viewModel.catalog.movies.isEmpty,
                  viewModel.catalog.series.isEmpty {
            ContentUnavailableCompat(
                icon: "wifi.exclamationmark",
                title: "Couldn’t load \(provider.name)",
                message: error
            )
            .frame(minHeight: 320)
        } else {
            catalogRails
        }
    }

    @ViewBuilder
    private var catalogRails: some View {
        if scope != .series, !viewModel.catalog.movies.isEmpty {
            AdaptiveMediaRail(
                title: "Top 10 Movies on \(provider.name)",
                subtitle: "Ranked by TMDB popularity in \(region)",
                metas: viewModel.catalog.movies,
                source: .home,
                ranked: true
            )
        }
        if scope != .movies, !viewModel.catalog.series.isEmpty {
            AdaptiveMediaRail(
                title: "Top 10 Series on \(provider.name)",
                subtitle: "Ranked by TMDB popularity in \(region)",
                metas: viewModel.catalog.series,
                source: .home,
                ranked: true
            )
        }
        if scope != .series, viewModel.catalog.movies.count > 10 {
            AdaptiveMediaRail(
                title: "More Movies",
                metas: Array(viewModel.catalog.movies.dropFirst(10)),
                source: .home
            )
        }
        if scope != .movies, viewModel.catalog.series.count > 10 {
            AdaptiveMediaRail(
                title: "More Series",
                metas: Array(viewModel.catalog.series.dropFirst(10)),
                source: .home
            )
        }
    }

    private var serviceHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(harborHex: provider.tintHex).opacity(0.5), Theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("POPULAR ON")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.2)
                    .foregroundColor(.white.opacity(0.65))
                Text(provider.name)
                    .font(.system(size: horizontalSizeClass == .regular ? 46 : 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Popular movies and series available on \(provider.name) right now in \(region), ranked by TMDB popularity.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.72))
                Text("Streaming availability data by JustWatch")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(22)
        }
        .frame(height: horizontalSizeClass == .regular ? 230 : 190)
    }

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Scope.allCases) { item in
                    HarborFilterPill(title: item.rawValue, selected: scope == item) {
                        scope = item
                    }
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
        }
    }
}
