import SwiftUI

/// Decodes thumbnails off the main thread and caches them in memory.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 400 }

    func image(for item: PhotoItem, maxPixel: CGFloat, filter: PhotoFilter = .original, lockLook: LockPhotoLook = .natural) async -> UIImage? {
        let key = "\(item.fileName)|\(Int(maxPixel))|\(filter.rawValue)|\(lockLook.rawValue)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image = await Task.detached(priority: .userInitiated) {
            ImageStore.image(for: item, maxPixel: maxPixel, filter: filter, lockLook: lockLook)
        }.value
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    func removeAll() { cache.removeAllObjects() }
}

/// Async thumbnail with a shimmer placeholder.
struct Thumbnail: View {
    let item: PhotoItem?
    var maxPixel: CGFloat = 400
    var filter: PhotoFilter = .original

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    (item?.dominantColorHex.map(Color.init(hex:)) ?? Color.gray.opacity(0.2))
                        .overlay(ShimmerView())
                }
            }
        }
        .task(id: "\(item?.id.uuidString ?? "")\(filter.rawValue)") {
            guard let item else { image = nil; return }
            let loaded = await ThumbnailCache.shared.image(for: item, maxPixel: maxPixel, filter: filter)
            withAnimation(.easeOut(duration: 0.25)) { image = loaded }
        }
    }
}

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(colors: [.clear, .white.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)
            .scaleEffect(x: 0.6)
            .offset(x: phase * 220)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
            .allowsHitTesting(false)
    }
}
