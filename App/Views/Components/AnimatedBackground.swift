import SwiftUI

/// Still, color-rich backdrop. Uses MeshGradient on iOS 18+, soft blobs on iOS 17.
/// Deliberately static: a constantly moving background distracts and drains battery.
/// `tint` lets screens bias the colors toward the current photo.
struct AnimatedBackground: View {
    var tint: Color? = nil
    @Environment(\.colorScheme) private var scheme

    private var colors: [Color] {
        let t = tint ?? Brand.lavender
        return scheme == .dark
            ? [Brand.ink, t.opacity(0.55), Color(hex: "#1B1D35"), Brand.coral.opacity(0.35), Brand.ink, Brand.mint.opacity(0.3)]
            : [Color(hex: "#FFF4EF"), t.opacity(0.45), Color(hex: "#F3F0FF"), Brand.coral.opacity(0.35), Color(hex: "#F6FFFC"), Brand.mint.opacity(0.35)]
    }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                mesh(t: 0)
            } else {
                blobs(t: 0)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: tint)
    }

    @available(iOS 18.0, *)
    private func mesh(t: TimeInterval) -> some View {
        let s = Float(sin(t * 0.35)) * 0.12
        let c = Float(cos(t * 0.27)) * 0.12
        let c0 = colors
        let points: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(0.5 + s, 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + c), SIMD2(0.5 + c, 0.5 + s), SIMD2(1, 0.5 - s),
            SIMD2(0, 1), SIMD2(0.5 - c, 1), SIMD2(1, 1),
        ]
        let meshColors: [Color] = [
            c0[0], c0[1], c0[2],
            c0[3], c0[4], c0[1],
            c0[5], c0[2], c0[3],
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: meshColors)
    }

    private func blobs(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                colors[0]
                Circle().fill(colors[1]).frame(width: w * 1.1)
                    .offset(x: CGFloat(sin(t * 0.3)) * w * 0.25, y: -h * 0.25)
                Circle().fill(colors[3]).frame(width: w * 0.9)
                    .offset(x: CGFloat(cos(t * 0.25)) * w * 0.3, y: h * 0.1)
                Circle().fill(colors[5]).frame(width: w)
                    .offset(x: -CGFloat(sin(t * 0.2)) * w * 0.2, y: h * 0.35)
            }
            .blur(radius: 70)
        }
    }
}

/// A blurred, full-bleed photo backdrop with a cross-fade when the photo changes.
struct PhotoBackdrop: View {
    let item: PhotoItem?
    @State private var image: UIImage?

    init(item: PhotoItem?) {
        self.item = item
        // Already decoded? Show it on the first frame instead of fading in from black.
        _image = State(initialValue: item.flatMap { ThumbnailCache.shared.cached(for: $0, maxPixel: ThumbSize.backdrop) })
    }

    var body: some View {
        // The fill-sized photo lives in an overlay so it can never widen whatever contains it.
        Rectangle().fill(.black.opacity(0.25))
            .background {
                Color.clear.overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 50)
                            .scaleEffect(1.3)
                            .transition(.opacity)
                            .id(image)
                    }
                }
                .clipped()
                // Dark base: with no photo (or before it decodes) white text stays readable in Light Mode.
                .background(Brand.ink)
            }
            .ignoresSafeArea()
            .task(id: item?.id) {
                guard let item else { image = nil; return }
                if let hit = ThumbnailCache.shared.cached(for: item, maxPixel: ThumbSize.backdrop) {
                    withAnimation(.easeInOut(duration: 0.4)) { image = hit }
                    return
                }
                let loaded = await ThumbnailCache.shared.image(for: item, maxPixel: ThumbSize.backdrop)
                withAnimation(.easeInOut(duration: 0.4)) { image = loaded }
            }
    }
}
