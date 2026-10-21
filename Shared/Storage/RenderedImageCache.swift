import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Finished, widget-sized images on disk, shared by the app and the widget extension.
///
/// Decoding a 1400px photo and running a Core Image filter on every widget render made
/// resizing a widget show a blank frame for a moment. With this cache a render is one
/// small file read. Only widget renders and `prewarm` write here (app thumbnails stay in
/// memory), and `prewarm` deletes anything the widgets won't ask for soon, so it can't grow
/// without limit.
enum RenderedImageCache {
    /// Bump when the rendering itself changes (e.g. the Lock Screen lift) so old files get pruned.
    private static let version = 3

    static let directory: URL = {
        let url = AppGroup.containerURL.appending(path: "Library/Caches/Rendered", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static func name(fileName: String, maxPixel: CGFloat, filter: PhotoFilter, lockLook: LockPhotoLook?) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return "\(stem)_v\(version)_\(Int(maxPixel))_\(filter.rawValue)_\(lockLook?.rawValue ?? "none").jpg"
    }

    static func load(fileName: String, maxPixel: CGFloat, filter: PhotoFilter, lockLook: LockPhotoLook?) -> UIImage? {
        let url = directory.appending(path: name(fileName: fileName, maxPixel: maxPixel, filter: filter, lockLook: lockLook))
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    static func store(_ image: CGImage, fileName: String, maxPixel: CGFloat, filter: PhotoFilter, lockLook: LockPhotoLook?) {
        // The photo may have been deleted while it was being rendered: don't recreate an orphan.
        guard FileManager.default.fileExists(atPath: ImageStore.url(for: fileName).path) else { return }
        let url = directory.appending(path: name(fileName: fileName, maxPixel: maxPixel, filter: filter, lockLook: lockLook))
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return }
        try? (data as Data).write(to: url, options: .atomic)
    }

    /// Deletes every cached size of a photo (call when the photo is removed).
    static func remove(fileName: String) {
        let prefix = (fileName as NSString).deletingPathExtension + "_"
        for file in contents() where file.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: directory.appending(path: file))
        }
    }

    private static func contents() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    // MARK: Prewarm

    /// One image a widget will ask for.
    private struct Variant {
        let item: PhotoItem
        let maxPixel: CGFloat
        let filter: PhotoFilter
        let lockLook: LockPhotoLook?
        var name: String { RenderedImageCache.name(fileName: item.fileName, maxPixel: maxPixel, filter: filter, lockLook: lockLook) }
    }

    /// Builds what the widgets will show over the next `upcomingSlots` rotations, nearest first,
    /// then (if `prune`) deletes everything else. Covers the whole widget timeline by default, so
    /// no entry has to be decoded and filtered inside the widget extension. Runs off the main
    /// actor and stops if the caller is cancelled.
    static func prewarm(_ sets: [PhotoSet], gate: FeatureGate,
                        upcomingSlots: Int = PhotoScheduler.timelineLength, prune: Bool = true) async {
        let now = Date.now
        var ordered: [Variant] = []
        var keep = Set<String>()
        for slotOffset in 0..<upcomingSlots {
            for set in sets where !set.photos.isEmpty {
                let schedule = gate.schedule(for: set)
                let slot = PhotoScheduler.slot(at: now, schedule: schedule) + slotOffset
                let filter = gate.sanitize(set.style).filter
                let look = gate.sanitize(set.lockStyle).look
                // Shifts 0...3 cover the extra tiles Mosaic and the Lock Screen strip show.
                for shift in 0..<4 {
                    guard let i = PhotoScheduler.index(for: set, slot: slot, shift: shift) else { continue }
                    let item = set.photos[i]
                    let variants = WidgetPixelSize.home.map { Variant(item: item, maxPixel: $0, filter: filter, lockLook: nil) }
                        + WidgetPixelSize.lock.map { Variant(item: item, maxPixel: $0, filter: .original, lockLook: look) }
                    for v in variants where keep.insert(v.name).inserted { ordered.append(v) }
                }
            }
        }
        for v in ordered {
            if Task.isCancelled { return }
            if FileManager.default.fileExists(atPath: directory.appending(path: v.name).path) { continue }
            _ = ImageStore.image(for: v.item, maxPixel: v.maxPixel, filter: v.filter, lockLook: v.lockLook, persist: true)
        }
        // Old filters, old versions, deleted photos, far-future photos: the widget re-renders on demand.
        guard prune, !Task.isCancelled else { return }
        for file in contents() where !keep.contains(file) {
            try? FileManager.default.removeItem(at: directory.appending(path: file))
        }
    }
}
