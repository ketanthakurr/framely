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
        guard let i = sets.firstIndex(where: { $0.id == set.id }) else { return }
        sets[i] = set
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

    func syncAlbum(setID: UUID, gate: FeatureGate) async {
        guard let set = photoSet(id: setID), case .album = set.source else { return }
        progressLabel = "Syncing album"
        progress = 0
        let result = await AlbumSyncService.sync(set, limit: gate.maxPhotos()) { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }
        // Merge with the latest copy (the user may have edited styles meanwhile).
        if var latest = photoSet(id: setID) {
            latest.photos = result.photos
            latest.lastSyncedAt = .now
            update(latest)
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

    private func persist() {
        store.saveSets(sets)
        scheduleWidgetReload()
    }

    /// Debounced so dragging a slider doesn't spam WidgetKit's reload budget.
    func scheduleWidgetReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
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
