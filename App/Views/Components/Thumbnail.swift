import SwiftUI

/// Decode sizes shared across screens: the same photo at the same size is decoded once, so the
/// set screen's card stack opens with the image the Home card already decoded.
enum ThumbSize {
    /// Home set cards, the set screen's card stack and the medium widget preview.
    static let card: CGFloat = 1000
    static let previewSmall: CGFloat = 500
    static let grid: CGFloat = 360
    static let backdrop: CGFloat = 300
}

/// Decodes thumbnails off the main thread and caches them in memory.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 400
        cache.totalCostLimit = 160 * 1024 * 1024  // decoded bytes; card-size images are ~3 MB each
    }

    private func key(_ item: PhotoItem, _ maxPixel: CGFloat, _ filter: PhotoFilter, _ lockLook: LockPhotoLook?) -> NSString {
        "\(item.fileName)|\(Int(maxPixel))|\(filter.rawValue)|\(lockLook?.rawValue ?? "none")" as NSString
    }

    /// Synchronous memory-cache lookup, so a recreated view can show its image on the first frame.
    func cached(for item: PhotoItem, maxPixel: CGFloat, filter: PhotoFilter = .original, lockLook: LockPhotoLook? = nil) -> UIImage? {
        cache.object(forKey: key(item, maxPixel, filter, lockLook))
    }

    func image(for item: PhotoItem, maxPixel: CGFloat, filter: PhotoFilter = .original, lockLook: LockPhotoLook? = nil) async -> UIImage? {
        let key = key(item, maxPixel, filter, lockLook)
        if let hit = cache.object(forKey: key) { return hit }
        let image = await Task.detached(priority: .userInitiated) {
            ImageStore.image(for: item, maxPixel: maxPixel, filter: filter, lockLook: lockLook)
        }.value
        if let image { cache.setObject(image, forKey: key, cost: Self.cost(of: image)) }
        return image
    }

    private static func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }

    /// Decodes what Home draws first (front cards, widget previews, the set backdrop) while the
    /// splash plays, so Home opens fully drawn instead of shimmering photos in one by one.
    func preloadHome(sets: [PhotoSet]) async {
        var jobs: [(item: PhotoItem, maxPixel: CGFloat, filter: PhotoFilter)] = []
        for set in sets.prefix(2) {
            jobs += set.photos.prefix(3).map { ($0, ThumbSize.card, .original) }
        }
        if let first = sets.first, !first.photos.isEmpty {
            let photos = first.photos
            jobs.append((photos[0], ThumbSize.previewSmall, first.style.filter))
            jobs.append((photos[1 % photos.count], ThumbSize.card, first.style.filter))
            jobs.append((photos[0], ThumbSize.backdrop, .original))
        }
        await withTaskGroup(of: Void.self) { group in
            for job in jobs {
                group.addTask { _ = await self.image(for: job.item, maxPixel: job.maxPixel, filter: job.filter) }
            }
        }
    }

    func removeAll() { cache.removeAllObjects() }
}

/// Async thumbnail with a shimmer placeholder.
struct Thumbnail: View {
    let item: PhotoItem?
    var maxPixel: CGFloat = 400
    var filter: PhotoFilter = .original

    /// The image together with the photo it belongs to. When `item` changes, a stale image is
    /// never drawn for the new photo (that flashed the previous photo for a moment).
    @State private var loaded: (key: String, image: UIImage)?

    init(item: PhotoItem?, maxPixel: CGFloat = 400, filter: PhotoFilter = .original) {
        self.item = item
        self.maxPixel = maxPixel
        self.filter = filter
        let key = Self.key(item, maxPixel, filter)
        _loaded = State(initialValue: item
            .flatMap { ThumbnailCache.shared.cached(for: $0, maxPixel: maxPixel, filter: filter) }
            .map { (key, $0) })
    }

    private static func key(_ item: PhotoItem?, _ maxPixel: CGFloat, _ filter: PhotoFilter) -> String {
        "\(item?.id.uuidString ?? "")|\(Int(maxPixel))|\(filter.rawValue)"
    }

    private var key: String { Self.key(item, maxPixel, filter) }

    private var image: UIImage? {
        if let loaded, loaded.key == key { return loaded.image }
        return item.flatMap { ThumbnailCache.shared.cached(for: $0, maxPixel: maxPixel, filter: filter) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    (item?.dominantColorHex.map(Color.init(hex:)) ?? Color.gray.opacity(0.2))
                        .overlay { ShimmerView() }
                        .clipped()
                }
            }
        }
        .task(id: key) {
            let key = key
            guard let item else { loaded = nil; return }
            if let hit = ThumbnailCache.shared.cached(for: item, maxPixel: maxPixel, filter: filter) {
                loaded = (key, hit)  // already decoded: no fade
                return
            }
            let image = await ThumbnailCache.shared.image(for: item, maxPixel: maxPixel, filter: filter)
            guard let image else { return }
            withAnimation(.easeOut(duration: 0.2)) { loaded = (key, image) }
        }
    }
}

struct ShimmerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                Color.white.opacity(0.12)
            } else {
                LinearGradient(colors: [.clear, .white.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)
                    .scaleEffect(x: 0.6)
                    .offset(x: phase * geo.size.width)
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
