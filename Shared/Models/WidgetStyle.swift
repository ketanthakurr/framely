import SwiftUI

enum FrameStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case edgeToEdge, inset, polaroid, film, glass, arch

    var id: String { rawValue }
    var title: String {
        switch self {
        case .edgeToEdge: "Full bleed"
        case .inset: "Inset"
        case .polaroid: "Polaroid"
        case .film: "Film"
        case .glass: "Glass"
        case .arch: "Arch"
        }
    }
    var symbol: String {
        switch self {
        case .edgeToEdge: "rectangle.fill"
        case .inset: "rectangle.inset.filled"
        case .polaroid: "photo.artframe"
        case .film: "film"
        case .glass: "square.on.square.intersection.dashed"
        case .arch: "door.left.hand.closed"
        }
    }
}

/// Core Image photo effects applied when the widget loads an image.
enum PhotoFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case original, mono, noir, warm, vintage, fade, chrome

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: "Original"
        case .mono: "Mono"
        case .noir: "Noir"
        case .warm: "Warm"
        case .vintage: "Vintage"
        case .fade: "Fade"
        case .chrome: "Chrome"
        }
    }
    /// Built-in CIFilter name, nil = no filter.
    var ciFilterName: String? {
        switch self {
        case .original: nil
        case .mono: "CIPhotoEffectMono"
        case .noir: "CIPhotoEffectNoir"
        case .warm: "CIPhotoEffectTransfer"
        case .vintage: "CIPhotoEffectInstant"
        case .fade: "CIPhotoEffectFade"
        case .chrome: "CIPhotoEffectChrome"
        }
    }
}

enum OverlayPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case topLeading, bottomLeading, bottomTrailing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .topLeading: "Top"
        case .bottomLeading: "Bottom left"
        case .bottomTrailing: "Bottom right"
        }
    }
    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }
}

struct WidgetStyle: Codable, Hashable, Sendable {
    var frame: FrameStyle = .edgeToEdge
    var filter: PhotoFilter = .original
    var theme: ThemeID = .auto
    /// Corner radius of the photo inside inset/polaroid/glass frames (points).
    var innerCornerRadius: Double = 14
    var showDate: Bool = false
    var showCaption: Bool = false
    var overlayPosition: OverlayPosition = .bottomLeading
    /// Soft glow tinted with the photo's color (color-matched look).
    var glow: Bool = true

    static let `default` = WidgetStyle()
}
