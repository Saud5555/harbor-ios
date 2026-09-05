import SwiftUI

struct TMDBStreamingProvidersRow: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HarborSectionHeader(
                title: "Your Streaming",
                subtitle: "Popular titles available in your region"
            )
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 11) {
                    ForEach(TMDBStreamingProvider.all) { provider in
                        NavigationLink {
                            TMDBServiceView(provider: provider)
                        } label: {
                            TMDBProviderCard(provider: provider)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
            }
        }
    }
}

private struct TMDBProviderCard: View {
    let provider: TMDBStreamingProvider
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(harborHex: provider.tintHex).opacity(0.95), Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 10) {
                Text(provider.shortMark)
                    .font(.system(size: provider.shortMark.count <= 2 ? 30 : 21, weight: .black, design: .rounded))
                    .foregroundColor(provider.id == "apple" ? .black : .white)
                Spacer(minLength: 0)
                Text(provider.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Label("Explore", systemImage: "arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.72))
            }
            .padding(14)
        }
        .frame(
            width: horizontalSizeClass == .regular ? 190 : 152,
            height: horizontalSizeClass == .regular ? 118 : 96
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
        .accessibilityLabel("Popular on \(provider.name)")
    }
}

struct TMDBGenreRow: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HarborSectionHeader(
                title: "Browse by Genre",
                subtitle: "Find the mood you want"
            )
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(TMDBGenreDefinition.all) { genre in
                        NavigationLink {
                            TMDBCollectionView(definition: genre.collection)
                        } label: {
                            genreTile(genre)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
            }
        }
    }

    private func genreTile(_ genre: TMDBGenreDefinition) -> some View {
        let width: CGFloat = horizontalSizeClass == .regular ? 220 : 168
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(harborHex: genre.tintHex), Color(harborHex: genre.tintHex).opacity(0.38), Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: genre.symbol)
                .font(.system(size: 62, weight: .bold))
                .foregroundColor(.white.opacity(0.12))
                .offset(x: width * 0.52, y: -20)
            HStack(alignment: .bottom) {
                Text(genre.name)
                    .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(15)
        }
        .frame(width: width, height: width * 0.68)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
    }
}
