import Photos
import UIKit

struct AlbumInfo: Identifiable, Hashable {
    let id: String          // PHAssetCollection.localIdentifier
    let title: String
    let count: Int
    let coverAssetID: String?
}

/// Reads albums from the Photos library and mirrors one into a PhotoSet.
enum AlbumSyncService {
    static var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Favorites + Recents first, then the user's own albums.
    static func albums() -> [AlbumInfo] {
        var result: [AlbumInfo] = []
        let imageOptions = PHFetchOptions()
        imageOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        func append(_ collection: PHAssetCollection) {
            let assets = PHAsset.fetchAssets(in: collection, options: imageOptions)
            guard assets.count > 0 else { return }
            result.append(AlbumInfo(id: collection.localIdentifier,
                                    title: collection.localizedTitle ?? "Album",
                                    count: assets.count,
                                    coverAssetID: assets.lastObject?.localIdentifier))
        }

        for subtype in [PHAssetCollectionSubtype.smartAlbumFavorites, .smartAlbumUserLibrary] {
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
                .enumerateObjects { c, _, _ in append(c) }
        }
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            .enumerateObjects { c, _, _ in append(c) }
        return result
    }

    /// Returns `set` with photos matching the album (newest first, up to `limit`).
    /// Keeps already-imported photos (and their captions), imports new ones, deletes removed ones.
    static func sync(_ set: PhotoSet, limit: Int, progress: @escaping @Sendable (Double) -> Void) async -> PhotoSet {
        guard case let .album(albumID, _) = set.source,
              let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject
        else { return set }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let fetch = PHAsset.fetchAssets(in: collection, options: options)

        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }

        let existing = Dictionary(set.photos.compactMap { p in p.assetIdentifier.map { ($0, p) } }, uniquingKeysWith: { a, _ in a })
        var photos: [PhotoItem] = []
        let toImport = assets.filter { existing[$0.localIdentifier] == nil }
        var imported = 0

        for asset in assets {
            if let kept = existing[asset.localIdentifier] {
                photos.append(kept)
                continue
            }
            if let data = await imageData(for: asset),
               var item = try? ImageStore.save(imageData: data) {
                item.assetIdentifier = asset.localIdentifier
                item.capturedAt = item.capturedAt ?? asset.creationDate
                photos.append(item)
            }
            imported += 1
            progress(Double(imported) / Double(max(1, toImport.count)))
        }

        // Delete files for photos no longer in the album.
        let keptIDs = Set(photos.map(\.id))
        set.photos.filter { !keptIDs.contains($0.id) }.forEach(ImageStore.delete)

        var updated = set
        updated.photos = photos
        return updated
    }

    /// Downloads (from iCloud if needed) a screen-sized version of the asset.
    static func imageData(for asset: PHAsset, targetPixel: CGFloat = ImageStore.storedMaxPixel) async -> Data? {
        let image: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat   // one callback only
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: targetPixel, height: targetPixel),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        // Photos calls back on the main thread; encode elsewhere so syncing doesn't stutter the UI.
        return await Task.detached(priority: .utility) { image?.jpegData(compressionQuality: 0.92) }.value
    }

    static func thumbnail(for assetID: String, side: CGFloat = 200) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else { return nil }
        guard let data = await imageData(for: asset, targetPixel: side) else { return nil }
        return UIImage(data: data)
    }
}
