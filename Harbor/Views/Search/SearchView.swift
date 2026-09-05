import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var browseModel = HomeViewModel()
    @ObservedObject private var tmdbSettings = TMDBSettingsStore.shared
    @ObservedObject private var tmdbCatalog = TMDBCatalogStore.shared
    @AppStorage("harbor.region") private var region = "US"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 148 : 104), spacing: 14)]
    }

    private var horizontalPadding: CGFloat { horizontalSizeClass == .regular ? 28 : 16 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    HarborPageHeader(
                        title: "Discover",
                        eyebrow: "Browse Harbor",
                        subtitle: "Find the next story worth watching"
                    )
                    .accessibilityIdentifier("harbor.discover.header")

                    HarborSearchField(prompt: "Movies, series and more", text: $viewModel.query)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CatalogSearchScope.allCases) { scope in
                                HarborFilterPill(
                                    title: scope.rawValue,
                                    selected: viewModel.scope == scope
                                ) {
                                    viewModel.scope = scope
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Group {
                    if viewModel.visibleResults.isEmpty {
                        emptyState
                    } else {
                        resultsGrid
                    }
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MetaNavigation.self) { nav in
                DetailView(nav: nav)
            }
            .onChange(of: viewModel.query) { _ in
                viewModel.queryChanged()
            }
            .onChange(of: viewModel.scope) { _ in
                viewModel.scopeChanged()
            }
            .onChange(of: tmdbSettings.apiKey) { apiKey in
                Task {
                    if apiKey.isEmpty {
                        await browseModel.loadIfNeeded()
                    } else {
                        await tmdbCatalog.loadDiscovery(apiKey: apiKey, region: region, force: true)
                    }
                }
            }
            .onChange(of: region) { value in
                Task {
                    await tmdbCatalog.loadDiscovery(
                        apiKey: tmdbSettings.apiKey,
                        region: value,
                        force: true
                    )
                }
            }
            .onAppear {
                AnalyticsService.shared.setCurrentScreen(.search, screenClass: "SearchView")
            }
            .task {
                if tmdbSettings.hasAPIKey {
                    await tmdbCatalog.loadDiscovery(apiKey: tmdbSettings.apiKey, region: region)
                } else {
                    await browseModel.loadIfNeeded()
                }
            }
        }
    }

    private var resultsGrid: some View {
        ScrollView {
            HarborSectionHeader(
                title: viewModel.query.isEmpty ? "Explore" : "Search Results",
                subtitle: viewModel.visibleResults.isEmpty
                    ? nil
                    : "\(viewModel.visibleResults.count) titles"
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.visibleResults.enumerated()), id: \.element.id) { index, meta in
                    NavigationLink(value: MetaNavigation(meta: meta, base: nil, source: .search)) {
                        PosterCard(
                            meta: meta,
                            width: horizontalSizeClass == .regular ? 148 : 104,
                            showTypeBadge: true
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        var parameters = AnalyticsService.shared.mediaParameters(
                            mediaType: meta.type,
                            mediaId: meta.id,
                            source: .search
                        )
                        parameters[.resultPosition] = .int(index + 1)
                        parameters[.searchScope] = .string(viewModel.scope.analyticsValue)
                        AnalyticsService.shared.log(.searchResultClicked, parameters: parameters)
                    })
                    .onAppear {
                        viewModel.loadMoreIfNeeded(current: meta)
                    }
                }
            }
            .padding(horizontalPadding)

            if viewModel.isSearching {
                ProgressView().tint(Theme.accent).padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isSearching {
            VStack(spacing: 12) {
                ProgressView().tint(Theme.accent)
                Text("Searching")
                    .foregroundColor(Theme.textSecondary)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.hasSearched {
            ContentUnavailableCompat(
                icon: "magnifyingglass",
                title: "No results",
                message: viewModel.scope == .all
                    ? "Nothing matched \"\(viewModel.query)\"."
                    : "No \(viewModel.scope.rawValue.lowercased()) matched \"\(viewModel.query)\"."
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if tmdbSettings.hasAPIKey {
                        HarborSectionHeader(
                            title: "Explore the catalog",
                            subtitle: "Curated with TMDB for \(region)"
                        )
                        .padding(.horizontal, horizontalPadding)

                        if let featured = tmdbCatalog.shelves.first?.metas.first {
                            discoveryFeature(meta: featured, base: nil)
                        }

                        TMDBGenreRow()

                        ForEach(tmdbCatalog.shelves) { shelf in
                            AdaptiveMediaRail(
                                title: shelf.title,
                                subtitle: shelf.subtitle,
                                metas: shelf.metas,
                                source: .search,
                                ranked: shelf.id == "trending-week"
                            )
                        }

                        if tmdbCatalog.isLoadingDiscovery && tmdbCatalog.shelves.isEmpty {
                            ProgressView()
                                .tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 70)
                        } else if let error = tmdbCatalog.errorMessage,
                                  tmdbCatalog.shelves.isEmpty {
                            ContentUnavailableCompat(
                                icon: "wifi.exclamationmark",
                                title: "Couldn’t load Discover",
                                message: error
                            )
                            .frame(minHeight: 260)
                        }
                    } else {
                        TMDBKeyPrompt()
                            .padding(.horizontal, horizontalPadding)

                        ForEach(Array(browseModel.rails.prefix(2))) { rail in
                            RailRow(rail: rail, source: .search)
                        }

                        if browseModel.isLoading && browseModel.rails.isEmpty {
                            ProgressView()
                                .tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 50)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func discoveryFeature(meta: Meta, base: String?) -> some View {
        NavigationLink(value: MetaNavigation(meta: meta, base: base, source: .search)) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: meta.background ?? meta.poster ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Theme.surfaceRaised
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: horizontalSizeClass == .regular ? 320 : 220)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text("FEATURED DISCOVERY")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2)
                        .foregroundColor(Theme.accent)
                    Text(meta.name)
                        .font(.system(size: 25, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Label("Explore", systemImage: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(16)
            }
            .frame(height: horizontalSizeClass == .regular ? 320 : 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, horizontalPadding)
        }
        .buttonStyle(.plain)
    }

}
