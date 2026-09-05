import SwiftUI

struct AdaptiveMediaRail: View {
    let title: String
    var subtitle: String?
    let metas: [Meta]
    var source: HarborNavigationSource = .search
    var ranked = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var posterWidth: CGFloat { horizontalSizeClass == .regular ? 148 : 116 }
    private var horizontalPadding: CGFloat { horizontalSizeClass == .regular ? 28 : 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HarborSectionHeader(title: title, subtitle: subtitle)
                .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: ranked ? 5 : 13) {
                    ForEach(Array(metas.prefix(ranked ? 10 : 24).enumerated()), id: \.element.id) { index, meta in
                        NavigationLink(value: MetaNavigation(meta: meta, base: nil, source: source)) {
                            if ranked {
                                rankedCard(meta: meta, rank: index + 1)
                            } else {
                                PosterCard(meta: meta, width: posterWidth)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
    }

    private func rankedCard(meta: Meta, rank: Int) -> some View {
        let numberWidth: CGFloat = horizontalSizeClass == .regular ? 102 : 76
        let cardWidth: CGFloat = horizontalSizeClass == .regular ? 136 : 105
        return ZStack(alignment: .bottomLeading) {
            Text("\(rank)")
                .font(.system(size: horizontalSizeClass == .regular ? 144 : 108, weight: .black, design: .rounded))
                .foregroundColor(Theme.background)
                .shadow(color: .white.opacity(0.5), radius: 1.2)
                .frame(width: numberWidth, alignment: .leading)
                .offset(y: 5)

            PosterCard(meta: meta, width: cardWidth, showTitle: false)
                .offset(x: numberWidth * 0.54)
        }
        .frame(
            width: cardWidth + numberWidth * 0.54,
            height: cardWidth * 1.5,
            alignment: .bottomLeading
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(rank), \(meta.name)")
    }
}
