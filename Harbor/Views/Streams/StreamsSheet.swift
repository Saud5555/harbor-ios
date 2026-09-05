import SwiftUI

private struct PlaybackSelection: Identifiable {
    let id = UUID()
    let url: URL
    let requestedAt: Date
    let target: StreamTarget
}

struct StreamsSheet: View {
    let target: StreamTarget

    @StateObject private var engine = StreamEngine()
    @State private var playbackSelection: PlaybackSelection?
    @State private var playbackAttemptCount = 0
    @State private var selectedAddonId: String?

    private let tierColors: [String: Color] = [
        "4K": .purple,
        "1080p": Theme.accent,
        "720p": .teal,
        "SD": Color(white: 0.45),
        "?": Color(white: 0.3),
    ]

    var body: some View {
        VStack(spacing: 0) {
            streamHeader

            Group {
                if engine.isLoading && engine.streams.isEmpty {
                    loadingState
                } else if displayedStreams.isEmpty {
                    emptyState
                } else {
                    streamList
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .harborNavigationChrome()
        .task(id: target) {
            await engine.load(target: target)
        }
        .onAppear {
            AnalyticsService.shared.setCurrentScreen(.streams, screenClass: "StreamsSheet")
        }
        .fullScreenCover(item: $playbackSelection) { selection in
            PlayerScreen(
                streamURL: selection.url,
                title: selection.target.title,
                target: selection.target,
                playbackRequestedAt: selection.requestedAt
            )
        }
    }

    private var subtitle: String {
        let done = engine.progress.filter {
            if case .done = $0.state { return true }
            return false
        }.count
        return "\(target.title) · \(displayedStreams.count) sources · \(done)/\(engine.progress.count) addons"
    }

    private var displayedStreams: [ScoredStream] {
        guard let selectedAddonId else { return engine.streams }
        return engine.streams.filter { $0.raw.addonId == selectedAddonId }
    }

    private var selectedAddonName: String {
        guard let selectedAddonId else { return "All addons" }
        return engine.availableAddons.first { $0.id == selectedAddonId }?.displayName ?? "Addon"
    }

    private var addonFilter: some View {
        Menu {
            Button {
                selectedAddonId = nil
            } label: {
                if selectedAddonId == nil {
                    Label("All addons", systemImage: "checkmark")
                } else {
                    Text("All addons")
                }
            }

            ForEach(engine.availableAddons) { addon in
                Button {
                    selectedAddonId = addon.id
                } label: {
                    if selectedAddonId == addon.id {
                        Label(addon.displayName, systemImage: "checkmark")
                    } else {
                        Text(addon.displayName)
                    }
                }
            }
        } label: {
            Label(selectedAddonName, systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Theme.surface.opacity(0.9), in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .disabled(engine.availableAddons.count < 2)
    }

    private var streamHeader: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: target.background ?? target.poster ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Theme.surfaceRaised, Theme.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.2), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("CHOOSE A SOURCE")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2.1)
                    .foregroundColor(Theme.accent)
                Text(target.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .tracking(-0.6)
                    .lineLimit(2)
                HStack {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    addonFilter
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(height: 180)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Theme.accent)
            Text("Querying \(engine.progress.count) addons")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: engine.errorMessage == nil ? "water.waves.slash" : "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text(filteredEmptyTitle)
                .font(.system(size: 22, weight: .bold, design: .serif))
            Text(filteredEmptyMessage)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        if engine.errorMessage != nil { return "Could not load streams" }
        if engine.progress.isEmpty { return "No stream addons available" }
        return "No streams found"
    }

    private var emptyMessage: String {
        if let error = engine.errorMessage { return error }
        if engine.progress.isEmpty {
            return "Harbor automatically uses streaming addons installed in your Stremio account. Install or configure one in Stremio on any device, then try again."
        }
        return "Your \(engine.progress.count) synced streaming addon(s) returned no sources for this title."
    }

    private var filteredEmptyTitle: String {
        if selectedAddonId != nil, engine.streams.isEmpty == false, displayedStreams.isEmpty {
            return "No streams from \(selectedAddonName)"
        }
        return emptyTitle
    }

    private var filteredEmptyMessage: String {
        if selectedAddonId != nil, engine.streams.isEmpty == false, displayedStreams.isEmpty {
            return "Choose All addons or another installed streaming addon."
        }
        return emptyMessage
    }

    private var streamList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(displayedStreams) { scored in
                    StreamRow(scored: scored, tierColor: tierColors[scored.tierLabel] ?? Color(white: 0.3))
                        .onTapGesture {
                            guard scored.playable else { return }
                            select(scored)
                        }
                }

                if engine.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.accent)
                        Text("More results incoming")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(14)
        }
    }

    private func select(_ stream: ScoredStream) {
        guard let rawURL = stream.raw.url, let url = URL(string: rawURL) else { return }
        let requestedAt = Date()
        let attemptTarget = playbackTargetForNextAttempt()
        let position = engine.streams.firstIndex(where: { $0.id == stream.id }).map { $0 + 1 }
        let parameters = StreamAnalytics.selectionParameters(
            stream: stream,
            position: position,
            target: attemptTarget,
            availableAddons: engine.availableAddons,
            url: url
        )
        AnalyticsService.shared.log(.streamSelected, parameters: parameters)
        AnalyticsService.shared.log(.playbackStartRequested, parameters: parameters)
        playbackSelection = PlaybackSelection(
            url: url,
            requestedAt: requestedAt,
            target: attemptTarget
        )
    }

    private func playbackTargetForNextAttempt() -> StreamTarget {
        let sessionId = playbackAttemptCount == 0 ? target.playbackSessionId : UUID()
        playbackAttemptCount += 1
        return StreamTarget(
            metaId: target.metaId,
            type: target.type,
            title: target.title,
            videoId: target.videoId,
            base: target.base,
            metaName: target.metaName,
            poster: target.poster,
            background: target.background,
            analyticsSource: target.analyticsSource,
            playbackSessionId: sessionId,
            analyticsSeasonNumber: target.seasonNumber,
            analyticsEpisodeNumber: target.episodeNumber
        )
    }

}
