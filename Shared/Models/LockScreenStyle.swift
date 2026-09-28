import Foundation

/// Shape the photo is cut into for the circular Lock Screen widget.
enum LockShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case circle, ring, squircle, heart, star

    var id: String { rawValue }
    var title: String {
        switch self {
        case .circle: "Circle"
        case .ring: "Ring"
        case .squircle: "Squircle"
        case .heart: "Heart"
        case .star: "Star"
        }
    }
    var symbol: String {
        switch self {
        case .circle: "circle.fill"
        case .ring: "circle.circle"
        case .squircle: "app.fill"
        case .heart: "heart.fill"
        case .star: "star.fill"
        }
    }
}

/// How the photo is processed so it reads well in the Lock Screen's tinted (vibrant) style.
enum LockPhotoLook: String, Codable, CaseIterable, Identifiable, Sendable {
    case natural, contrast, poster, soft, outline

    var id: String { rawValue }
    var title: String {
        switch self {
        case .natural: "Natural"
        case .contrast: "Bold"
        case .poster: "Poster"
        case .soft: "Soft"
        case .outline: "Sketch"
        }
    }
}

/// Layout of the rectangular Lock Screen widget.
enum LockRectLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case photoAndText, photoOnly, strip, textOverPhoto

    var id: String { rawValue }
    var title: String {
        switch self {
        case .photoAndText: "Photo + text"
        case .photoOnly: "Wide photo"
        case .strip: "Photo strip"
        case .textOverPhoto: "Text on photo"
        }
    }
    var symbol: String {
        switch self {
        case .photoAndText: "rectangle.lefthalf.inset.filled"
        case .photoOnly: "rectangle.fill"
        case .strip: "square.split.3x1"
        case .textOverPhoto: "textformat"
        }
    }
}

/// What text the Lock Screen widgets show.
enum LockText: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, setName, photoDate, caption, today, yearsAgo, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Nothing"
        case .setName: "Set name"
        case .photoDate: "Photo date"
        case .caption: "Caption"
        case .today: "Today’s date"
        case .yearsAgo: "“2 years ago”"
        case .custom: "Custom text"
        }
    }
}

struct LockScreenStyle: Codable, Hashable, Sendable {
    var shape: LockShape = .circle
    var look: LockPhotoLook = .natural
    var rectLayout: LockRectLayout = .photoAndText
    var primaryText: LockText = .setName
    var secondaryText: LockText = .photoDate
    var customText: String = ""
    /// Thin outline around the photo (helps it stand out on busy wallpapers).
    var border: Bool = false
    /// 0.3–1.0 — how strong the photo appears in the tinted Lock Screen style.
    var intensity: Double = 1.0

    static let `default` = LockScreenStyle()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LockScreenStyle()
        shape = (try? c.decodeIfPresent(LockShape.self, forKey: .shape)) ?? d.shape
        look = (try? c.decodeIfPresent(LockPhotoLook.self, forKey: .look)) ?? d.look
        rectLayout = (try? c.decodeIfPresent(LockRectLayout.self, forKey: .rectLayout)) ?? d.rectLayout
        primaryText = (try? c.decodeIfPresent(LockText.self, forKey: .primaryText)) ?? d.primaryText
        secondaryText = (try? c.decodeIfPresent(LockText.self, forKey: .secondaryText)) ?? d.secondaryText
        customText = (try? c.decodeIfPresent(String.self, forKey: .customText)) ?? d.customText
        border = (try? c.decodeIfPresent(Bool.self, forKey: .border)) ?? d.border
        intensity = (try? c.decodeIfPresent(Double.self, forKey: .intensity)) ?? d.intensity
    }

    /// Resolves a text choice into the string to display.
    static func text(_ choice: LockText, set: PhotoSet?, item: PhotoItem?, date: Date, custom: String) -> String? {
        switch choice {
        case .none:
            return nil
        case .setName:
            return set?.name ?? "Framely"
        case .photoDate:
            return item?.capturedAt?.formatted(.dateTime.day().month(.abbreviated).year())
        case .caption:
            return item?.caption
        case .today:
            return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .yearsAgo:
            guard let captured = item?.capturedAt else { return nil }
            let years = Calendar.current.dateComponents([.year], from: captured, to: date).year ?? 0
            switch years {
            case ..<1: return "This year"
            case 1: return "1 year ago"
            default: return "\(years) years ago"
            }
        case .custom:
            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
    }
}
