import Foundation

/// ─────────────────────────────────────────────────────────────
///  FREE vs PRO — every limit lives here. Change freely.
/// ─────────────────────────────────────────────────────────────
enum ProConfig {
    /// Unlocks everything. Only true in tester builds, which are compiled with the
    /// `TESTER_PRO` flag on the command line (never set in project.yml, so App Store
    /// builds can't pick it up by accident). Never submit a tester build for review.
    #if TESTER_PRO
    static let everythingFree = true
    #else
    static let everythingFree = false
    #endif

    // Limits for free users
    static let freeMaxSets = 1
    static let freeMaxPhotosPerSet = 30

    // Style options available without Pro
    static let freeFrames: Set<FrameStyle> = [.edgeToEdge, .inset, .polaroid]
    static let freeFilters: Set<PhotoFilter> = [.original, .mono]
    static let freeThemes: Set<ThemeID> = [.auto, .paper, .noir]
    /// Free users can rotate at most this often T(presets and custom times).
    static let freeMinimumMinutes = 60
    /// Shortest interval anyone can pick. Timelines are pre-built (up to
    /// `PhotoScheduler.timelineLength` entries), so even 1 minute only reloads the
    /// widget about once every 48 minutes.
    static let absoluteMinimumMinutes = 1

    // Lock Screen options available without Pro 
    static let freeLockShapes: Set<LockShape> = [.circle, .squircle]
    static let freeLockLooks: Set<LockPhotoLook> = [.natural, .contrast]
    static let freeLockLayouts: Set<LockRectLayout> = [.photoAndText, .photoOnly]

    // Whole features
    static let mosaicWidgetIsPro = true
    static let infoWidgetIsPro = true
    static let albumSyncIsPro = false
    static let wallpaperShortcutIsPro = true
    static let overlaysArePro = false       // date / caption overlays

    // StoreKit product IDs, exactly as created in App Store Connect (they can't be renamed there).
    // Subscriptions › group "Framely Pro":
    static let monthlyProductID = "PRO_0001"
    static let yearlyProductID = "PRO_0002"
    // In-App Purchases › Non-Consumable (pay once, Pro forever; also what lifetime offer codes grant):
    static let lifetimeProductID = "LIFETIME_0001"
    /// Paywall order.
    static let productIDs = [yearlyProductID, monthlyProductID, lifetimeProductID]
}

/// Answers "is this allowed?" for both the app and the widget.
struct FeatureGate: Sendable {
    let isPro: Bool

    static var current: FeatureGate { FeatureGate(isPro: ProConfig.everythingFree || SharedStore.shared.isProCached) }

    func canAddSet(existing: Int) -> Bool { isPro || existing < ProConfig.freeMaxSets }
    func maxPhotos() -> Int { isPro ? 2_000 : ProConfig.freeMaxPhotosPerSet }

    func allows(_ frame: FrameStyle) -> Bool { isPro || ProConfig.freeFrames.contains(frame) }
    func allows(_ filter: PhotoFilter) -> Bool { isPro || ProConfig.freeFilters.contains(filter) }
    func allows(_ theme: ThemeID) -> Bool { isPro || ProConfig.freeThemes.contains(theme) }
    func allows(_ interval: RotationInterval) -> Bool { allows(minutes: interval.rawValue) }
    func allows(minutes: Int) -> Bool { isPro || minutes >= ProConfig.freeMinimumMinutes }
    func allows(_ shape: LockShape) -> Bool { isPro || ProConfig.freeLockShapes.contains(shape) }
    func allows(_ look: LockPhotoLook) -> Bool { isPro || ProConfig.freeLockLooks.contains(look) }
    func allows(_ layout: LockRectLayout) -> Bool { isPro || ProConfig.freeLockLayouts.contains(layout) }

    var mosaic: Bool { isPro || !ProConfig.mosaicWidgetIsPro }
    var infoWidget: Bool { isPro || !ProConfig.infoWidgetIsPro }
    var albumSync: Bool { isPro || !ProConfig.albumSyncIsPro }
    var wallpaperShortcut: Bool { isPro || !ProConfig.wallpaperShortcutIsPro }
    var overlays: Bool { isPro || !ProConfig.overlaysArePro }

    /// Downgrades a style to what the user may actually render (e.g. after Pro expires).
    func sanitize(_ style: WidgetStyle) -> WidgetStyle {
        var s = style
        if !allows(s.frame) { s.frame = .edgeToEdge }
        if !allows(s.filter) { s.filter = .original }
        if !allows(s.theme) { s.theme = .auto }
        if !overlays { s.showDate = false; s.showCaption = false }
        return s
    }

    func sanitize(_ lock: LockScreenStyle) -> LockScreenStyle {
        var l = lock
        if !allows(l.shape) { l.shape = .circle }
        if !allows(l.look) { l.look = .natural }
        if !allows(l.rectLayout) { l.rectLayout = .photoAndText }
        return l
    }

    /// The timing a widget should actually use for this set.
    func schedule(for set: PhotoSet?) -> RotationSchedule {
        guard let set else { return .default }
        var minutes = max(ProConfig.absoluteMinimumMinutes, set.intervalMinutes)
        if !allows(minutes: minutes) { minutes = ProConfig.freeMinimumMinutes }
        return RotationSchedule(minutes: minutes, anchorMinutes: set.anchorMinutes)
    }
}
