import Foundation

/// One photo copied into the shared container.
struct PhotoItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    /// File name inside `ImageStore.directory`.
    var fileName: String
    /// Original capture date (used for the date overlay and "On this day").
    var capturedAt: Date?
    /// PHAsset local identifier when the photo came from a synced album.
    var assetIdentifier: String?
    /// Average color of the photo, e.g. "#A3B2C1" — drives color-matched widgets.
    var dominantColorHex: String?
    var caption: String?
    var addedAt: Date = .now
}

enum PhotoSource: Codable, Hashable, Sendable {
    case manual
    case album(localIdentifier: String, title: String)

    var isAlbum: Bool {
        if case .album = self { return true }
        return false
    }
}

enum PhotoOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case shuffle, sequential
    var id: String { rawValue }
    var title: String { self == .shuffle ? "Shuffle" : "In order" }
    var symbol: String { self == .shuffle ? "shuffle" : "arrow.right" }
}

/// How often the widget moves to the next photo.
enum RotationInterval: Int, Codable, CaseIterable, Identifiable, Sendable {
    case min5 = 5, min15 = 15, min30 = 30, hour1 = 60, hour3 = 180, hour6 = 360, hour12 = 720, day1 = 1440

    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    /// Chip label, e.g. "5 min", "1 hr", "1 day". Same wording as every other interval label.
    var shortTitle: String { RotationInterval.shortTitle(minutes: rawValue) }

    /// e.g. "Every 5 minutes", "Every hour", "Every day".
    var title: String { RotationInterval.everyTitle(minutes: rawValue) }
}

/// A named collection of photos with its own rotation and style.
struct PhotoSet: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var symbol: String = "heart.fill"
    var photos: [PhotoItem] = []
    var source: PhotoSource = .manual
    var order: PhotoOrder = .shuffle
    /// Preset interval (used when `customMinutes` is nil).
    var interval: RotationInterval = .hour1
    /// Custom interval picked with the time picker; overrides `interval`.
    var customMinutes: Int? = nil
    /// Minutes after local midnight that rotations line up with (480 = 8:00 AM).
    var anchorMinutes: Int = 0
    var style: WidgetStyle = .default
    var lockStyle: LockScreenStyle = .default
    var createdAt: Date = .now
    var lastSyncedAt: Date?

    init(name: String, symbol: String = "heart.fill") {
        self.name = name
        self.symbol = symbol
    }

    var cover: PhotoItem? { photos.first }

    /// Effective rotation length in minutes (before Pro gating).
    var intervalMinutes: Int { customMinutes ?? interval.rawValue }

    static let symbols = [
        "heart.fill", "sparkles", "sun.max.fill", "moon.stars.fill", "airplane",
        "leaf.fill", "pawprint.fill", "camera.fill", "house.fill", "star.fill",
        "flame.fill", "music.note", "gift.fill", "figure.2.and.child.holdinghands", "mountain.2.fill", "cup.and.saucer.fill",
    ]

    // Tolerant decoding: sets saved by older versions (missing new keys) still load.
    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, photos, source, order, interval, customMinutes, anchorMinutes, style, lockStyle, createdAt, lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "heart.fill"
        photos = try c.decodeIfPresent([PhotoItem].self, forKey: .photos) ?? []
        source = try c.decodeIfPresent(PhotoSource.self, forKey: .source) ?? .manual
        order = try c.decodeIfPresent(PhotoOrder.self, forKey: .order) ?? .shuffle
        interval = (try? c.decodeIfPresent(RotationInterval.self, forKey: .interval)) ?? .hour1
        customMinutes = try c.decodeIfPresent(Int.self, forKey: .customMinutes)
        anchorMinutes = try c.decodeIfPresent(Int.self, forKey: .anchorMinutes) ?? 0
        style = (try? c.decodeIfPresent(WidgetStyle.self, forKey: .style)) ?? .default
        lockStyle = (try? c.decodeIfPresent(LockScreenStyle.self, forKey: .lockStyle)) ?? .default
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        lastSyncedAt = try c.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }
}

extension RotationInterval {
    /// "5 min", "1 hr 30 min", "2 days"
    static func shortTitle(minutes: Int) -> String {
        let (d, h, m) = components(minutes)
        var parts: [String] = []
        if d > 0 { parts.append(d == 1 ? "1 day" : "\(d) days") }
        if h > 0 { parts.append("\(h) hr") }
        if m > 0 || parts.isEmpty { parts.append("\(m) min") }
        return parts.joined(separator: " ")
    }

    /// "5 minutes", "1 hour 30 minutes", "2 days"
    static func longTitle(minutes: Int) -> String {
        let (d, h, m) = components(minutes)
        var parts: [String] = []
        if d > 0 { parts.append(d == 1 ? "1 day" : "\(d) days") }
        if h > 0 { parts.append(h == 1 ? "1 hour" : "\(h) hours") }
        if m > 0 || parts.isEmpty { parts.append(m == 1 ? "1 minute" : "\(m) minutes") }
        return parts.joined(separator: " ")
    }

    /// "Every minute", "Every hour", "Every day", "Every 5 minutes", "Every 1 hour 30 minutes".
    static func everyTitle(minutes: Int) -> String {
        switch minutes {
        case 1: "Every minute"
        case 60: "Every hour"
        case 1440: "Every day"
        default: "Every " + longTitle(minutes: minutes)
        }
    }

    private static func components(_ minutes: Int) -> (days: Int, hours: Int, minutes: Int) {
        let total = max(0, minutes)
        return (total / 1440, (total % 1440) / 60, total % 60)
    }
}

/// Timing used by the scheduler (already Pro-gated).
struct RotationSchedule: Hashable, Sendable {
    var minutes: Int
    var anchorMinutes: Int

    var seconds: TimeInterval { TimeInterval(max(1, minutes) * 60) }
    /// Labels for what the widget really does (Pro-gated), so every screen agrees.
    var shortTitle: String { RotationInterval.shortTitle(minutes: minutes) }
    var title: String { RotationInterval.everyTitle(minutes: minutes) }
    static let `default` = RotationSchedule(minutes: 60, anchorMinutes: 0)
}
