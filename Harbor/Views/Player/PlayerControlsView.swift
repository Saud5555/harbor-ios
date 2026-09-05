import SwiftUI

@MainActor
struct PlayerControlsView: View {
    @ObservedObject var player: VLCPlayerController

    let title: String
    let episode: EpisodeCoordinates?
    let nextVideo: MetaVideo?
    let onClose: () -> Void
    let onShowOptions: () -> Void
    let onPlayNext: () -> Void

    private let speeds: [Float] = [
        0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0,
    ]

    var body: some View {
        VStack {
            topBar
            Spacer()
            centerControls
            Spacer()
            seekBar
        }
        .padding(.horizontal, 16)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Close player and stop playback")
            .accessibilityIdentifier("harbor.player.close")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let episode {
                    Text(episode.label)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Menu {
                ForEach(speeds, id: \.self) { speed in
                    Button(String(format: "%.2fx", speed)) {
                        player.setRate(speed)
                    }
                }
            } label: {
                Text(String(format: "%.2fx", player.rate))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.black.opacity(0.45), in: Capsule())
            }

            Button(action: onShowOptions) {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.45), in: Circle())
            }
        }
        .padding(.top, 8)
    }

    private var centerControls: some View {
        HStack(spacing: 44) {
            Button {
                player.seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white)
            }

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
                    .foregroundColor(.white)
            }

            Button {
                if nextVideo == nil {
                    player.seek(by: 10)
                } else {
                    onPlayNext()
                }
            } label: {
                Image(systemName: nextVideo == nil ? "goforward.10" : "forward.end.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(nextVideo == nil ? .white : Theme.accent)
            }
        }
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { player.duration > 0 ? player.currentTime / player.duration : 0 },
                    set: { player.seek(to: $0 * player.duration) }
                ),
                in: 0...1
            )
            .tint(Theme.accent)

            HStack {
                Text(Self.timeString(player.currentTime))
                Spacer()
                if let nextVideo {
                    Button("Next: \(nextVideo.displayTitle)", action: onPlayNext)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.accent)
                        .lineLimit(1)
                    Spacer()
                }
                Text("-\(Self.timeString(max(player.duration - player.currentTime, 0)))")
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(.white.opacity(0.85))
        }
        .padding(.bottom, 14)
    }

    private static func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
