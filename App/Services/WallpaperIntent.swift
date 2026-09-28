import AppIntents
import Photos
import UIKit
import UniformTypeIdentifiers

/// Shortcuts action used to rotate the real wallpaper:
/// Automation (Time of Day) → "Get Framely Photo" → "Set Wallpaper Photo".
/// Apps can't change the wallpaper themselves; Shortcuts can.
struct GetFramelyPhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Framely Photo"
    static let description = IntentDescription(
        "Gets the next photo from a Framely set. Pair it with “Set Wallpaper Photo” to rotate your wallpaper.",
        categoryName: "Wallpaper"
    )

    @Parameter(title: "Photo Set")
    var photoSet: PhotoSetEntity

    @Parameter(title: "Apply Set’s Filter", default: false)
    var applyFilter: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Get a photo from \(\.$photoSet)") {
            \.$applyFilter
        }
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard FeatureGate.current.wallpaperShortcut else { throw FramelyIntentError.proRequired }
        guard let set = SharedStore.shared.set(id: photoSet.id), !set.photos.isEmpty else {
            throw FramelyIntentError.emptySet
        }

        // Independent cursor so wallpaper order doesn't disturb the widgets.
        let key = "wallpaperCursor.\(set.id.uuidString)"
        let cursor = AppGroup.defaults.integer(forKey: key)
        AppGroup.defaults.set(cursor + 1, forKey: key)
        let index = PhotoScheduler.index(for: set, slot: cursor) ?? 0
        let item = set.photos[index]

        let filter = applyFilter ? set.style.filter : .original
        guard let data = await Self.wallpaperData(for: item, filter: filter) else {
            throw FramelyIntentError.unreadable
        }
        return .result(value: IntentFile(data: data, filename: "Framely-\(item.id.uuidString.prefix(8)).jpg", type: .jpeg))
    }

    /// Prefers the full-resolution original from Photos (wallpapers need ~2800px);
    /// falls back to Framely's stored copy.
    private static func wallpaperData(for item: PhotoItem, filter: PhotoFilter) async -> Data? {
        var image: UIImage?
        if let id = item.assetIdentifier, AlbumSyncService.isAuthorized,
           let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
           let data = await AlbumSyncService.imageData(for: asset, targetPixel: 3000) {
            image = UIImage(data: data)
        }
        if image == nil {
            image = ImageStore.image(for: item, maxPixel: ImageStore.storedMaxPixel)
        }
        guard var result = image else { return nil }
        if let cg = result.cgImage, let filtered = ImageProcessing.apply(filter, to: cg) {
            result = UIImage(cgImage: filtered)
        }
        return result.jpegData(compressionQuality: 0.92)
    }
}

enum FramelyIntentError: Error, CustomLocalizedStringResourceConvertible {
    case proRequired, emptySet, unreadable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .proRequired: "Wallpaper rotation is part of Framely Pro. Open Framely to upgrade."
        case .emptySet: "That photo set is empty. Add photos in Framely first."
        case .unreadable: "Framely couldn’t read that photo."
        }
    }
}

struct FramelyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetFramelyPhotoIntent(),
            phrases: ["Get a photo from \(.applicationName)", "Get a \(.applicationName) photo"],
            shortTitle: "Get Photo",
            systemImageName: "photo.on.rectangle.angled"
        )
    }
}
