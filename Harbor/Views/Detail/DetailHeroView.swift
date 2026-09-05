import SwiftUI

struct DetailHeroView: View {
    let meta: Meta
    let fallbackPoster: String?
    let background: String?
    let story: String?
    let layout: HarborAdaptiveLayout

    var body: some View {
        if layout == .pad {
            expandedHero
        } else {
            VStack(spacing: 0) {
                compactHero
                compactTitleBlock
            }
        }
    }

    private var expandedHero: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                backdropImage
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.08), .black.opacity(0.16), Theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [Theme.background.opacity(0.7), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 10) {
                    mediaEyebrow
                    titleOrLogo
                    metadataBadges

                    if let genres = meta.genres, !genres.isEmpty {
                        Text(genres.prefix(3).joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    if let story {
                        Text(story)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(3)
                            .frame(maxWidth: 340, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 490)
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier("harbor.detail.banner")
    }

    private var compactHero: some View {
        GeometryReader { geometry in
            ZStack {
                backdropImage
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, Theme.background.opacity(0.98)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier("harbor.detail.banner")
    }

    private var compactTitleBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterCard(meta: posterMeta, width: 92, showTitle: false)

            VStack(alignment: .leading, spacing: 8) {
                mediaEyebrow

                Text(meta.name)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .tracking(-0.5)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(3)

                metadataBadges

                if let genres = meta.genres, !genres.isEmpty {
                    Text(genres.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, -44)
    }

    private var backdropImage: some View {
        AsyncImage(url: URL(string: background ?? "")) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                LinearGradient(
                    colors: [Theme.surfaceRaised, Theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private var titleOrLogo: some View {
        if let logo = meta.logo, !logo.isEmpty {
            AsyncImage(url: URL(string: logo)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    detailTitle
                }
            }
            .frame(maxWidth: 260, maxHeight: 92, alignment: .leading)
        } else {
            detailTitle
        }
    }

    private var mediaEyebrow: some View {
        Text(meta.type == "series" ? "HARBOR SERIES" : "HARBOR MOVIE")
            .font(.system(size: 9, weight: .heavy))
            .tracking(2.2)
            .foregroundColor(Theme.accent)
    }

    private var metadataBadges: some View {
        HStack(spacing: 8) {
            if let year = meta.releaseInfo, !year.isEmpty {
                Badge(text: year)
            }
            if let runtime = meta.runtime, !runtime.isEmpty {
                Badge(text: runtime)
            }
            if let rating = meta.imdbRating, !rating.isEmpty {
                HStack(spacing: 3) {
                    Text("IMDb")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 2))
                    Text(rating).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.surfaceRaised, in: Capsule())
            }
        }
    }

    private var detailTitle: some View {
        Text(meta.name)
            .font(.system(size: 36, weight: .bold, design: .serif))
            .tracking(-1)
            .foregroundColor(Theme.textPrimary)
            .lineLimit(3)
    }

    private var posterMeta: Meta {
        Meta(
            id: meta.id,
            type: meta.type,
            name: meta.name,
            poster: meta.poster ?? fallbackPoster,
            background: nil,
            logo: nil,
            description: nil,
            releaseInfo: nil,
            imdbRating: nil,
            genres: nil,
            runtime: nil,
            country: nil,
            network: nil,
            videos: nil
        )
    }
}
