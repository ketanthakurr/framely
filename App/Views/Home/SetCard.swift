import SwiftUI

/// Carousel card: a fanned mini-stack of the set's photos with a glass caption.
struct SetCard: View {
    let set: PhotoSet

    var body: some View {
        ZStack(alignment: .bottom) {
            // Back photos peeking out
            ForEach(Array(set.photos.prefix(3).enumerated().reversed()), id: \.element.id) { index, item in
                Thumbnail(item: item, maxPixel: 700)
                    .frame(width: 250, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .rotationEffect(.degrees(index == 0 ? 0 : (index == 1 ? 5 : -5)))
                    .offset(x: index == 0 ? 0 : (index == 1 ? 12 : -12), y: CGFloat(index) * -6)
                    .scaleEffect(1 - CGFloat(index) * 0.04)
                    .shadow(color: .black.opacity(index == 0 ? 0.25 : 0.1), radius: 16, y: 10)
            }

            if set.photos.isEmpty {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Brand.gradient.opacity(0.85))
                    .frame(width: 250, height: 320)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 40, weight: .semibold))
                            Text("Add photos").font(Brand.headline)
                        }
                        .foregroundStyle(.white)
                    }
            }

            caption
                .padding(12)
        }
        .frame(width: 262, height: 340)
    }

    private var caption: some View {
        HStack(spacing: 10) {
            Image(systemName: set.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Brand.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(set.name).font(Brand.headline).lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(set.photos.count) photos")
                    Text("·")
                    Image(systemName: set.order.symbol)
                    Text(set.intervalShortTitle)
                    if set.source.isAlbum { Image(systemName: "arrow.triangle.2.circlepath") }
                }
                .font(Brand.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(10)
        .frame(width: 226)
        .glass(cornerRadius: 20)
    }
}

struct NewSetCard: View {
    var locked: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: locked ? "crown.fill" : "plus")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(locked ? AnyShapeStyle(Brand.proGradient) : AnyShapeStyle(Brand.gradient))
                .frame(width: 72, height: 72)
                .glassCircle()
            Text(locked ? "More sets with Pro" : "New set")
                .font(Brand.headline)
            Text(locked ? "Family, travel, pets —\none widget each" : "Family, travel, pets…")
                .font(Brand.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 200, height: 320)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .glass(cornerRadius: 30)
        .foregroundStyle(.primary)
    }
}

/// First-run hero with floating polaroids.
struct EmptyHomeHero: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            FloatingPolaroids()
                .frame(height: 260)

            VStack(spacing: 8) {
                Text("Make your Home Screen yours")
                    .font(Brand.title(26))
                    .multilineTextAlignment(.center)
                Text("Create a photo set, pick your favorite shots, and Framely turns them into beautiful rotating widgets.")
                    .font(Brand.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create your first set", action: action)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(22)
        .glass(cornerRadius: 32)
    }
}

/// Decorative fanned polaroids (no user photos needed).
struct FloatingPolaroids: View {
    var images: [UIImage] = []
    private let y: [CGFloat] = [6, -4, 6]

    private let gradients: [[Color]] = [
        [Brand.coral, Color(hex: "#FFC3A0")],
        [Brand.lavender, Color(hex: "#6A82FB")],
        [Brand.mint, Color(hex: "#3CA7D6")],
    ]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                polaroid(i)
                    .rotationEffect(.degrees(Double(i - 1) * 6))
                    .offset(x: CGFloat(i - 1) * 64, y: y[i])
                    .zIndex(i == 1 ? 2 : 0)
            }
        }
        .accessibilityHidden(true)
    }

    private func polaroid(_ i: Int) -> some View {
        VStack(spacing: 0) {
            Group {
                if i < images.count {
                    Image(uiImage: images[i]).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: gradients[i], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(Image(systemName: ["sun.max.fill", "heart.fill", "leaf.fill"][i])
                            .font(.system(size: 34)).foregroundStyle(.white.opacity(0.9)))
                }
            }
            .frame(width: 130, height: 130)
            .clipped()
            // Fixed width: an unsized Color.clear would stretch the card to the screen edge.
            Color.clear.frame(width: 130, height: 30)
        }
        .padding(8)
        .background(Color(hex: "#FBF8F2"), in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }
}
