import SwiftUI
import PhotosUI
import Photos
import WidgetKit

/// App-wide state: photo sets and everything that changes them.
@Observable
@MainActor
final class AppModel {
    private(set) var sets: [PhotoSet]
    /// 0…1 while importing/syncing, nil when idle.
    var progress: Double?
    var progressLabel = ""
    var errorMessage: String?

    private let store: SharedStore
    private var reloadTask: Task<Void, Never>?
    private var warmTask: Task<Void, Never>?

    init(store: SharedStore = .shared) {
        self.store = store
        self.sets = store.loadSets()
    }

    func photoSet(id: UUID) -> PhotoSet? { sets.first { $0.id == id } }

    // MARK: CRUD

    @discardableResult
    func createSet(name: String, symbol: String) -> PhotoSet {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let set = PhotoSet(name: trimmed.isEmpty ? "My Photos" : trimmed, symbol: symbol)
        sets.append(set)
        persist()
        return set
    }

    func update(_ set: PhotoSet) {
        // Unchanged (a picker re-sending its value, a sync that found nothing new): writing and
        // reloading would make every widget redraw for nothing.
        guard let i = sets.firstIndex(where: { $0.id == set.id }), sets[i] != set else { return }
        sets[i] = set
        persist()
    }

    /// Applies a new photo order (drag to reorder). "In order" rotation and the cover follow this order.
    func setPhotoOrder(_ ids: [UUID], in setID: UUID) {
        guard let s = sets.firstIndex(where: { $0.id == setID }) else { return }
        let rank = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        sets[s].photos.sort { (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max) }
        persist()
    }

    func deleteSet(_ set: PhotoSet) {
        set.photos.forEach(ImageStore.delete)
        sets.removeAll { $0.id == set.id }
        persist()
    }

    func deletePhotos(_ ids: Set<UUID>, from setID: UUID) {
        guard var set = photoSet(id: setID) else { return }
        set.photos.filter { ids.contains($0.id) }.forEach(ImageStore.delete)
        set.photos.removeAll { ids.contains($0.id) }
        update(set)
    }

    func makeCover(_ photoID: UUID, in setID: UUID) {
        guard var set = photoSet(id: setID), let i = set.photos.firstIndex(where: { $0.id == photoID }) else { return }
        let item = set.photos.remove(at: i)
        set.photos.insert(item, at: 0)
        update(set)
    }

    func setCaption(_ caption: String, photoID: UUID, in setID: UUID) {
        guard var set = photoSet(id: setID), let i = set.photos.firstIndex(where: { $0.id == photoID }) else { return }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        set.photos[i].caption = trimmed.isEmpty ? nil : trimmed
        update(set)
    }

    // MARK: Import (hand-picked)

    func importPhotos(_ items: [PhotosPickerItem], into setID: UUID, gate: FeatureGate) async {
        guard let current = photoSet(id: setID), !items.isEmpty else { return }
        let room = max(0, gate.maxPhotos() - current.photos.count)
        let batch = Array(items.prefix(room))
        guard !batch.isEmpty else { return }

        progressLabel = "Adding photos"
        progress = 0
        var added: [PhotoItem] = []
        var failures = 0

        for (n, pickerItem) in batch.enumerated() {
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else { throw ImageStoreError.unreadableImage }
                var item = try await Task.detached(priority: .userInitiated) { try ImageStore.save(imageData: data) }.value
                item.assetIdentifier = pickerItem.itemIdentifier
                if item.capturedAt == nil, let id = pickerItem.itemIdentifier {
                    item.capturedAt = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject?.creationDate
                }
                added.append(item)
            } catch {
                failures += 1
            }
            progress = Double(n + 1) / Double(batch.count)
        }

        if var set = photoSet(id: setID) {
            set.photos.append(contentsOf: added)
            update(set)
        }
        progress = nil
        if failures > 0 { errorMessage = "\(failures) photo\(failures == 1 ? "" : "s") couldn’t be added." }
    }

    // MARK: Album sync

    func linkAlbum(_ album: AlbumInfo, to setID: UUID, gate: FeatureGate) async {
        guard var set = photoSet(id: setID) else { return }
        set.source = .album(localIdentifier: album.id, title: album.title)
        update(set)
        await syncAlbum(setID: setID, gate: gate)
    }

    func unlinkAlbum(setID: UUID) {
        guard var set = photoSet(id: setID) else { return }
        set.source = .manual
        update(set)
    }

    /// Sets currently syncing. A second sync of the same set (Sync tapped twice, or the app
    /// becoming active mid-sync) would import the same photos twice and orphan files.
    private var syncing: Set<UUID> = []

    func syncAlbum(setID: UUID, gate: FeatureGate) async {
        guard let set = photoSet(id: setID), case .album = set.source, !syncing.contains(setID) else { return }
        syncing.insert(setID)
        defer { syncing.remove(setID) }
        progressLabel = "Syncing album"
        progress = 0
        let result = await AlbumSyncService.sync(set, limit: gate.maxPhotos()) { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }
        // Merge with the latest copy (the user may have edited styles meanwhile).
        if var latest = photoSet(id: setID), let i = sets.firstIndex(where: { $0.id == setID }) {
            let photosChanged = latest.photos != result.photos
            latest.photos = result.photos
            latest.lastSyncedAt = .now
            sets[i] = latest
            // Opening the app syncs albums; when the album didn't change, the widgets must not
            // reload (that blanked them for a moment on every launch).
            persist(reloadWidgets: photosChanged)
        }
        progress = nil
    }

    /// Called when the app becomes active: keeps album-linked sets fresh.
    func syncAllAlbums(gate: FeatureGate) async {
        guard gate.albumSync, AlbumSyncService.isAuthorized else { return }
        for set in sets where set.source.isAlbum {
            // Don't hammer the library — at most every 10 minutes.
            if let last = set.lastSyncedAt, Date.now.timeIntervalSince(last) < 600 { continue }
            await syncAlbum(setID: set.id, gate: gate)
        }
    }

    // MARK: Persistence

    private func persist(reloadWidgets: Bool = true) {
        store.saveSets(sets)
        if reloadWidgets { scheduleWidgetReload() }
    }

    /// Debounced so dragging a slider doesn't spam WidgetKit's reload budget.
    func scheduleWidgetReload() {
        reloadTask?.cancel()
        warmTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            let sets = sets, gate = FeatureGate.current
            // Render what's on screen right now *before* reloading. Reloaded widgets then
            // redraw from a small file instead of decoding and filtering inside the extension,
            // which blanked them for a moment (or hit the extension's memory limit).
            await RenderedImageCache.prewarm(sets, gate: gate, upcomingSlots: 1, prune: false)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            // Then the rest of the timeline, so the next rotations are a file read too.
            await RenderedImageCache.prewarm(sets, gate: gate)
        }
    }

    /// Tops up the widgets' image cache without reloading them (call when the app opens).
    /// Rotations keep moving while the app is closed; this pre-builds the ones coming up.
    func warmWidgetImages() {
        guard warmTask == nil else { return }
        let sets = sets
        warmTask = Task(priority: .utility) {
            await RenderedImageCache.prewarm(sets, gate: .current)
            warmTask = nil
        }
    }

    func cleanUpStorage() {
        ImageStore.removeOrphans(keeping: sets)
    }

    var storageUsed: String {
        let urls = (try? FileManager.default.contentsOfDirectory(at: ImageStore.directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let bytes = urls.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
