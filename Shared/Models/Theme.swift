import SwiftUI

/// Home-screen color themes. `.auto` derives colors from each photo.
enum ThemeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, paper, mocha, sage, blush, ocean, midnight, noir

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .paper: "Paper"
        case .mocha: "Mocha"
        case .sage: "Sage"
        case .blush: "Blush"
        case .ocean: "Ocean"
        case .midnight: "Midnight"
        case .noir: "Noir"
        }
    }

    /// Resolves the palette for a given photo color (used by `.auto`).
    func palette(photoColor: Color?) -> ThemePalette {
        switch self {
        case .auto:
            let base = photoColor ?? Color(hex: "#8E8CF0")
            return ThemePalette(background: base.opacity(0.9), frame: .white, text: .white, accent: base)
        case .paper:
            return ThemePalette(background: Color(hex: "#F4EFE6"), frame: Color(hex: "#FFFDF8"), text: Color(hex: "#3B3530"), accent: Color(hex: "#C8A27C"))
        case .mocha:
            return ThemePalette(background: Color(hex: "#6B4F3F"), frame: Color(hex: "#EADBC8"), text: Color(hex: "#FFF6EC"), accent: Color(hex: "#C79A74"))
        case .sage:
            return ThemePalette(background: Color(hex: "#9CAF88"), frame: Color(hex: "#F1F4EA"), text: Color(hex: "#FFFFFF"), accent: Color(hex: "#5E7250"))
        case .blush:
            return ThemePalette(background: Color(hex: "#F2C6C2"), frame: Color(hex: "#FFF5F3"), text: Color(hex: "#6A3B3B"), accent: Color(hex: "#E08E8A"))
        case .ocean:
            return ThemePalette(background: Color(hex: "#1F4E79"), frame: Color(hex: "#DCEBF7"), text: Color(hex: "#F2F8FF"), accent: Color(hex: "#5DA9E9"))
        case .midnight:
            return ThemePalette(background: Color(hex: "#15162B"), frame: Color(hex: "#2A2C4F"), text: Color(hex: "#E7E8FF"), accent: Color(hex: "#8E8CF0"))
        case .noir:
            return ThemePalette(background: .black, frame: Color(hex: "#1C1C1E"), text: .white, accent: .white)
        }
    }

    /// Swatch shown in the theme picker.
    var swatch: [Color] {
        switch self {
        case .auto: return [Color(hex: "#FF9A8B"), Color(hex: "#8E8CF0"), Color(hex: "#6FD6C5")]
        default:
            let p = palette(photoColor: nil)
            return [p.background, p.frame, p.accent]
        }
    }
}

struct ThemePalette: Sendable {
    var background: Color
    var frame: Color
    var text: Color
    var accent: Color
}

extension Color {
    /// Creates a color from "#RRGGBB" or "RRGGBB". Invalid input falls back to gray.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
