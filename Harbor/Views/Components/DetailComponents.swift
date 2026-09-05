import SwiftUI

struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.surfaceRaised, in: Capsule())
            .foregroundColor(Theme.textPrimary)
    }
}

struct EpisodeRow: View {
    let video: MetaVideo
    let meta: Meta
    let watched: Bool
    let base: String?
    let source: HarborNavigationSource

    @State private var playbackSessionId = UUID()

    var body: some View {
        NavigationLink(value: streamTarget) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                episodeDescription
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            logPlaybackRequest()
        })
    }

    private var streamTarget: StreamTarget {
        StreamTarget(
            metaId: meta.id,
            type: "series",
            title: video.displayTitle,
            videoId: video.id,
            base: base,
            metaName: meta.name,
            poster: meta.poster,
            background: meta.background,
            analyticsSource: source,
            playbackSessionId: playbackSessionId,
            analyticsSeasonNumber: video.season,
            analyticsEpisodeNumber: video.episode
        )
    }

    private var thumbnail: some View {
        ZStack {
            AsyncImage(url: URL(string: video.thumbnail ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Theme.surfaceRaised
                }
            }
            .frame(width: 110, height: 62)
            .clipped()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.white.opacity(0.85))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var episodeDescription: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if watched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.accent)
                }
                Text(video.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundColor(Theme.textPrimary)
            }
            if let overview = video.overview, !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func logPlaybackRequest() {
        let parameters = AnalyticsService.shared.mediaParameters(
            mediaType: "series",
            mediaId: meta.id,
            source: source,
            playbackSessionId: playbackSessionId,
            seasonNumber: video.season,
            episodeNumber: video.episode
        )
        AnalyticsService.shared.log(.playClicked, parameters: parameters)
        let usedSessionId = playbackSessionId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if playbackSessionId == usedSessionId {
                playbackSessionId = UUID()
            }
        }
    }
}
