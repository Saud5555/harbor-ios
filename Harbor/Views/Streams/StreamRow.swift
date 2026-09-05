import SwiftUI

struct StreamRow: View {
    let scored: ScoredStream
    let tierColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(scored.tierLabel)
                .font(.system(size: 11, weight: .heavy))
                .frame(width: 44)
                .padding(.vertical, 5)
                .background(tierColor.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
                .foregroundColor(tierColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(StreamScorer.cleanTitle(scored.raw.title ?? scored.raw.description ?? "Stream"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Label(scored.raw.addonName ?? "", systemImage: "puzzlepiece.extension")
                        .lineLimit(1)

                    if let size = scored.parsed.sizeGB {
                        Text(String(format: "%.1f GB", size))
                    }

                    if let seeders = scored.parsed.seeders {
                        Label("\(seeders)", systemImage: "person.2")
                    }

                    if scored.parsed.hdr != .none {
                        Text(scored.parsed.hdr.rawValue)
                            .foregroundColor(.orange)
                    }

                    if scored.parsed.hasAtmos || scored.parsed.isLosslessAudio {
                        Image(systemName: "hifispeaker.2.fill")
                            .foregroundColor(.pink)
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: scored.playable ? "play.circle.fill" : "link.circle")
                .font(.system(size: 24))
                .foregroundColor(scored.playable ? Theme.accent : Theme.textSecondary.opacity(0.6))
                .padding(.top, 2)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(scored.playable ? Theme.border : Theme.border.opacity(0.45), lineWidth: 1)
        )
        .opacity(scored.playable ? 1 : 0.65)
    }
}
