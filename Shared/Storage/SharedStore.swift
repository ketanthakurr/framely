import Foundation

/// JSON persistence in the App Group container, readable by the widget.
/// Kept intentionally simple (a few KB of JSON) so the widget can load it in milliseconds.
final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore()

    private let lock = NSLock()
    private let fileURL: URL
    private let defaults: UserDefaults

    private enum Key {
        static let isPro = "isProCached"
        static let onboardingDone = "onboardingDone"
        static func offset(_ id: UUID) -> String { "offset.\(id.uuidString)" }
        static func offsetStamp(_ id: UUID) -> String { "offsetStamp.\(id.uuidString)" }
    }

    init(containerURL: URL = AppGroup.containerURL, defaults: UserDefaults = AppGroup.defaults) {
        self.fileURL = containerURL.appendingPathComponent("sets.json")
        self.defaults = defaults
    }

    // MARK: Sets

    func loadSets() -> [PhotoSet] {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PhotoSet].self, from: data)) ?? []
    }

    func saveSets(_ sets: [PhotoSet]) {
        lock.lock(); defer { lock.unlock() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(sets)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            assertionFailure("Failed to save sets: \(error)")
        }
    }

    func set(id: UUID) -> PhotoSet? {
        loadSets().first { $0.id == id }
    }

    // MARK: Pro (cached for the widget; the app refreshes it from StoreKit)

    var isProCached: Bool {
        get { defaults.bool(forKey: Key.isPro) }
        set { defaults.set(newValue, forKey: Key.isPro) }
    }

    var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    // MARK: Manual "next photo" offset (driven by the widget button)

    func manualOffset(for id: UUID) -> Int { defaults.integer(forKey: Key.offset(id)) }

    /// When the user tapped "next" last — the widget uses it to animate a fresh photo in.
    func manualOffsetDate(for id: UUID) -> Date? { defaults.object(forKey: Key.offsetStamp(id)) as? Date }

    func advance(setID id: UUID, by step: Int = 1) {
        defaults.set(manualOffset(for: id) + step, forKey: Key.offset(id))
        defaults.set(Date.now, forKey: Key.offsetStamp(id))
    }
}
