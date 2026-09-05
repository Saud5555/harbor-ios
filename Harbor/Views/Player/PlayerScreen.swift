import SwiftUI
import UIKit

struct PlayerScreen: View {
    let streamURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player = VLCPlayerController.shared
    @StateObject private var subtitleEngine = SubtitleEngine()

    @State private var activeTitle: String
    @State private var activeTarget: StreamTarget
    @State private var analyticsSession: PlaybackAnalyticsSession
    @State private var showControls = true
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var syncCounter = 0
    @State private var markedWatched = false
    @State private var resumeApplied = false
    @State private var nextVideo: MetaVideo?
    @State private var showNextPrompt = false
    @State private var persistenceTask: Task<Void, Never>?
    @State private var showPlaybackOptions = false

    private let uiTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        streamURL: URL,
        title: String,
        target: StreamTarget,
        playbackRequestedAt: Date = Date()
    ) {
        self.streamURL = streamURL
        _activeTitle = State(initialValue: title)
        _activeTarget = State(initialValue: target)
        _analyticsSession = State(initialValue: PlaybackAnalyticsSession(
            target: target,
            requestedAt: playbackRequestedAt
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerHostView(controller: player)
                .ignoresSafeArea()

            playbackTapSurface

            if player.isBuffering {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)
            }

            if player.state == .errored {
                errorOverlay
            }

            if showControls {
                controlsOverlay
            }

            if showNextPrompt, let _ = nextVideo {
                nextEpisodePrompt
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { begin() }
        .onDisappear {
            controlsHideTask?.cancel()
            persistProgress(force: true)
            analyticsSession.stop(
                reason: playbackStopReason,
                currentTime: player.currentTime,
                duration: player.duration
            )
            player.stop()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                persistProgress(force: true)
            }
        }
        .onReceive(uiTimer) { _ in
            tick()
        }
        .onChange(of: player.state) { state in
            handlePlaybackState(state)
        }
        .onChange(of: showPlaybackOptions) { isShowing in
            if !isShowing, player.isPlaying, showControls {
                scheduleControlsHide()
            }
        }
        .sheet(isPresented: $showPlaybackOptions) {
            PlayerOptionsSheet(player: player, subtitleEngine: subtitleEngine)
        }
    }

    // MARK: - Lifecycle

    private func begin() {
        guard !resumeApplied else { return }
        resumeApplied = true

        AnalyticsService.shared.setCurrentScreen(.player, screenClass: "PlayerScreen")
        let resume = resumeContext()
        analyticsSession.prepareForResume(offset: resume.offset, knownDuration: resume.duration)
        analyticsSession.begin()
        player.load(url: streamURL, startAt: resume.offset)

        scheduleControlsHide()
        loadNextEpisodeCandidate()
        let target = activeTarget
        Task {
            await subtitleEngine.load(target: target)
        }
    }

    private func resumeContext() -> (offset: TimeInterval, duration: TimeInterval) {
        guard let item = LibraryStore.shared.item(id: activeTarget.metaId),
              let state = item.state else { return (0, 0) }
        let sameVideo: Bool
        if let videoId = activeTarget.videoId {
            sameVideo = state.videoId == videoId
        } else {
            sameVideo = state.videoId == nil || state.videoId?.hasPrefix(activeTarget.metaId + ":") != true
        }
        guard sameVideo, let offset = state.timeOffset, offset > 30_000 else { return (0, 0) }
        return (offset / 1000, (state.duration ?? 0) / 1000)
    }

    private func loadNextEpisodeCandidate() {
        guard activeTarget.type == "series", let currentVideoId = activeTarget.videoId else { return }
        let candidateTarget = activeTarget
        Task {
            let meta = try? await AddonClient.shared.metaDetail(
                base: candidateTarget.base, type: "series", id: candidateTarget.metaId
            )
            let videos = (meta?.videos ?? []).sorted {
                ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0)
            }
            guard let currentIndex = videos.firstIndex(where: { $0.id == currentVideoId }),
                  currentIndex + 1 < videos.count else { return }
            await MainActor.run {
                nextVideo = videos[currentIndex + 1]
            }
        }
    }

    // MARK: - Tick / sync

    private func tick() {
        player.poll()
        analyticsSession.update(
            state: player.state,
            currentTime: player.currentTime,
            duration: player.duration
        )
        syncCounter += 1
        let ratio = player.duration > 0 ? player.currentTime / player.duration : 0

        if ratio >= 0.9 {
            if !markedWatched, let authKey = AuthStore.shared.authKey {
                markedWatched = true
                let watchedTarget = activeTarget
                let previous = persistenceTask
                persistenceTask = Task {
                    await previous?.value
                    await LibraryStore.shared.markWatched(
                        authKey: authKey,
                        target: watchedTarget
                    )
                }
            }
        } else if syncCounter % 10 == 0, player.isPlaying || player.state == .paused {
            persistProgress(force: false)
        }

        if player.state == .ended, nextVideo != nil {
            showNextPrompt = true
        }

    }

    private func handlePlaybackState(_ state: VLCPlayerController.PlayState) {
        analyticsSession.update(
            state: state,
            currentTime: player.currentTime,
            duration: player.duration
        )
        switch state {
        case .playing:
            if showControls { scheduleControlsHide() }
        case .paused, .ended, .errored:
            controlsHideTask?.cancel()
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = true
            }
        case .idle, .buffering, .stopped:
            break
        }
    }

    private var playbackStopReason: HarborPlaybackStopReason {
        switch player.state {
        case .ended: return .ended
        case .errored: return .failed
        default: return .dismissed
        }
    }

    private func persistProgress(force: Bool) {
        guard player.duration > 5, player.state != .errored else { return }
        guard !markedWatched else { return }
        guard force || player.currentTime > 5 else { return }
        guard let authKey = AuthStore.shared.authKey else { return }
        let offset = player.currentTime
        let duration = player.duration
        let progressTarget = activeTarget
        let previous = persistenceTask
        persistenceTask = Task {
            await previous?.value
            await LibraryStore.shared.saveProgress(
                authKey: authKey,
                target: progressTarget,
                offset: offset * 1000,
                duration: duration * 1000
            )
        }
    }

    // MARK: - Controls

    /// VLC renders inside a native UIView, which can consume touches before a
    /// gesture attached to PlayerHostView reaches SwiftUI. Keep a permanent,
    /// nearly transparent SwiftUI hit area above the video instead.
    private var playbackTapSurface: some View {
        Color.black.opacity(0.001)
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
                toggleControls()
            }
            .accessibilityLabel("Toggle playback controls")
            .accessibilityIdentifier("harbor.player.control_surface")
    }

    private func toggleControls() {
        controlsHideTask?.cancel()
        let willShow = !showControls
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls = willShow
        }
        if willShow {
            scheduleControlsHide()
        }
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showControls = false
            }
        }
    }

    private func playNext() {
        guard let next = nextVideo else { return }
        persistProgress(force: true)
        showNextPrompt = false
        let nextTarget = StreamTarget(
            metaId: activeTarget.metaId,
            type: "series",
            title: next.displayTitle,
            videoId: next.id,
            base: activeTarget.base,
            metaName: activeTarget.metaName,
            poster: activeTarget.poster,
            background: activeTarget.background,
            analyticsSource: activeTarget.analyticsSource,
            playbackSessionId: UUID(),
            analyticsSeasonNumber: next.season,
            analyticsEpisodeNumber: next.episode
        )

        let nextParameters = AnalyticsService.shared.mediaParameters(
            mediaType: nextTarget.type,
            mediaId: nextTarget.metaId,
            source: nextTarget.analyticsSource,
            playbackSessionId: nextTarget.playbackSessionId,
            seasonNumber: nextTarget.seasonNumber,
            episodeNumber: nextTarget.episodeNumber
        )
        AnalyticsService.shared.log(.playClicked, parameters: nextParameters)

        Task {
            let streams = StreamEngine()
            await streams.load(target: nextTarget)
            guard let best = streams.streams.first(where: \.playable) else {
                await recoverNextEpisodeSelection(
                    category: .noStreams,
                    parameters: nextParameters
                )
                return
            }
            guard let urlString = best.raw.url, let url = URL(string: urlString) else {
                await recoverNextEpisodeSelection(
                    category: .invalidURL,
                    parameters: nextParameters
                )
                return
            }
            let requestedAt = Date()
            let position = streams.streams.firstIndex(where: { $0.id == best.id }).map { $0 + 1 }
            let selectionParameters = StreamAnalytics.selectionParameters(
                stream: best,
                position: position,
                target: nextTarget,
                availableAddons: streams.availableAddons,
                url: url
            )
            AnalyticsService.shared.log(.streamSelected, parameters: selectionParameters)
            AnalyticsService.shared.log(.playbackStartRequested, parameters: selectionParameters)
            await MainActor.run {
                analyticsSession.stop(
                    reason: player.state == .ended ? .ended : .replaced,
                    currentTime: player.currentTime,
                    duration: player.duration
                )
                markedWatched = false
                syncCounter = 0
                resumeApplied = true
                nextVideo = nil
                activeTitle = next.displayTitle
                activeTarget = nextTarget
                analyticsSession = PlaybackAnalyticsSession(
                    target: nextTarget,
                    requestedAt: requestedAt
                )
                analyticsSession.begin()
                player.load(url: url, startAt: 0)
                showControls = true
                scheduleControlsHide()
                loadNextEpisodeCandidate()
                Task {
                    await subtitleEngine.load(target: nextTarget)
                }
            }
        }
    }

    private func recoverNextEpisodeSelection(
        category: HarborAnalyticsErrorCategory,
        parameters: HarborAnalyticsParameters
    ) async {
        var failureParameters = parameters
        failureParameters[.errorType] = .string(category.rawValue)
        AnalyticsService.shared.log(.playbackStartRequested, parameters: parameters)
        AnalyticsService.shared.log(.playbackFailed, parameters: failureParameters)
        await MainActor.run {
            showNextPrompt = nextVideo != nil
            showControls = true
        }
    }

    // MARK: - Overlay views

    private var controlsOverlay: some View {
        PlayerControlsView(
            player: player,
            title: activeTitle,
            episode: activeTarget.episodeCoordinates,
            nextVideo: nextVideo,
            onClose: { dismiss() },
            onShowOptions: {
                controlsHideTask?.cancel()
                showPlaybackOptions = true
            },
            onPlayNext: playNext
        )
    }

    private var errorOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(Theme.accent)
            Text("Playback failed")
                .font(.headline)
                .foregroundColor(.white)
            Text("This source could not be decoded. Try another stream.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(HarborPrimaryButtonStyle())
        }
        .padding(24)
        .background(Theme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private var nextEpisodePrompt: some View {
        VStack(spacing: 14) {
            Text("Up next")
                .font(.headline)
                .foregroundColor(.white)
            if let next = nextVideo {
                Text(next.displayTitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            HStack(spacing: 12) {
                Button("Dismiss") { showNextPrompt = false }
                    .buttonStyle(HarborSecondaryButtonStyle())
                Button("Play now") { playNext() }
                    .buttonStyle(HarborPrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(Theme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

}
