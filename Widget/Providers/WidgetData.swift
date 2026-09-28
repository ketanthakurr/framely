import WidgetKit
import SwiftUI

/// A lightweight timeline entry. Images are loaded lazily in the view (memory-safe for widgets).
struct SetEntry: TimelineEntry {
    let date: Date
    let set: PhotoSet?
    let slot: Int
    let gate: FeatureGate
    var isPreview: Bool = false
    var showNextButton: Bool = true

    var style: WidgetStyle { gate.sanitize(set?.style ?? .default) }
    var schedule: RotationSchedule { gate.schedule(for: set) }
    var lockStyle: LockScreenStyle { gate.sanitize(set?.lockStyle ?? .default) }

    func photo(shift: Int = 0) -> PhotoItem? {
        guard let set, let i = PhotoScheduler.index(for: set, slot: slot, shift: shift) else { return nil }
        return set.photos[i]
    }

    static func empty(_ date: Date = .now) -> SetEntry {
        SetEntry(date: date, set: nil, slot: 0, gate: .current)
    }
}

enum WidgetData {
    /// The chosen set, or the first set if the widget hasn't been configured yet.
    static func resolveSet(_ entity: PhotoSetEntity?) -> PhotoSet? {
        let sets = SharedStore.shared.loadSets()
        if let id = entity?.id, let match = sets.first(where: { $0.id == id }) { return match }
        return sets.first(where: { !$0.photos.isEmpty }) ?? sets.first
    }

    /// Builds entries at every rotation boundary for the next day.
    /// `endAtMidnight` makes date-based widgets refresh right after midnight.
    static func timeline(for entity: PhotoSetEntity?, endAtMidnight: Bool = false, isPreview: Bool = false) -> Timeline<SetEntry> {
        let now = Date.now
        let gate = FeatureGate.current
        let set = resolveSet(entity)
        let schedule = gate.schedule(for: set)

        guard let set, !set.photos.isEmpty else {
            // Nothing to rotate — check back in a while in case photos get added.
            return Timeline(entries: [SetEntry(date: now, set: set, slot: 0, gate: gate)], policy: .after(now.addingTimeInterval(3600)))
        }

        var horizon: TimeInterval = 24 * 3600
        if endAtMidnight, let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 1), matchingPolicy: .nextTime) {
            horizon = min(horizon, midnight.timeIntervalSince(now))
        }

        let dates = PhotoScheduler.upcomingDates(from: now, schedule: schedule, horizon: horizon)
        let entries = dates.map { date in
            SetEntry(date: date, set: set, slot: PhotoScheduler.slot(at: date, schedule: schedule), gate: gate, isPreview: isPreview)
        }
        let refresh = endAtMidnight ? now.addingTimeInterval(horizon) : PhotoScheduler.nextChange(after: dates.last ?? now, schedule: schedule)
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

extension WidgetFamily {
    /// Pixel size to decode photos at for this family (@3x).
    var maxPixel: CGFloat {
        switch self {
        case .systemSmall: 540
        case .systemMedium, .systemLarge, .systemExtraLarge: 1150
        default: 320
        }
    }
}

/// Glassy round "next" button used on interactive widgets.
struct NextPhotoGlyph: View {
    var body: some View {
        Image(systemName: "arrow.forward")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }
}

/// Shown on Pro widgets when the user isn't subscribed.
struct LockedWidgetView: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "#FFD36E"), Color(hex: "#FF9A8B")], startPoint: .top, endPoint: .bottom))
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text("Framely Pro")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(hex: "#2A2C4F"), Color(hex: "#15162B")], startPoint: .top, endPoint: .bottom)
        }
        .widgetURL(DeepLink.pro.url)
    }
}
