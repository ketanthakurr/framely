import Foundation

/// Identifiers shared by the app and the widget extension.
/// If you change the bundle ID, change `groupID` here AND in both .entitlements files (project.yml).
enum AppGroup {
    static let groupID = "group.com.widget.framely"

    /// Root folder both processes can read/write.
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return url
        }
        // Fallback keeps SwiftUI previews and unit tests working without entitlements.
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }
}

enum WidgetKind {
    static let photo = "FramelyPhotoWidget"
    static let mosaic = "FramelyMosaicWidget"
    static let info = "FramelyInfoWidget"
    static let lockScreen = "FramelyLockScreenWidget"

    static let all = [photo, mosaic, info, lockScreen]
}

/// framely:// URLs opened from widgets.
enum DeepLink: Equatable {
    case set(UUID)
    case newSet
    case pro

    static let scheme = "framely"

    var url: URL {
        switch self {
        case .set(let id): URL(string: "\(Self.scheme)://set/\(id.uuidString)")!
        case .newSet: URL(string: "\(Self.scheme)://new")!
        case .pro: URL(string: "\(Self.scheme)://pro")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "set":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .set(id)
        case "new": self = .newSet
        case "pro": self = .pro
        default: return nil
        }
    }
}

enum AppLinks {
    // TODO: replace with your real pages before submitting (App Review requires working links).
    static let privacyPolicy = URL(string: "https://example.com/framely/privacy")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let support = URL(string: "mailto:support@example.com")!
    static let shortcutsApp = URL(string: "shortcuts://")!
    /// Your numeric App Store ID (App Store Connect › App Information › Apple ID), e.g. "6720000000".
    /// Once set, codes typed into Framely's redeem field open Apple's redemption page pre-filled.
    static let appStoreID: String? = nil
}
